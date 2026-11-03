import 'package:flutter/material.dart';
import 'reader_learning.dart';
import 'reader_learning_store.dart';
import 'library/document_repository_factory.dart';
import 'library/document_repository.dart';

class ReaderCardSourcesPage extends StatefulWidget {
  const ReaderCardSourcesPage(
      {super.key, required this.cardId, required this.onOpen, this.repository});
  final String cardId;
  final DocumentRepository? repository;
  final Future<void> Function(ReaderOccurrence) onOpen;
  @override
  State<ReaderCardSourcesPage> createState() => _ReaderCardSourcesPageState();
}

class _ReaderCardSourcesPageState extends State<ReaderCardSourcesPage> {
  Future<DocumentRepository> _getRepository() async =>
      widget.repository ?? await createDocumentRepository();
  bool _opening = false;
  late Future<({List<ReaderOccurrence> sources, Set<String> available})> _data =
      _load();
  Future<({List<ReaderOccurrence> sources, Set<String> available})>
      _load() async {
    final learning = await ReaderLearningStore.load();
    final sources = learning.occurrencesFor(widget.cardId);
    learning.dispose();
    if (sources.isEmpty) return (sources: sources, available: <String>{});
    final repo = await _getRepository();
    final available = await repo
        .availableDocumentIds(sources.map((source) => source.documentId));
    return (sources: sources, available: available);
  }

  Future<void> _open(ReaderOccurrence source) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final repo = await _getRepository();
      if (!(await repo.availableDocumentIds([source.documentId]))
          .contains(source.documentId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('문서가 삭제되었거나 접근할 수 없습니다. 원본 PDF를 다시 가져와 주세요.')));
        }
        return;
      }
      if (mounted) await widget.onOpen(source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('원문을 열지 못했습니다. 기존 학습 기록은 유지했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        _reload();
      }
    }
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
                          onPressed: available && !_opening
                              ? () => _open(source)
                              : null));
                });
          }));
}
