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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final term = normalizePersonalTerm(_term.text);
    final duplicate = widget.store.allCards.any((entry) =>
        normalizePersonalTerm(entry.card.displayTerm).toLowerCase() ==
        term.toLowerCase());
    if (duplicate && !_allowDuplicate) {
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
          title: const Text('내 단어장에 추가'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                                controller: _term,
                                enabled: !_saving,
                                maxLength: 2000,
                                decoration: const InputDecoration(
                                    labelText: '단어 또는 전문용어 *'),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? '단어를 입력하세요.'
                                    : null),
                            TextFormField(
                                controller: _meaning,
                                enabled: !_saving,
                                autofocus: true,
                                decoration: const InputDecoration(
                                    labelText: '내가 작성한 뜻 *'),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? '뜻을 입력하세요.'
                                    : null),
                            TextField(
                                controller: _note,
                                enabled: !_saving,
                                minLines: 1,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                    labelText: '설명 / 메모 (선택)')),
                            TextField(
                                controller: _sentence,
                                enabled: !_saving,
                                minLines: 2,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                    labelText: '원문 문장 (선택)',
                                    helperText:
                                        'PDF에서 가져온 문장은 수정하거나 지울 수 있습니다.')),
                            const SizedBox(height: 12),
                            Text('출처: ${widget.source}'),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _allowDuplicate,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(
                                        () => _allowDuplicate = v ?? false),
                                title: const Text('같은 단어가 있어도 별도 항목으로 저장')),
                            if (_error != null)
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                          ])))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('취소')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중…' : '저장'))
          ]));
}
