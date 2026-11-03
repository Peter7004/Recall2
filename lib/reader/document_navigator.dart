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

class ReaderDocumentNavigator extends StatefulWidget {
  const ReaderDocumentNavigator(
      {super.key,
      required this.pageCount,
      required this.currentPage,
      required this.loadBookmarks,
      required this.loadOutline,
      required this.onBookmark,
      required this.removeBookmark,
      required this.onPage,
      required this.thumbnailBuilder});
  final int pageCount, currentPage;
  final Future<List<ReaderPageBookmark>> Function() loadBookmarks;
  final Future<List<ReaderOutlineEntry>> Function() loadOutline;
  final ValueChanged<ReaderPageBookmark> onBookmark;
  final Future<void> Function(int page) removeBookmark;
  final ValueChanged<int> onPage;
  final Widget Function(BuildContext context, int page) thumbnailBuilder;
  @override
  State<ReaderDocumentNavigator> createState() =>
      _ReaderDocumentNavigatorState();
}

class _ReaderDocumentNavigatorState extends State<ReaderDocumentNavigator>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(_tabChanged);
  late Future<List<ReaderPageBookmark>> _bookmarks = widget.loadBookmarks();
  Future<List<ReaderOutlineEntry>>? _outline;
  int _tab = 0;
  bool _busy = false;

  void _tabChanged() {
    if (!mounted || _tab == _tabs.index) return;
    if (_tabs.index == 1 && _outline == null) {
      _outline = widget.loadOutline();
      _outline!.ignore();
    }
    setState(() => _tab = _tabs.index);
  }

  void _reloadBookmarks() {
    final next = widget.loadBookmarks();
    next.ignore();
    setState(() {
      _bookmarks = next;
    });
  }

  Future<void> _remove(int page) async {
    setState(() => _busy = true);
    try {
      await widget.removeBookmark(page);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('페이지 북마크를 삭제하지 못했습니다.')));
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

  Widget _bookmarkList() => FutureBuilder<List<ReaderPageBookmark>>(
      future: _bookmarks,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _failure(
              '페이지 북마크를 읽지 못했습니다. 기록은 변경하지 않았습니다.', _reloadBookmarks);
        }
        final bookmarks = snapshot.data!;
        if (bookmarks.isEmpty) {
          return const Center(
              child: Text('저장한 페이지가 없습니다. 읽기 화면의 북마크 버튼으로 추가하세요.'));
        }
        return ListView.builder(
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return ListTile(
                  title: Text('${bookmark.page}쪽'),
                  leading: IconButton(
                      tooltip: '북마크로 이동: ${bookmark.page}쪽',
                      icon: const Icon(Icons.bookmark),
                      onPressed:
                          _busy ? null : () => widget.onBookmark(bookmark)),
                  onTap: _busy ? null : () => widget.onBookmark(bookmark),
                  trailing: IconButton(
                      tooltip: '${bookmark.page}쪽 북마크 삭제',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : () => _remove(bookmark.page)));
            });
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
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          const Expanded(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('문서 탐색',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)))),
          IconButton(
              tooltip: '문서 탐색 닫기',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))
        ]),
        const Text('PDF 파일 기준 페이지 번호입니다.'),
        TabBar(controller: _tabs, tabs: const [
          Tab(text: '내 북마크'),
          Tab(text: '문서 목차'),
          Tab(text: '미리보기')
        ]),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
            child: TabBarView(controller: _tabs, children: [
          _bookmarkList(),
          _tab == 1 ? _outlineList() : const SizedBox.shrink(),
          _tab == 2
              ? _ThumbnailGrid(
                  pageCount: widget.pageCount,
                  currentPage: widget.currentPage,
                  builder: widget.thumbnailBuilder,
                  onPage: widget.onPage)
              : const SizedBox.shrink(),
        ])),
      ]);
}

class _ThumbnailGrid extends StatefulWidget {
  const _ThumbnailGrid(
      {required this.pageCount,
      required this.currentPage,
      required this.builder,
      required this.onPage});
  final int pageCount, currentPage;
  final Widget Function(BuildContext, int) builder;
  final ValueChanged<int> onPage;
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
        _scroll ??= ScrollController(
            initialScrollOffset: ((widget.currentPage - 1) ~/ columns) * 250.0);
        return GridView.builder(
            controller: _scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            addAutomaticKeepAlives: false,
            padding: const EdgeInsets.all(12),
            itemCount: widget.pageCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 240,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10),
            itemBuilder: (context, index) {
              final page = index + 1;
              return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: page == widget.currentPage
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2)),
                  child: InkWell(
                      onTap: () => widget.onPage(page),
                      child: Column(children: [
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: widget.builder(context, page))),
                        TextButton(
                            onPressed: () => widget.onPage(page),
                            child: Text('$page쪽으로 이동')),
                      ])));
            });
      });
}
