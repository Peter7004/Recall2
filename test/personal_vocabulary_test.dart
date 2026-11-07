import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/recall_store.dart';
import 'package:recall/reader/personal_vocabulary_context.dart';
import 'package:recall/reader/personal_vocabulary_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('context uses the selected occurrence and joins line breaks', () {
    const text =
        'The reactance is small. The reactance of an AC\ncircuit depends on frequency.';
    final start = text.lastIndexOf('reactance');
    expect(personalSentence(text, start, start + 9),
        'The reactance of an AC circuit depends on frequency.');
    expect(normalizePersonalTerm('  reactive\n power  '), 'reactive power');
  });
  test('incomplete and ambiguous sentences remain empty', () {
    expect(personalSentence('The reactance is', 4, 13), '');
    expect(personalSentence('See Fig. Reactance is shown.', 9, 18), '');
    expect(personalSentence('The\n\nreactance is shown.', 6, 15), '');
    expect(personalSentence('Column\t reactance.', 8, 17), '');
    expect(personalSentence('Hello.', -1, 2), '');
  });
  test(
      'personal duplicates survive reload, editing and deletion without changing base cards or reviews',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '', front: 'power', meaning: '기본 뜻', example: '');
    final original = store.allCards.single.card;
    await store.markReviewed(original.id);
    final reviewed = store.cardById(original.id)!.toJson();
    for (final meaning in ['내 뜻', '다른 뜻']) {
      await store.addCard(
          personal: true,
          deckId: '',
          front: 'power',
          meaning: meaning,
          example: 'Power is measured here.',
          source: 'book.pdf · 3쪽',
          meanings: [
            VocabularyMeaning(
                id: 'personal',
                meaningKo: meaning,
                explanationKo: '내 메모',
                exampleSentence: 'Power is measured here.')
          ]);
    }
    final restored = await RecallStore.load();
    expect(restored.allCards.length, 3);
    expect(restored.cardById(original.id)!.toJson(), reviewed);
    final personal =
        restored.allCards.where((e) => e.card.isPersonal).first.card;
    expect(personal.example, 'Power is measured here.');
    expect(personal.effectiveMeanings.single.explanationKo, '내 메모');
    expect(personal.source, 'book.pdf · 3쪽');
    expect(restored.dueCards.any((e) => e.card.id == personal.id), isTrue);
    await restored.updateCard(
        deckId: '',
        cardId: personal.id,
        front: 'power',
        meaning: '수정',
        example: '',
        termEnglish: 'power');
    expect(restored.cardById(personal.id)!.isPersonal, isTrue);
    await restored.deleteEntries([personal.id]);
    expect((await RecallStore.load()).allCards.length, 2);
    expect(restored.cardById(original.id)!.toJson(), reviewed);
  });
  test('normal additions never merge into a personal entry', () async {
    final store = await RecallStore.load();
    await store.addCard(
        personal: true,
        deckId: '',
        front: 'power',
        meaning: '내 뜻',
        example: '');
    await store.addCard(
        deckId: '', front: 'power', meaning: '일반 뜻', example: '');
    expect(store.allCards.length, 2);
    expect(store.allCards.first.card.primaryMeaning, '내 뜻');
  });
  test('personal save rejects stale stores without overwriting another edit',
      () async {
    final first = await RecallStore.load();
    final stale = await RecallStore.load();
    await first.addCard(
        deckId: '', front: 'voltage', meaning: '전압', example: '');
    await expectLater(
        stale.addCard(
            personal: true,
            deckId: '',
            front: 'power',
            meaning: '내 뜻',
            example: ''),
        throwsA(isA<RecallConcurrentWriteException>()));
    expect(
        (await RecallStore.load()).allCards.single.card.displayTerm, 'voltage');
  });
  test('failed personal save rolls back and can be retried', () async {
    final preferences =
        _FailingPreferences(await SharedPreferences.getInstance());
    final store = await RecallStore.load(storage: preferences);
    final before = preferences.getString('recall.data.v3');
    preferences.failWrites = true;
    await expectLater(
        store.addCard(
            personal: true,
            deckId: '',
            front: 'power',
            meaning: '내 뜻',
            example: ''),
        throwsStateError);
    expect(store.allCards, isEmpty);
    expect(preferences.getString('recall.data.v3'), before);
    preferences.failWrites = false;
    await store.addCard(
        personal: true,
        deckId: '',
        front: 'power',
        meaning: '내 뜻',
        example: '');
    expect((await RecallStore.load()).allCards.single.card.isPersonal, isTrue);
  });
  testWidgets(
      'manual dialog requires a meaning, preserves optional context and warns on duplicates',
      (tester) async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '', front: 'reactive power', meaning: '기존', example: '');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => PersonalVocabularyDialog(
                        store: store,
                        term: ' reactive\n power ',
                        sentence: '',
                        source: 'book.pdf · 2쪽')),
                child: const Text('열기')))));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('reactive power'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('뜻을 입력하세요.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '내가 쓴 뜻');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('같은 단어가 있습니다.'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.allCards.length, 2);
    expect(store.allCards.last.card.isPersonal, isTrue);
  });
  testWidgets(
      'compact dialog scrolls with keyboard and hides irrelevant duplicate option',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final store = await RecallStore.load();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PersonalVocabularyDialog(
                store: store,
                term: 'new term',
                sentence: '',
                source:
                    'A very long electrical engineering document title.pdf · 12쪽'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('저장').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.textContaining('PDF 출처'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF 출처').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FailingPreferences extends Fake implements SharedPreferences {
  _FailingPreferences(this.delegate);
  final SharedPreferences delegate;
  bool failWrites = false;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) =>
      failWrites ? Future.value(false) : delegate.setString(key, value);
  @override
  Future<void> reload() => delegate.reload();
}
