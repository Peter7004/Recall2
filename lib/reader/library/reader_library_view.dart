import 'package:flutter/material.dart';
import 'document_repository.dart';
import 'reader_document.dart';

class ReaderLibraryView extends StatefulWidget {
  const ReaderLibraryView(
      {super.key,
      required this.repository,
      required this.onImport,
      required this.onOpen,
      required this.onDelete});
  final Future<DocumentRepository> Function() repository;
  final Future<void> Function() onImport;
  final Future<void> Function(String id) onOpen;
  final Future<bool> Function(String id) onDelete;
  @override
  State<ReaderLibraryView> createState() => _ReaderLibraryViewState();
}

class _ReaderLibraryViewState extends State<ReaderLibraryView> {
  late Future<List<ReaderDocument>> _documents = _load();
  bool _busy = false;
  String _filter = '';
  Future<List<ReaderDocument>> _load() async =>
      (await widget.repository()).list();
  void _reload() {
    if (!mounted) return;
    final next = _load();
    // FutureBuilder attaches on the next frame; observe early errors meanwhile.
    next.ignore();
    setState(() {
      _documents = next;
    });
  }

  void _message(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is DocumentStorageException
            ? error.message
            : '문서 저장 작업을 완료하지 못했습니다. 저장 공간과 파일 접근 권한을 확인해 주세요.')));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  Future<void> _rename(ReaderDocument doc) async {
    var input = doc.title;
    final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('문서 제목 변경'),
              content: TextFormField(
                  initialValue: input,
                  onChanged: (value) => input = value,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: '문서 제목')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, input),
                    child: const Text('저장'))
              ],
            ));
    if (title != null && mounted) {
      await _run(() async => (await widget.repository()).rename(doc.id, title));
    }
  }

  Future<void> _delete(ReaderDocument doc) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('PDF를 삭제할까요?'),
              content: Text('“${doc.title}”의 앱 관리 복사본과 읽기 기록을 삭제합니다.\n\n'
                  '원본 PDF와 저장한 단어·북마크·플래시카드는 유지합니다. 삭제된 문서로 돌아가는 기능은 사용할 수 없습니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final purged = await widget.onDelete(doc.id);
      if (!purged) {
        _message(const DocumentStorageException(
            '목록과 읽기 기록은 삭제했지만 파일 일부를 정리하지 못했습니다. 앱 저장 공간을 확인해 주세요.'));
      }
    });
  }

  String _description(ReaderDocument doc) =>
      '${doc.pageCount == null ? '페이지 수 확인 전' : '${doc.pageCount}쪽'} · '
      '${(doc.byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Expanded(
                  child: Text('최근 문서',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              IconButton(
                  tooltip: '목록 새로고침',
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                  onPressed: _busy ? null : () => _run(widget.onImport),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('PDF 열기')),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                'PDF는 이 기기·브라우저에 보관됩니다. 앱 삭제 또는 사이트 데이터 삭제 시 사라질 수 있으니 원본을 보관해 주세요.',
                style: TextStyle(fontSize: 12))),
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                  labelText: '문서 제목 검색', prefixIcon: Icon(Icons.search)),
              onChanged: (value) =>
                  setState(() => _filter = value.trim().toLowerCase()),
            )),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
            child: FutureBuilder<List<ReaderDocument>>(
                future: _documents,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                '문서 목록을 열지 못했습니다. 저장 공간과 접근 설정을 확인한 뒤 새로고침해 주세요.')));
                  }
                  final docs = snapshot.data!
                      .where((doc) => doc.title.toLowerCase().contains(_filter))
                      .toList();
                  if (docs.isEmpty) {
                    return Center(
                        child: Text(_filter.isEmpty
                            ? 'PDF를 가져오면 여기에 표시됩니다.'
                            : '제목이 일치하는 문서가 없습니다.'));
                  }
                  return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        return ListTile(
                          leading: IconButton(
                              tooltip: '문서 열기: ${doc.title}',
                              onPressed: _busy
                                  ? null
                                  : () => _run(() => widget.onOpen(doc.id)),
                              icon: const Icon(Icons.picture_as_pdf_outlined)),
                          title: Text(doc.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_description(doc)),
                          onTap: _busy
                              ? null
                              : () => _run(() => widget.onOpen(doc.id)),
                          trailing: PopupMenuButton<String>(
                              tooltip: '문서 관리: ${doc.title}',
                              enabled: !_busy,
                              onSelected: (value) => value == 'rename'
                                  ? _rename(doc)
                                  : _delete(doc),
                              itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'rename', child: Text('제목 변경')),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('삭제'))
                                  ]),
                        );
                      });
                })),
      ]);
}
