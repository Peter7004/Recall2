import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'page_bookmark.dart';

class ReaderOutlineEntry {
  const ReaderOutlineEntry(
      {required this.title, required this.depth, this.page, this.onNavigate});
  final String title;
  final int depth;
  final int? page;
  final VoidCallback? onNavigate;
}

/// Two direct entry points: outline only, or one combined preview/bookmark grid.
class ReaderDocumentNavigator extends StatefulWidget {
  const ReaderDocumentNavigator(
      {super.key,
      required this.pageCount,
      required this.currentPage,
      required this.loadBookmarks,
      required this.loadOutline,
      required this.onBookmark,
      required this.toggleBookmark,
      required this.onPage,
      required this.thumbnailBuilder,
      this.outlineOnly = false});
  final int pageCount, currentPage;
  final bool outlineOnly;
  final Future<List<ReaderPageBookmark>> Function() loadBookmarks;
  final Future<List<ReaderOutlineEntry>> Function() loadOutline;
  final ValueChanged<ReaderPageBookmark> onBookmark;
  final Future<void> Function(int page) toggleBookmark;
  final ValueChanged<int> onPage;
  final Widget Function(BuildContext context, int page) thumbnailBuilder;
  @override
  State<ReaderDocumentNavigator> createState() =>
      _ReaderDocumentNavigatorState();
}

class _ReaderDocumentNavigatorState extends State<ReaderDocumentNavigator> {
  late Future<List<ReaderPageBookmark>> _bookmarks;
  Future<List<ReaderOutlineEntry>>? _outline;
  bool _busy = false, _onlyBookmarks = false;
  @override
  void initState() {
    super.initState();
    if (widget.outlineOnly) {
      _outline = widget.loadOutline();
    } else {
      _bookmarks = widget.loadBookmarks();
    }
  }

  void _reloadBookmarks() {
    final next = widget.loadBookmarks();
    setState(() {
      _bookmarks = next;
    });
  }

  Future<void> _toggle(int page) async {
    setState(() => _busy = true);
    try {
      await widget.toggleBookmark(page);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('페이지 북마크를 변경하지 못했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reloadBookmarks();
      }
    }
  }

  Widget _failure(String message, VoidCallback retry) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message),
        TextButton(onPressed: retry, child: const Text('다시 시도'))
      ]));
  Widget _preview() => FutureBuilder<List<ReaderPageBookmark>>(
      future: _bookmarks,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _failure(
              '페이지 북마크를 읽지 못했습니다. 기록은 변경하지 않았습니다.', _reloadBookmarks);
        }
        final bookmarks = {for (final b in snapshot.data!) b.page: b};
        return Column(children: [
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                    label: Text('북마크만 (${bookmarks.length})'),
                    selected: _onlyBookmarks,
                    onSelected: (value) =>
                        setState(() => _onlyBookmarks = value)),
                const Text('각 페이지의 별표로 저장·해제'),
              ]),
          Expanded(
              child: _onlyBookmarks && bookmarks.isEmpty
                  ? const Center(child: Text('저장한 페이지가 없습니다.'))
                  : _ThumbnailGrid(
                      key: ValueKey(_onlyBookmarks),
                      pages: _onlyBookmarks
                          ? bookmarks.keys.toList()
                          : List.generate(widget.pageCount, (i) => i + 1),
                      currentPage: widget.currentPage,
                      builder: widget.thumbnailBuilder,
                      bookmarks: bookmarks,
                      busy: _busy,
                      onToggle: _toggle,
                      onPage: (page) {
                        final bookmark = bookmarks[page];
                        if (bookmark != null) {
                          widget.onBookmark(bookmark);
                        } else {
                          widget.onPage(page);
                        }
                      })),
        ]);
      });
  Widget _outlineList() => FutureBuilder<List<ReaderOutlineEntry>>(
      future: _outline,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _failure('문서 목차를 읽지 못했습니다.', () {
            final next = widget.loadOutline();
            next.ignore();
            setState(() {
              _outline = next;
            });
          });
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Center(child: Text('이 PDF에는 문서 목차가 없습니다.'));
        }
        return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                  padding:
                      EdgeInsets.only(left: entry.depth.clamp(0, 8) * 12.0),
                  child: ListTile(
                      title:
                          Text(entry.title.isEmpty ? '제목 없는 목차' : entry.title),
                      subtitle: Text(
                          entry.page == null ? '이동 위치 없음' : '${entry.page}쪽'),
                      onTap: entry.onNavigate,
                      leading: entry.onNavigate == null
                          ? const Icon(Icons.subject)
                          : IconButton(
                              tooltip: '목차로 이동: ${entry.title}',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: entry.onNavigate)));
            });
      });

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(widget.outlineOnly ? '문서 목차' : '미리보기·북마크',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)))),
          IconButton(
              tooltip: widget.outlineOnly ? '문서 목차 닫기' : '미리보기·북마크 닫기',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))
        ]),
        const Text('PDF 파일 기준 페이지 번호입니다.'),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: widget.outlineOnly ? _outlineList() : _preview()),
      ]);
}

class _ThumbnailGrid extends StatefulWidget {
  const _ThumbnailGrid(
      {super.key,
      required this.pages,
      required this.currentPage,
      required this.builder,
      required this.onPage,
      required this.bookmarks,
      required this.busy,
      required this.onToggle});
  final List<int> pages;
  final int currentPage;
  final Map<int, ReaderPageBookmark> bookmarks;
  final bool busy;
  final Widget Function(BuildContext, int) builder;
  final ValueChanged<int> onPage, onToggle;
  @override
  State<_ThumbnailGrid> createState() => _ThumbnailGridState();
}

class _ThumbnailGridState extends State<_ThumbnailGrid> {
  ScrollController? _scroll;
  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = (constraints.maxWidth / 180).floor().clamp(1, 3);
        final index = widget.pages.indexOf(widget.currentPage);
        _scroll ??= ScrollController(
            initialScrollOffset: (index < 0 ? 0 : index ~/ columns) * 250.0);
        return GridView.builder(
            controller: _scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            addAutomaticKeepAlives: false,
            padding: const EdgeInsets.all(12),
            itemCount: widget.pages.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 240,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10),
            itemBuilder: (context, index) {
              final page = widget.pages[index];
              final saved = widget.bookmarks.containsKey(page);
              return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: page == widget.currentPage
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2)),
                  child: Column(children: [
                    Expanded(
                        child: InkWell(
                            onTap: () => widget.onPage(page),
                            child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: widget.builder(context, page)))),
                    Row(children: [
                      Expanded(
                          child: TextButton(
                              onPressed: () => widget.onPage(page),
                              child: Text('$page쪽으로 이동'))),
                      IconButton(
                          tooltip: '$page쪽 북마크 ${saved ? '해제' : '추가'}',
                          isSelected: saved,
                          icon: const Icon(Icons.star_border),
                          selectedIcon: const Icon(Icons.star),
                          onPressed:
                              widget.busy ? null : () => widget.onToggle(page))
                    ]),
                  ]));
            });
      });
}
