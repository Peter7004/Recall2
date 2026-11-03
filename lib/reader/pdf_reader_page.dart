import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../recall_store.dart';
import 'terminology_lookup.dart';
import 'reader_progress.dart';
import 'reader_navigation.dart';
import 'library/document_repository.dart';
import 'library/document_repository_factory.dart';
import 'library/reader_document.dart';
import 'library/reader_library_view.dart';
import 'term_hover_region.dart';
import 'pdf_term_hover.dart';
import 'page_bookmark.dart';
import 'document_navigator.dart';
import 'pdf_thumbnail.dart';
import 'thumbnail_queue.dart';
import 'reader_learning.dart';
import 'reader_learning_store.dart';
import 'reader_learning_view.dart';
import 'reader_source.dart';
import 'reader_settings.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage(
      {super.key, this.store, this.repository, this.initialSource});
  final ReaderOccurrence? initialSource;
  final RecallStore? store;
  final DocumentRepository? repository;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage>
    with WidgetsBindingObserver {
  final _controller = PdfViewerController();
  late final _searcher = PdfTextSearchSession(_controller);
  final _query = TextEditingController();
  String? _documentId;
  ReaderProgress? _restore;
  bool _paged = false;
  bool _restoring = false;
  bool _searchVisible = false;
  bool _saveErrorShown = false;
  int _gesturePage = 1;
  Offset? _gesturePosition;
  double _gestureScale = 1;
  Timer? _saveTimer;
  Future<void> _writes = Future.value();
  Future<DocumentRepository>? _repository;
  late DictionaryTerminologyLookup _terminology;
  List<ReaderPageBookmark> _pageBookmarks = [];
  bool _bookmarksReadable = false;
  bool _bookmarkBusy = false;
  bool _highlightAll = false;
  bool _defaultPaged = false;
  int _settingsEpoch = 0;
  Future<void> _settingsWrites = Future.value();
  Future<ReaderLearningStore>? _learningFuture;
  ReaderLearningStore? _learning;
  Map<int, List<ReaderOccurrence>> _savedByPage = {};
  final Map<int, TermAnalysisState> _analysis = {};
  int _analysisRetry = 0;
  int _restoreGeneration = 0;
  bool _termSaving = false;
  List<PdfPageTextRange> _selectionRanges = const [];
  ReaderOccurrence? _pendingSource;
  ({String id, ReaderProgress position})? _returnPoint;

  Future<void> _loadSettings() async {
    final epoch = _settingsEpoch;
    try {
      final settings = await ReaderSettings.load();
      if (!mounted || epoch != _settingsEpoch) return;
      setState(() {
        _highlightAll = settings.highlightAll;
        _defaultPaged = settings.paged;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('표시 설정을 읽지 못했습니다. 기본 설정으로 표시합니다.')));
      }
    }
  }

  void _saveSettings() {
    _settingsEpoch++;
    final settings =
        ReaderSettings(highlightAll: _highlightAll, paged: _defaultPaged);
    _settingsWrites =
        _settingsWrites.then((_) => settings.save()).catchError((Object _) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('표시 설정을 저장하지 못했습니다.')));
      }
    });
  }

  void _toggleHighlight() {
    setState(() {
      _highlightAll = !_highlightAll;
      _analysis.clear();
    });
    _saveSettings();
  }

  Future<void> _initializeLearning() async {
    try {
      await _getLearning();
    } catch (_) {
      /* Explicit access reports errors without overwriting records. */
    }
  }

  Future<ReaderLearningStore> _getLearning() async {
    try {
      final learning = await (_learningFuture ??= ReaderLearningStore.load());
      if (mounted && !identical(_learning, learning)) {
        _learning = learning;
        learning.addListener(_learningChanged);
        _learningChanged();
      }
      return learning;
    } catch (_) {
      _learningFuture = null;
      rethrow;
    }
  }

  void _learningChanged() {
    if (!mounted) return;
    final byPage = <int, List<ReaderOccurrence>>{};
    if (_documentId != null) {
      for (final source in _learning?.occurrencesForDocument(_documentId!) ??
          <ReaderOccurrence>[]) {
        (byPage[source.page] ??= []).add(source);
      }
    }
    setState(() => _savedByPage = byPage);
  }

  Future<void> _showLearning() async {
    try {
      final learning = await _getLearning();
      final docs = await (await _getRepository()).list();
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 720),
          builder: (sheetContext) => SafeArea(
              child: SizedBox(
                  height: math.min(
                      MediaQuery.sizeOf(sheetContext).height * .85, 900),
                  child: ReaderLearningView(
                      store: learning,
                      documentIds: docs.map((d) => d.id).toSet(),
                      currentDocumentId: _documentId,
                      cardById: (id) => widget.store?.cardById(id),
                      onSource: (source) {
                        Navigator.pop(sheetContext);
                        unawaited(_openSource(source));
                      }))));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('저장한 단어 기록을 읽지 못했습니다. 기존 기록은 변경하지 않았습니다.')));
      }
    }
  }

  Future<void> _saveTerm(ReaderTermMatch match) async {
    if (_termSaving || !_ready || !_controller.isReady || _documentId == null) {
      return;
    }
    final id = _documentId!;
    List<ReaderOccurrence> sources;
    try {
      sources = captureReaderOccurrences(
          ranges: _selectionRanges,
          document: _controller.document,
          lookup: _terminology,
          cardId: match.concept.card.id,
          documentId: id,
          documentTitle: _name);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('원문 위치를 읽지 못했습니다. 해당 용어를 다시 선택해 주세요.')));
      return;
    }
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('정확한 원문 위치를 확인하지 못했습니다. 해당 용어를 다시 선택해 주세요.')));
      return;
    }
    final card = match.concept.card;
    setState(() => _termSaving = true);
    try {
      final learning = await _getLearning();
      await learning.save(
          ReaderSavedTerm(
              cardId: card.id,
              term: card.displayTerm,
              meaning: card.meaning,
              definition: card.definitionEn,
              explanation: card.explanationKo,
              createdAt: DateTime.now()),
          sources);
      try {
        await widget.store?.ensureBookmarked(card.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('단어와 원문 위치를 저장했습니다.')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Reader 단어와 출처는 저장됐지만 기존 단어 북마크를 저장하지 못했습니다. 다시 저장해 주세요.')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('단어를 저장하지 못했습니다. 기존 학습 기록은 변경하지 않았습니다.')));
      }
    } finally {
      if (mounted) setState(() => _termSaving = false);
    }
  }

  Future<void> _openSource(ReaderOccurrence source) async {
    if (_opening || _pendingSource != null) return;
    final originId = _documentId, origin = _capture();
    try {
      await _save();
      if (source.documentId != _documentId) {
        setState(() => _opening = true);
        final opened = await (await _getRepository()).open(source.documentId);
        if (!mounted) return;
        _pendingSource = source;
        await _activate(opened.document, opened.bytes);
      } else {
        await _jumpToSource(source);
      }
      if (mounted && originId != null && origin != null) {
        setState(() => _returnPoint = (id: originId, position: origin));
      }
    } catch (error) {
      _pendingSource = null;
      _storageError(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _jumpToSource(ReaderOccurrence source) async {
    if (!mounted || !_controller.isReady || _documentId != source.documentId) {
      return;
    }
    if (source.page > _pages || source.rects.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('원문 위치를 표시할 수 없습니다.')));
      return;
    }
    final id = _documentId;
    await _controller.goToPage(
        pageNumber: source.page, duration: Duration.zero);
    if (!mounted || id != _documentId || !_controller.isReady) return;
    final layout = _controller.layout.pageLayouts[source.page - 1];
    final point = source.rects.first.center;
    await _controller.goTo(
        _controller.calcMatrixFor(
            Offset(layout.left + layout.width * point.dx,
                layout.top + layout.height * point.dy),
            zoom: _controller.currentZoom),
        duration: Duration.zero);
    if (mounted && id == _documentId) {
      setState(() {
        _page = source.page;
        _word = null;
        _selectionRanges = const [];
      });
      await _save();
    }
  }

  Future<void> _finishRestore() async {
    try {
      await _restorePosition();
      final pending = _pendingSource;
      if (pending != null && pending.documentId == _documentId) {
        _pendingSource = null;
        await _jumpToSource(pending);
      }
    } catch (error) {
      _pendingSource = null;
      _storageError(error);
    }
  }

  Future<void> _returnToReading() async {
    final point = _returnPoint;
    if (point == null || _opening) return;
    try {
      await _save();
      if (_documentId != point.id) {
        setState(() => _opening = true);
        final opened = await (await _getRepository()).open(point.id);
        if (!mounted) return;
        await _activate(opened.document, opened.bytes);
      }
      if (!mounted) return;
      _restore = point.position;
      setState(() {
        _paged = point.position.paged;
        _returnPoint = null;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _controller.isReady && _ready) await _restorePosition();
    } catch (error) {
      _storageError(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _analysisStatus() {
    final state =
        _analysis[_page] ?? const TermAnalysisState(TermAnalysisStatus.idle);
    final text = switch (state.status) {
      TermAnalysisStatus.idle => '커서를 올리면 사전 단어를 확인합니다.',
      TermAnalysisStatus.loading => '현재 페이지의 사전 단어 분석 중…',
      TermAnalysisStatus.ready =>
        '현재 페이지 사전 매칭 ${state.matchCount}곳 · 저장한 위치는 초록색',
      TermAnalysisStatus.unavailable =>
        state.message ?? '이 페이지의 텍스트를 읽을 수 없습니다.',
      TermAnalysisStatus.error => '단어 분석에 실패했습니다. 사전에 없는 것으로 판단하지 마세요.',
    };
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
          if (state.status == TermAnalysisStatus.error)
            TextButton(
                onPressed: () => setState(() => _analysisRetry++),
                child: const Text('단어 분석 재시도')),
        ]));
  }

  Future<List<ReaderPageBookmark>> _bookmarksFor(String id) async {
    final bookmarks = await (await _getRepository()).pageBookmarks(id);
    if (mounted && id == _documentId) {
      setState(() {
        _pageBookmarks = bookmarks;
        _bookmarksReadable = true;
      });
    }
    return bookmarks;
  }

  Future<void> _togglePageBookmark() async {
    if (_bookmarkBusy || !_bookmarksReadable) return;
    final position = _capture();
    final id = _documentId;
    if (position == null || id == null) return;
    setState(() => _bookmarkBusy = true);
    try {
      final bookmarks = await (await _getRepository())
          .togglePageBookmark(id, ReaderPageBookmark.fromProgress(position));
      if (mounted && id == _documentId) {
        setState(() => _pageBookmarks = bookmarks);
      }
    } catch (error) {
      _storageError(error);
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  Future<void> _togglePreviewBookmark(String id, int page) async {
    if (!mounted || id != _documentId || !_controller.isReady) return;
    final position = page == _page
        ? _capture()
        : ReaderProgress(
            page: page,
            x: .5,
            y: .5,
            zoom: _controller.minScale,
            paged: _paged);
    if (position == null) return;
    final bookmarks = await (await _getRepository())
        .togglePageBookmark(id, ReaderPageBookmark.fromProgress(position));
    if (mounted && id == _documentId) {
      setState(() => _pageBookmarks = bookmarks);
    }
  }

  Future<void> _goBookmark(String id, ReaderPageBookmark bookmark) async {
    if (!mounted || id != _documentId || !_ready || !_controller.isReady) {
      return;
    }
    _restore = bookmark.position(paged: _paged);
    await _restorePosition();
  }

  Future<void> _goOutline(String id, PdfDest dest) async {
    if (!mounted || id != _documentId || !_controller.isReady) return;
    try {
      final moved = await _controller.goToDest(dest);
      if (!moved && mounted && id == _documentId) {
        await _navigateToPage(dest.pageNumber);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('정확한 위치 대신 해당 페이지로 이동했습니다.')));
        }
      }
      await _save();
    } catch (error) {
      _storageError(error);
    }
  }

  Future<void> _showDocumentNavigator({bool outlineOnly = false}) async {
    if (!_ready || !_controller.isReady) return;
    final id = _documentId!;
    final document = _controller.document;
    final queue = ThumbnailQueue<ui.Image>(discard: (image) => image.dispose());
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 640),
          builder: (sheetContext) {
            void close() => Navigator.pop(sheetContext);
            return SafeArea(
                child: SizedBox(
                    height: math.min(
                        MediaQuery.sizeOf(sheetContext).height * .85, 900),
                    child: ReaderDocumentNavigator(
                      pageCount: document.pages.length,
                      currentPage: _page,
                      outlineOnly: outlineOnly,
                      loadBookmarks: () => _bookmarksFor(id),
                      toggleBookmark: (page) =>
                          _togglePreviewBookmark(id, page),
                      onBookmark: (bookmark) {
                        close();
                        unawaited(_goBookmark(id, bookmark));
                      },
                      onPage: (page) {
                        close();
                        if (id == _documentId) unawaited(_navigateToPage(page));
                      },
                      loadOutline: () async {
                        final nodes = await document.loadOutline();
                        final entries = <ReaderOutlineEntry>[];
                        final stack = [
                          for (final node in nodes.reversed)
                            (node: node, depth: 0)
                        ];
                        while (stack.isNotEmpty) {
                          final current = stack.removeLast();
                          final dest = current.node.dest;
                          final valid = dest != null &&
                              dest.pageNumber >= 1 &&
                              dest.pageNumber <= document.pages.length;
                          entries.add(ReaderOutlineEntry(
                              title: current.node.title,
                              depth: current.depth,
                              page: valid ? dest.pageNumber : null,
                              onNavigate: valid
                                  ? () {
                                      close();
                                      unawaited(_goOutline(id, dest));
                                    }
                                  : null));
                          for (final child in current.node.children.reversed) {
                            stack.add((node: child, depth: current.depth + 1));
                          }
                        }
                        return entries;
                      },
                      thumbnailBuilder: (context, page) => PdfThumbnail(
                          key: ValueKey((id, page)),
                          page: document.pages[page - 1],
                          queue: queue),
                    )));
          });
    } finally {
      queue.dispose();
    }
  }

  DictionaryTerminologyLookup _buildTerminology() =>
      DictionaryTerminologyLookup([
        for (final entry in widget.store?.allCards ??
            <({RecallDeck deck, RecallCard card})>[])
          ReaderConcept(entry.card),
      ]);
  void _dictionaryChanged() {
    if (mounted) {
      setState(() {
        _terminology = _buildTerminology();
        _analysis.clear();
      });
    }
  }

  Future<DocumentRepository> _getRepository() async {
    try {
      return await (_repository ??= widget.repository != null
          ? Future.value(widget.repository!)
          : createDocumentRepository());
    } catch (_) {
      _repository = null;
      rethrow;
    }
  }

  Widget _library({VoidCallback? close}) => ReaderLibraryView(
      repository: _getRepository,
      onImport: () async {
        close?.call();
        await _open();
      },
      onOpen: (id) async {
        close?.call();
        await _openManaged(id);
      },
      onDelete: _deleteManaged);

  Future<void> _showLibrary() async {
    await _save();
    if (!mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .85,
                child: _library(close: () => Navigator.pop(sheetContext)))));
  }

  Future<bool> _deleteManaged(String id) async {
    if (id == _documentId) {
      await _save();
      _saveTimer?.cancel();
      _ready = false;
    }
    try {
      final result = await (await _getRepository()).delete(id);
      if (mounted && _returnPoint?.id == id) {
        setState(() => _returnPoint = null);
      }
      if (_pendingSource?.documentId == id) _pendingSource = null;
      if (mounted && id == _documentId) {
        _searcher.resetTextSearch();
        _query.clear();
        _selectionTimer?.cancel();
        _selectionRequest++;
        setState(() {
          _bytes = null;
          _documentId = null;
          _name = 'Recall Reader';
          _searchVisible = false;
          _word = null;
          _page = 1;
          _pages = 0;
          _pageBookmarks = [];
          _bookmarksReadable = false;
          _selectionRanges = const [];
          _savedByPage = {};
          _analysis.clear();
        });
      }
      return result;
    } catch (_) {
      if (mounted && id == _documentId) setState(() => _ready = true);
      rethrow;
    }
  }

  Future<void> _openManaged(String id) async {
    if (_opening) return;
    _pendingSource = null;
    setState(() => _opening = true);
    try {
      await _save();
      final opened = await (await _getRepository()).open(id);
      await _activate(opened.document, opened.bytes);
    } catch (error) {
      _storageError(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _storageError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is DocumentStorageException
            ? error.message
            : 'PDF를 보관하거나 열지 못했습니다. 저장 공간과 파일 접근 권한을 확인해 주세요.')));
  }

  Future<void> _activate(ReaderDocument doc, Uint8List bytes) async {
    if (!mounted) return;
    if (_documentId == doc.id) {
      setState(() => _name = doc.title);
      return;
    }
    final progress = await ReaderProgress.load(doc.id);
    var bookmarks = <ReaderPageBookmark>[];
    var bookmarksReadable = true;
    try {
      bookmarks = await _bookmarksFor(doc.id);
    } catch (error) {
      bookmarksReadable = false;
      _storageError(error);
    }
    if (!mounted) return;
    _searcher.resetTextSearch();
    _query.clear();
    _selectionTimer?.cancel();
    _selectionRequest++;
    setState(() {
      _bytes = bytes;
      _documentId = doc.id;
      _restore = progress;
      _paged = progress?.paged ?? _defaultPaged;
      _saveErrorShown = false;
      _searchVisible = false;
      _name = doc.title;
      _word = null;
      _selectionRanges = const [];
      _analysis.clear();
      _restoreGeneration++;
      _restoring = false;
      _ready = false;
      _page = 1;
      _pages = 0;
      _pageBookmarks = bookmarks;
      _bookmarksReadable = bookmarksReadable;
    });
    _learningChanged();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminology = _buildTerminology();
    widget.store?.addListener(_dictionaryChanged);
    _controller.addListener(_positionChanged);
    _searcher.addListener(_searchChanged);
    unawaited(_loadSettings());
    unawaited(_initializeLearning());
    if (widget.initialSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openSource(widget.initialSource!));
      });
    }
  }

  @override
  void didUpdateWidget(PdfReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store?.removeListener(_dictionaryChanged);
      widget.store?.addListener(_dictionaryChanged);
      _terminology = _buildTerminology();
    }
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  ReaderProgress? _capture() {
    if (!_ready || !_controller.isReady || _restoring) return null;
    final page = _controller.pageNumber ?? _page;
    final rect = _controller.layout.pageLayouts[page - 1];
    final center = _controller.centerPosition;
    return ReaderProgress(
        page: page,
        x: ((center.dx - rect.left) / rect.width).clamp(0, 1),
        y: ((center.dy - rect.top) / rect.height).clamp(0, 1),
        zoom: _controller.currentZoom,
        paged: _paged);
  }

  void _positionChanged() {
    if (_restoring || !_ready) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _save);
  }

  Future<void> _save() {
    _saveTimer?.cancel();
    final progress = _capture();
    final id = _documentId;
    if (progress == null || id == null) return _writes;
    // Serialize snapshots so an older asynchronous write cannot win.
    _writes = _writes.then((_) => progress.save(id)).catchError((Object error) {
      if (mounted && !_saveErrorShown) {
        _saveErrorShown = true;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('읽던 위치를 저장하지 못했습니다.')));
      }
    });
    return _writes;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_save());
  }

  Future<void> _restorePosition() async {
    final progress = _restore;
    if (progress == null || !_controller.isReady) return;
    final id = _documentId;
    final generation = ++_restoreGeneration;
    _restoring = true;
    try {
      final page = progress.page.clamp(1, _pages);
      await _controller.goToPage(pageNumber: page, duration: Duration.zero);
      if (!mounted ||
          !_controller.isReady ||
          id != _documentId ||
          generation != _restoreGeneration) {
        return;
      }
      final rect = _controller.layout.pageLayouts[page - 1];
      final zoom =
          progress.zoom.clamp(_controller.minScale, _controller.maxScale);
      await _controller.goTo(
          _controller.calcMatrixFor(
              Offset(rect.left + rect.width * progress.x,
                  rect.top + rect.height * progress.y),
              zoom: zoom),
          duration: Duration.zero);
      if (mounted) setState(() => _page = page);
    } finally {
      if (id == _documentId && generation == _restoreGeneration) {
        _restore = null;
        _restoring = false;
        if (mounted) unawaited(_save());
      }
    }
  }

  Future<void> _switchMode() async {
    final progress = _capture();
    if (progress == null) return;
    await _save();
    if (!mounted) return;
    _selectionTimer?.cancel();
    _selectionRequest++;
    _restore = ReaderProgress(
        page: progress.page,
        x: progress.x,
        y: progress.y,
        zoom: progress.zoom,
        paged: !_paged);
    setState(() {
      _paged = !_paged;
      _defaultPaged = _paged;
      _ready = false;
      _word = null;
    });
    _saveSettings();
    // Keep the viewer/controller attached. Replacing the keyed viewer can let
    // the old viewer detach the shared controller after the new one attaches.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _ready = true);
    await _restorePosition();
  }

  Future<void> _navigateToPage(int page) async {
    if (!_ready || !_controller.isReady || _pages < 1) return;
    await _controller.goToPage(pageNumber: page.clamp(1, _pages));
    await _save();
  }

  Future<void> _showPageDialog() async {
    final id = _documentId;
    final page = await showDialog<int>(
        context: context,
        builder: (_) => ReaderPageDialog(page: _page, pageCount: _pages));
    if (!mounted || page == null || id != _documentId) return;
    await _navigateToPage(page);
  }

  PdfPageLayout _horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height =
        pages.fold(0.0, (v, p) => math.max(v, p.height)) + params.margin * 2;
    final width =
        pages.fold(0.0, (v, p) => math.max(v, p.width)) + params.margin * 2;
    return PdfPageLayout(pageLayouts: [
      for (var i = 0; i < pages.length; i++)
        Rect.fromLTWH(i * width + (width - pages[i].width) / 2,
            (height - pages[i].height) / 2, pages[i].width, pages[i].height),
    ], documentSize: Size(width * pages.length, height));
  }

  void _snapPage(ScaleEndDetails details) {
    if (!_paged || !_ready || _gesturePosition == null) return;
    // At increased zoom, keep panning available instead of forcing a page turn.
    if ((_gestureScale - 1).abs() > .02 ||
        _controller.currentZoom > _controller.minScale * 1.05) {
      return;
    }
    final dx = _controller.centerPosition.dx - _gesturePosition!.dx;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final direction = dx.abs() > 30
        ? dx.sign.toInt()
        : velocity.abs() > 250
            ? -velocity.sign.toInt()
            : 0;
    unawaited(_controller.goToPage(
        pageNumber: (_gesturePage + direction).clamp(1, _pages)));
  }

  Widget _searchPanel() => SizedBox(
      height: 210,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                  labelText: 'PDF 본문 검색',
                  suffixIcon: IconButton(
                      tooltip: '검색 닫기',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searcher.resetTextSearch();
                        setState(() => _searchVisible = false);
                      })),
              onChanged: (text) =>
                  _searcher.startTextSearch(text.trim(), goToFirstMatch: false),
            )),
        if (_searcher.isSearching)
          LinearProgressIndicator(value: _searcher.searchProgress),
        Text(
            '검색 결과 ${_searcher.matches.length}개${_searcher.isSearching ? ' · 검색 중' : ''}'),
        Expanded(
            child: _searcher.matches.isEmpty
                ? Center(
                    child: Text(_query.text.trim().isEmpty
                        ? '검색어를 입력하세요.'
                        : '결과가 없습니다. 스캔 PDF는 본문 검색을 지원하지 않습니다.'))
                : ListView.builder(
                    itemCount: _searcher.matches.length,
                    itemBuilder: (context, index) {
                      final match = _searcher.matches[index];
                      return ListTile(
                          dense: true,
                          title: Text(match.contextText.replaceAll('\n', ' '),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          leading: Text('${match.pageNumber}쪽'),
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            await _searcher.goToMatchOfIndex(index);
                            await _save();
                          });
                    })),
      ]));
  Uint8List? _bytes;
  String _name = 'Recall Reader';
  String? _word;
  bool _opening = false;
  bool _ready = false;
  int _page = 1;
  int _pages = 0;
  int _selectionRequest = 0;
  Timer? _selectionTimer;

  Widget _lookupContent(String text) {
    final matches = {
      for (final match in _terminology.lookup(text))
        match.concept.card.id: match
    }.values;
    return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: matches.isEmpty
              ? [const Text('정의를 찾을 수 없습니다 (Definition not available).')]
              : [
                  for (final match in matches.take(5)) ...[
                    Text(match.expression,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text((match.isKorean
                            ? match.concept.english
                            : match.concept.korean)
                        .join(' / ')),
                    for (final meaning in match.concept.card.effectiveMeanings)
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (meaning.definitionEn.isNotEmpty)
                              Text(meaning.definitionEn),
                            if (meaning.explanationKo.isNotEmpty)
                              Text(meaning.explanationKo),
                          ]),
                    TextButton.icon(
                        onPressed: _termSaving ? null : () => _saveTerm(match),
                        icon: const Icon(Icons.playlist_add),
                        label:
                            Text('단어 저장: ${match.concept.card.displayTerm}')),
                    if (match.concept.card.verificationStatus !=
                        VerificationStatus.verified)
                      Text(match.concept.card.verificationStatus.label),
                    const SizedBox(height: 8),
                  ],
                ],
        )));
  }

  Future<void> _open() async {
    if (_opening) return;
    _pendingSource = null;
    setState(() => _opening = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (!mounted || result == null) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('PDF 파일을 읽을 수 없습니다.');
      }
      await _save();
      final repo = await _getRepository();
      final imported = await repo.importPdf(bytes, file.name);
      final opened = await repo.open(imported.document.id);
      await _activate(opened.document, opened.bytes);
      if (mounted && imported.duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 보관된 PDF입니다. 기존 문서를 열었습니다.')));
      }
    } catch (error) {
      _storageError(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _selectionChanged(PdfTextSelection selection) {
    _selectionTimer?.cancel();
    final request = ++_selectionRequest;
    final id = _documentId;
    _selectionRanges = const [];
    // Keep the native selection and its highlight; do not steal focus with a dialog.
    _selectionTimer = Timer(const Duration(milliseconds: 180), () async {
      String? word;
      var ranges = <PdfPageTextRange>[];
      try {
        if (selection.isCopyAllowed) {
          ranges = await selection.getSelectedTextRanges();
          final text = ranges.map((r) => r.text).join().trim();
          if (text.isNotEmpty && text.length <= 2000) word = text;
        }
      } catch (_) {
        word = null;
      }
      if (mounted && request == _selectionRequest && id == _documentId) {
        setState(() {
          _word = word;
          _selectionRanges = word == null ? const [] : ranges;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_save());
    WidgetsBinding.instance.removeObserver(this);
    widget.store?.removeListener(_dictionaryChanged);
    _controller.removeListener(_positionChanged);
    _searcher.removeListener(_searchChanged);
    _searcher.dispose();
    _query.dispose();
    _selectionTimer?.cancel();
    _selectionRequest++;
    _learning?.removeListener(_learningChanged);
    _learning?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                  tooltip: '저장한 단어·출처',
                  onPressed: _opening ? null : _showLearning,
                  icon: const Icon(Icons.school_outlined)),
              if (_ready)
                IconButton(
                    tooltip: '본문 검색',
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        setState(() => _searchVisible = !_searchVisible)),
              if (_bytes != null)
                IconButton(
                    tooltip: _paged ? '연속 스크롤로 전환' : '페이지별 보기로 전환',
                    icon: Icon(_paged
                        ? Icons.view_agenda_outlined
                        : Icons.view_carousel_outlined),
                    onPressed: _ready ? _switchMode : null),
              if (_bytes != null)
                IconButton(
                    tooltip: '문서 목록',
                    onPressed: _opening ? null : _showLibrary,
                    icon: const Icon(Icons.folder_open_outlined)),
              IconButton(
                  tooltip: 'PDF 열기',
                  onPressed: _opening ? null : _open,
                  icon: const Icon(Icons.file_open_outlined)),
            ]),
        body: Column(children: [
          if (_opening) const LinearProgressIndicator(),
          if (_searchVisible) _searchPanel(),
          if (_bytes != null)
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                      tooltip: '이전 페이지',
                      onPressed: _ready && _page > 1
                          ? () => _navigateToPage(_page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left)),
                  Tooltip(
                      message: '페이지 번호로 이동',
                      child: TextButton(
                          onPressed: _ready ? _showPageDialog : null,
                          child: Text('$_page / $_pages'))),
                  IconButton(
                      tooltip: '다음 페이지',
                      onPressed: _ready && _page < _pages
                          ? () => _navigateToPage(_page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right)),
                  IconButton(
                      tooltip: '축소',
                      onPressed: _ready ? () => _controller.zoomDown() : null,
                      icon: const Icon(Icons.zoom_out)),
                  IconButton(
                      tooltip: '확대',
                      onPressed: _ready ? () => _controller.zoomUp() : null,
                      icon: const Icon(Icons.zoom_in)),
                  IconButton(
                      tooltip: _pageBookmarks.any((b) => b.page == _page)
                          ? '페이지 북마크 해제'
                          : '페이지 북마크 추가',
                      onPressed: _ready && _bookmarksReadable && !_bookmarkBusy
                          ? _togglePageBookmark
                          : null,
                      icon: Icon(_pageBookmarks.any((b) => b.page == _page)
                          ? Icons.bookmark
                          : Icons.bookmark_border)),
                  IconButton(
                      tooltip: '미리보기·북마크',
                      onPressed: _ready ? () => _showDocumentNavigator() : null,
                      icon: const Icon(Icons.grid_view_outlined)),
                  IconButton(
                      tooltip: '문서 목차',
                      onPressed: _ready
                          ? () => _showDocumentNavigator(outlineOnly: true)
                          : null,
                      icon: const Icon(Icons.format_list_bulleted)),
                  if (_returnPoint != null)
                    IconButton(
                        tooltip: '이전 읽던 위치로 돌아가기',
                        onPressed:
                            _opening || !_ready ? null : _returnToReading,
                        icon: const Icon(Icons.undo)),
                  IconButton(
                      tooltip: _highlightAll
                          ? '커서를 올릴 때만 강조로 전환'
                          : '사전 단어 항상 강조로 전환',
                      isSelected: _highlightAll,
                      onPressed: _ready ? _toggleHighlight : null,
                      icon: const Icon(Icons.highlight_alt_outlined),
                      selectedIcon: const Icon(Icons.highlight)),
                ]),
          if (_bytes != null) _analysisStatus(),
          Expanded(
              child: _bytes == null
                  ? _library()
                  : Stack(children: [
                      Positioned.fill(
                          child: PdfViewer.data(
                        _bytes!,
                        sourceName: _documentId!,
                        key: const ValueKey('reader-document'),
                        controller: _controller,
                        params: PdfViewerParams(
                          layoutPages: _paged ? _horizontalLayout : null,
                          scrollPhysics:
                              _paged ? const ClampingScrollPhysics() : null,
                          onInteractionStart: (_) {
                            _gesturePage = _controller.pageNumber ?? _page;
                            _gesturePosition = _controller.centerPosition;
                            _gestureScale = 1;
                          },
                          onInteractionUpdate: (details) =>
                              _gestureScale = details.scale,
                          onInteractionEnd: _snapPage,
                          pagePaintCallbacks: [
                            _searcher.pageTextMatchPaintCallback
                          ],
                          pageOverlaysBuilder: (context, rect, page) => [
                            Positioned.fill(
                                child: TermHoverRegion(
                                    highlightAll: _highlightAll,
                                    retryToken: _analysisRetry,
                                    onAnalysisChanged: (state) {
                                      if (mounted &&
                                          page.document.sourceName ==
                                              _documentId &&
                                          _analysis[page.pageNumber] != state) {
                                        setState(() =>
                                            _analysis[page.pageNumber] = state);
                                      }
                                    },
                                    key: ValueKey(
                                        (_documentId, page.pageNumber)),
                                    cacheKey: (
                                      _documentId,
                                      page.pageNumber,
                                      _terminology
                                    ),
                                    viewToken: _controller.isReady
                                        ? (
                                            _controller.centerPosition,
                                            _controller.currentZoom
                                          )
                                        : null,
                                    loadAreas: () =>
                                        loadPdfHoverAreas(page, _terminology))),
                            if (_savedByPage[page.pageNumber] != null)
                              Positioned.fill(
                                  child: IgnorePointer(
                                      child: CustomPaint(
                                          painter: ReaderSourcePainter(
                                              _savedByPage[
                                                  page.pageNumber]!)))),
                          ],
                          onViewerReady: (document, controller) {
                            if (mounted && document.sourceName == _documentId) {
                              setState(() {
                                _ready = true;
                                _pages = document.pages.length;
                              });
                              unawaited(_finishRestore());
                              final id = _documentId;
                              if (id != null) {
                                unawaited(_getRepository()
                                    .then((repo) => repo.setPageCount(
                                        id, document.pages.length))
                                    .catchError((Object error) =>
                                        _storageError(error)));
                              }
                              if (_query.text.trim().isNotEmpty) {
                                _searcher.startTextSearch(_query.text.trim(),
                                    goToFirstMatch: false);
                              }
                            }
                          },
                          onPageChanged: (page) {
                            if (mounted && page != null) {
                              setState(() => _page = page);
                            }
                          },
                          textSelectionParams: PdfTextSelectionParams(
                              onTextSelectionChange: _selectionChanged),
                        ),
                      )),
                      if (_ready && _pages > 1)
                        Positioned(
                            right: 6,
                            top: 12,
                            bottom: 12,
                            width: 48,
                            child: ReaderPageRail(
                                key: ValueKey(_documentId),
                                page: _page,
                                pageCount: _pages,
                                onNavigate: (page) =>
                                    unawaited(_navigateToPage(page)))),
                      if (_word != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(8),
                                child: ListTile(
                                    title: Text(_word!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: _lookupContent(_word!),
                                    trailing: IconButton(
                                        tooltip: '닫기',
                                        onPressed: () =>
                                            setState(() => _word = null),
                                        icon: const Icon(Icons.close))),
                              ),
                            ),
                          ),
                        ),
                    ])),
        ]),
      );
}
