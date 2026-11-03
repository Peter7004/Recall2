import 'package:flutter/material.dart';
import 'reader_learning_store.dart';
import 'reader_learning.dart';
import '../vocabulary.dart';

class ReaderLearningView extends StatefulWidget {
  const ReaderLearningView(
      {super.key,
      required this.store,
      required this.documentIds,
      required this.cardById,
      required this.onSource,
      this.currentDocumentId});
  final ReaderLearningStore store;
  final Set<String> documentIds;
  final String? currentDocumentId;
  final RecallCard? Function(String id) cardById;
  final ValueChanged<ReaderOccurrence> onSource;
  @override
  State<ReaderLearningView> createState() => _ReaderLearningViewState();
}

class _ReaderLearningViewState extends State<ReaderLearningView> {
  bool _onlyCurrent = false;
  Future<void> _remove(ReaderSavedTerm term) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('저장한 단어 기록을 삭제할까요?'),
                content: const Text(
                    'Reader 학습 목록과 연결된 출처만 삭제합니다. 기존 사전 단어와 단어 북마크는 유지합니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'))
                ]));
    if (confirmed != true) return;
    try {
      await widget.store.removeTerm(term.cardId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is ReaderLearningStorageException
                ? error.message
                : '학습 기록을 삭제하지 못했습니다.')));
      }
    }
  }

  Future<void> _refresh() async {
    try {
      await widget.store.refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('최신 학습 기록을 읽지 못했습니다. 기존 기록은 유지했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final terms = widget.store.terms
            .where((term) =>
                !_onlyCurrent ||
                widget.store
                    .occurrencesFor(term.cardId,
                        documentId: widget.currentDocumentId)
                    .isNotEmpty)
            .toList();
        return Column(children: [
          Row(children: [
            const Expanded(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('저장한 단어·출처',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)))),
            IconButton(
                tooltip: '저장한 단어 닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close))
          ]),
          if (widget.store.synchronizationError != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Expanded(child: Text(widget.store.synchronizationError!)),
                  TextButton(onPressed: _refresh, child: const Text('기록 다시 읽기'))
                ])),
          if (widget.currentDocumentId != null)
            FilterChip(
                label: const Text('이 문서만'),
                selected: _onlyCurrent,
                onSelected: (value) => setState(() => _onlyCurrent = value)),
          Expanded(
              child: terms.isEmpty
                  ? const Center(
                      child: Text('저장한 단어가 없습니다. PDF에서 단어를 선택해 저장하세요.'))
                  : ListView.builder(
                      itemCount: terms.length,
                      itemBuilder: (context, index) {
                        final term = terms[index];
                        final card = widget.cardById(term.cardId);
                        final sources = widget.store.occurrencesFor(term.cardId,
                            documentId:
                                _onlyCurrent ? widget.currentDocumentId : null);
                        return ExpansionTile(
                            key: ValueKey(term.cardId),
                            maintainState: false,
                            title: Text(card?.displayTerm ?? term.term),
                            subtitle: Text(card?.meaning ?? term.meaning),
                            leading: const Icon(Icons.school_outlined),
                            children: [
                              if (term.definition.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(term.definition)),
                              if (term.explanation.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(term.explanation)),
                              for (final (index, source) in sources.indexed)
                                ListTile(
                                    title: Text(
                                        '${source.documentTitle} · ${source.page}쪽'),
                                    subtitle: Text(
                                        '${source.context}${widget.documentIds.contains(source.documentId) ? '' : '\n문서가 삭제되었거나 접근할 수 없습니다.'}'),
                                    trailing: IconButton(
                                        key: ValueKey(
                                            'reader-source-${source.id}'),
                                        tooltip:
                                            '원문으로 이동: ${source.documentTitle} · ${source.page}쪽 · 위치 ${index + 1}',
                                        icon: const Icon(Icons.open_in_new),
                                        onPressed: widget.documentIds
                                                .contains(source.documentId)
                                            ? () => widget.onSource(source)
                                            : null)),
                              TextButton.icon(
                                  onPressed: () => _remove(term),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('학습 목록에서 삭제')),
                            ]);
                      })),
        ]);
      });
}
