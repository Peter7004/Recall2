import 'package:flutter/material.dart';
import '../recall_store.dart';
import 'personal_vocabulary_context.dart';

class PersonalVocabularyDialog extends StatefulWidget {
  const PersonalVocabularyDialog(
      {super.key,
      required this.store,
      required this.term,
      required this.sentence,
      required this.source});
  final RecallStore store;
  final String term, sentence, source;
  @override
  State<PersonalVocabularyDialog> createState() =>
      _PersonalVocabularyDialogState();
}

class _PersonalVocabularyDialogState extends State<PersonalVocabularyDialog> {
  final _form = GlobalKey<FormState>();
  late final _term =
      TextEditingController(text: normalizePersonalTerm(widget.term));
  final _meaning = TextEditingController(), _note = TextEditingController();
  late final _sentence = TextEditingController(text: widget.sentence);
  bool _saving = false, _allowDuplicate = false;
  String? _error;

  bool get _hasDuplicate => widget.store.allCards.any((entry) =>
      normalizePersonalTerm(entry.card.displayTerm).toLowerCase() ==
      normalizePersonalTerm(_term.text).toLowerCase());

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.all(14));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final term = normalizePersonalTerm(_term.text);
    if (_hasDuplicate && !_allowDuplicate) {
      setState(() => _error = '같은 단어가 있습니다. 다른 뜻이나 문맥으로 저장하려면 아래 항목을 체크하세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.addCard(
          personal: true,
          deckId: '',
          front: term,
          termEnglish: term,
          meaning: _meaning.text.trim(),
          example: _sentence.text.trim(),
          source: widget.source,
          sources: [
            VocabularySource(title: widget.source)
          ],
          meanings: [
            VocabularyMeaning(
                id: 'personal',
                meaningKo: _meaning.text.trim(),
                explanationKo: _note.text.trim(),
                exampleSentence: _sentence.text.trim())
          ]);
      if (mounted) Navigator.pop(context, true);
    } on RecallConcurrentWriteException catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = '저장하지 못했습니다. 입력 내용은 유지했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_term, _meaning, _note, _sentence]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          scrollable: true,
          title: const Text('내 단어장에 추가'),
          content: SizedBox(
              width: 480,
              child: Form(
                  key: _form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('단어와 뜻만 입력하면 저장할 수 있어요.',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: _term,
                            enabled: !_saving,
                            maxLength: 2000,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {
                                  _allowDuplicate = false;
                                  _error = null;
                                }),
                            decoration: _decoration('단어 또는 전문용어 *'),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? '단어를 입력하세요.' : null),
                        TextFormField(
                            controller: _meaning,
                            enabled: !_saving,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 3,
                            decoration: _decoration('내가 작성한 뜻 *',
                                hint: '이 문맥에서 이해한 뜻을 적어 주세요'),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? '뜻을 입력하세요.' : null),
                        const SizedBox(height: 24),
                        Text('학습 메모 · 선택 사항',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _note,
                            enabled: !_saving,
                            minLines: 1,
                            maxLines: 4,
                            decoration: _decoration('설명 / 메모 (선택)')),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _sentence,
                            enabled: !_saving,
                            minLines: 2,
                            maxLines: 5,
                            decoration: _decoration('원문 문장 (선택)',
                                hint: '필요한 문장을 직접 입력해도 좋아요')),
                        const SizedBox(height: 8),
                        Text('원문은 수정하거나 지울 수 있고, 카드 뒷면에 표시됩니다.',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('PDF 출처\n${widget.source}',
                                style: Theme.of(context).textTheme.bodySmall)),
                        if (_hasDuplicate)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _allowDuplicate,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(
                                      () => _allowDuplicate = v ?? false),
                              title: const Text('같은 단어가 있어도 별도 항목으로 저장')),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                              liveRegion: true,
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        ],
                      ]))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('취소')),
            FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(_saving ? '저장 중…' : '저장'))
          ]));
}
