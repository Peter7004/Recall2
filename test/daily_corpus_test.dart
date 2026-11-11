import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/corpus/corpus_stats.dart';
import 'package:recall/main.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const focusKey = 'recall.learning.corpus-source.v1';
final catalog = CorpusCatalog.parse(
    '''term_en,textbook_tf,textbook_df,abstract_tf,abstract_df
Textbook term,20,5,2,1
Paper term,100,4,40,8
Tie term,19,5,100,7
Zero term,0,0,0,0
''');

Future<RecallStore> seeded(
    {CorpusCatalog? corpus, SharedPreferences? prefs}) async {
  final store =
      await RecallStore.load(corpus: corpus ?? catalog, storage: prefs);
  for (final term in [
    'Textbook term',
    'Paper term',
    'Tie term',
    'Zero term',
    'Personal term'
  ]) {
    await store.addCard(deckId: '', front: term, meaning: '뜻', example: '');
  }
  return store;
}

List<String> names(RecallStore store, {DateTime? now}) =>
    store.recommendationCards(now: now).map((e) => e.card.displayTerm).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'focus uses independent DF then TF, with no unknown/zero or excluded terms',
      () async {
    final store = await seeded();
    expect(names(store), ['Textbook term', 'Tie term', 'Paper term']);
    await store.setLearningSource(CorpusSource.abstracts);
    expect(names(store), ['Paper term', 'Tie term', 'Textbook term']);
    await store
        .toggleReviewExclusion(store.searchCards('Paper term').first.card.id);
    expect(names(store), ['Tie term', 'Textbook term']);
    expect(store.dueCards,
        hasLength(4)); // Manual full-dictionary study stays available.
  });

  test(
      'focus persists without rewriting vocabulary, Reader data or the daily goal',
      () async {
    final store = await seeded();
    await store.setDailyGoal(10);
    final id = store.searchCards('Textbook term').first.card.id;
    await store.toggleBookmark(id);
    await store.markReviewed(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recall.reader.learning.v1', 'keep reader records');
    final before = prefs.getString('recall.data.v3');
    await store.setLearningSource(CorpusSource.abstracts);
    expect(prefs.getString('recall.data.v3'), before);
    expect(prefs.getString('recall.reader.learning.v1'), 'keep reader records');
    final restored = await RecallStore.load(corpus: catalog);
    expect(restored.learningSource, CorpusSource.abstracts);
    expect(restored.dailyGoal, 10);
    expect(restored.reviewsToday, 1);
    expect(restored.cardById(id)!.toJson(), store.cardById(id)!.toJson());
    expect(names(restored), ['Paper term', 'Tie term']);
  });

  test('new words first, then oldest review day; no repeats on the same day',
      () async {
    await seeded();
    final prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(prefs.getString('recall.data.v3')!) as Map;
    for (final row in json['entries'] as List) {
      row['lastReviewed'] = switch (row['front']) {
        'Textbook term' => '2026-11-09T12:00:00',
        'Paper term' => '2026-11-08T12:00:00',
        _ => null,
      };
    }
    await prefs.setString('recall.data.v3', jsonEncode(json));
    final store = await RecallStore.load(corpus: catalog);
    expect(names(store, now: DateTime(2026, 11, 10)),
        ['Tie term', 'Paper term', 'Textbook term']);
    expect(
        names(store, now: DateTime(2026, 11, 9)), ['Tie term', 'Paper term']);
    expect(names(store, now: DateTime(2026, 11, 8)), ['Tie term']);
  });

  test('daily queue respects goal; switching focus does not reset progress',
      () async {
    final store = await seeded();
    await store.setDailyGoal(2);
    expect(store.todayStudyCards.map((e) => e.card.front),
        ['Textbook term', 'Tie term']);
    await store.markReviewed(store.todayStudyCards.first.card.id);
    await store.setLearningSource(CorpusSource.abstracts);
    expect(store.reviewsToday, 1);
    expect(store.todayStudyCards.single.card.front, 'Paper term');
    await store.markReviewed(store.todayStudyCards.single.card.id);
    expect(store.todayStudyCards, isEmpty);
    expect(store.remainingToday, 0);
    expect(store.recommendationCards().single.card.front, 'Tie term');
  });

  test(
      'missing statistics, no observations and invalid preference safely fall back',
      () async {
    SharedPreferences.setMockInitialValues({focusKey: 7});
    final store = await seeded(corpus: const CorpusCatalog.empty());
    expect(store.learningSource, CorpusSource.textbook);
    expect(store.hasCorpusLearningCandidates, isFalse);
    expect(names(store), store.dueCards.map((e) => e.card.front));
    final noMatches = await RecallStore.load(
        corpus: CorpusCatalog.parse(
            '${corpusColumns.join(',')}\nUnrelated,1,1,0,0'));
    expect(noMatches.hasCorpusLearningCandidates, isFalse);
    expect(names(noMatches), names(store));
    await noMatches.setLearningSource(CorpusSource.abstracts);
    expect(names(noMatches), names(store));
  });

  test('failed preference write retains the active focus and all study data',
      () async {
    final prefs = _PreferenceFailure(await SharedPreferences.getInstance());
    final store = await seeded(prefs: prefs);
    final before = prefs.getString('recall.data.v3');
    prefs.fail = true;
    await expectLater(
        store.setLearningSource(CorpusSource.abstracts), throwsStateError);
    expect(store.learningSource, CorpusSource.textbook);
    expect(prefs.getString('recall.data.v3'), before);
    prefs.fail = false;
    await store.setLearningSource(CorpusSource.abstracts);
    expect(store.learningSource, CorpusSource.abstracts);
  });

  testWidgets(
      'mobile focus updates the default session but preserves explicit cards',
      (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await seeded();
    await tester.pumpWidget(RecallApp(loadStore: () async => store));
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(ChoiceChip, '논문 초록 중심');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(store.learningSource, CorpusSource.abstracts);
    expect(tester.takeException(), isNull);
    final start = find.text('오늘 학습 시작하기');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Paper term'), findsOneWidget);
    await store.setLearningSource(CorpusSource.textbook);
    await tester.pumpAndSettle();
    expect(find.text('Textbook term'), findsOneWidget);
    expect(store.reviewsToday, 0);

    // HomeShell owns its store; exercise the standalone session with a live one.
    final explicitStore = await RecallStore.load(corpus: catalog);
    final explicit = [
      explicitStore.allCards.firstWhere((e) => e.card.front == 'Personal term')
    ];
    await tester.pumpWidget(MaterialApp(
        home: ReviewPage(store: explicitStore, initialCards: explicit)));
    await tester.pumpAndSettle();
    await explicitStore.setLearningSource(CorpusSource.abstracts);
    await tester.pumpAndSettle();
    expect(find.text('Personal term'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    explicitStore.dispose();
  });
}

class _PreferenceFailure extends Fake implements SharedPreferences {
  _PreferenceFailure(this.delegate);
  final SharedPreferences delegate;
  bool fail = false;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) async =>
      fail && key == focusKey ? false : delegate.setString(key, value);
  @override
  Future<void> reload() => delegate.reload();
}
