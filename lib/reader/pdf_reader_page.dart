import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

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

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key, this.store, this.repository});
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

  DictionaryTerminologyLookup _buildTerminology() =>
      DictionaryTerminologyLookup([
        for (final entry in widget.store?.allCards ??
            <({RecallDeck deck, RecallCard card})>[])
          ReaderConcept(entry.card),
      ]);
  void _dictionaryChanged() {
    if (mounted) setState(() => _terminology = _buildTerminology());
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
    if (!mounted) return;
    _searcher.resetTextSearch();
    _query.clear();
    _selectionTimer?.cancel();
    _selectionRequest++;
    setState(() {
      _bytes = bytes;
      _documentId = doc.id;
      _restore = progress;
      _paged = progress?.paged ?? false;
      _saveErrorShown = false;
      _searchVisible = false;
      _name = doc.title;
      _word = null;
      _ready = false;
      _page = 1;
      _pages = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminology = _buildTerminology();
    widget.store?.addListener(_dictionaryChanged);
    _controller.addListener(_positionChanged);
    _searcher.addListener(_searchChanged);
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
    _restoring = true;
    try {
      final page = progress.page.clamp(1, _pages);
      await _controller.goToPage(pageNumber: page, duration: Duration.zero);
      if (!mounted || !_controller.isReady) return;
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
      _restore = null;
      _restoring = false;
      if (mounted) unawaited(_save());
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
      _ready = false;
      _word = null;
    });
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
    final matches = _terminology.lookup(text);
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
                      if (meaning.explanationKo.isNotEmpty)
                        Text(meaning.explanationKo),
                    if (match.concept.card.verificationStatus !=
                        VerificationStatus.verified)
                      Text(match.concept.card.verificationStatus.label),
                    const SizedBox(height: 8),
                  ],
                ],
        )));
  }

  Future<void> _open() async {
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
    // Keep the native selection and its highlight; do not steal focus with a dialog.
    _selectionTimer = Timer(const Duration(milliseconds: 180), () async {
      String? word;
      try {
        if (selection.isCopyAllowed) {
          final text = (await selection.getSelectedText()).trim();
          if (text.isNotEmpty && text.length <= 2000) word = text;
        }
      } catch (_) {
        word = null;
      }
      if (mounted && request == _selectionRequest) setState(() => _word = word);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
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
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
            ]),
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
                          ],
                          onViewerReady: (document, controller) {
                            if (mounted && document.sourceName == _documentId) {
                              setState(() {
                                _ready = true;
                                _pages = document.pages.length;
                              });
                              unawaited(_restorePosition());
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
