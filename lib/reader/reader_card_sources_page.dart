import 'package:flutter/material.dart';
import 'reader_learning.dart';
import 'reader_learning_store.dart';
import 'library/document_repository_factory.dart';

class ReaderCardSourcesPage extends StatefulWidget {
  const ReaderCardSourcesPage(
      {super.key, required this.cardId, required this.onOpen});
  final String cardId;
  final Future<void> Function(ReaderOccurrence) onOpen;
  @override
  State<ReaderCardSourcesPage> createState() => _ReaderCardSourcesPageState();
}

class _ReaderCardSourcesPageState extends State<ReaderCardSourcesPage> {
  late Future<({List<ReaderOccurrence> sources, Set<String> available})> _data =
      _load();
  Future<({List<ReaderOccurrence> sources, Set<String> available})>
      _load() async {
    final learning = await ReaderLearningStore.load();
    final sources = learning.occurrencesFor(widget.cardId);
    learning.dispose();
    if (sources.isEmpty) return (sources: sources, available: <String>{});
    final repo = await createDocumentRepository();
    final docs = await repo.list();
    final available = <String>{};
    for (final doc in docs) {
      if (sources.any((s) => s.documentId == doc.id) &&
          await repo.storage.available(doc.id)) {
        available.add(doc.id);
      }
    }
    return (sources: sources, available: available);
  }

  void _reload() {
    final next = _load();
    next.ignore();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('PDF 학습 출처')),
      body: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('출처 기록을 읽지 못했습니다. 기존 기록은 변경하지 않았습니다.'),
                TextButton(onPressed: _reload, child: const Text('다시 시도'))
              ]));
            }
            final data = snapshot.data!;
            if (data.sources.isEmpty) {
              return const Center(
                  child: Text('저장한 PDF 출처가 없습니다. Reader에서 단어를 선택해 저장하세요.'));
            }
            return ListView.builder(
                itemCount: data.sources.length,
                itemBuilder: (context, index) {
                  final source = data.sources[index];
                  final available = data.available.contains(source.documentId);
                  return ListTile(
                      title: Text(
                          '${source.documentTitle} · ${source.page}쪽 · 위치 ${index + 1}'),
                      subtitle: Text(
                          '${source.context}${available ? '' : '\n문서가 삭제되었거나 접근할 수 없습니다.'}'),
                      trailing: IconButton(
                          tooltip: 'PDF 원문 열기: 위치 ${index + 1}',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: available
                              ? () async {
                                  await widget.onOpen(source);
                                  if (mounted) {
                                    _reload();
                                  }
                                }
                              : null));
                });
          }));
}
