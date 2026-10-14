import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/bundled_vocabulary.dart';
import 'package:recall/csv_import.dart';
import 'package:recall/main.dart';
import 'package:recall/recall_backup.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BundledVocabulary catalog;
  setUpAll(() async {
    catalog = BundledVocabulary(
        version: BundledVocabulary.currentVersion,
        csvText: await File(BundledVocabulary.assetPath).readAsString());
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lazy built-in loader runs only before the catalog is persisted',
      () async {
    var loads = 0;
    Future<BundledVocabulary> loader() async {
      loads++;
      return catalog;
    }

    final first = await RecallStore.load(loadBundledVocabulary: loader);
    expect(loads, 1);
    expect(first.totalCards, 276);
    final erased = first.allCards.first.card.id;
    await first.deleteEntries([erased]);
    first.dispose();
    final reloaded = await RecallStore.load(loadBundledVocabulary: loader);
    expect(loads, 1);
    expect(reloaded.totalCards, 275);
    expect(reloaded.cardById(erased), isNull);
    reloaded.dispose();
  });

  test('failed lazy asset loading leaves the persisted dictionary intact',
      () async {
    final original = await RecallStore.load();
    await original.addCard(
        deckId: '', front: 'personal', meaning: 'mine', example: '');
    final preferences = await SharedPreferences.getInstance();
    final before = preferences.getString('recall.data.v3');
    original.dispose();
    await expectLater(RecallStore.load(loadBundledVocabulary: () async {
      throw StateError('Asset load failed');
    }), throwsStateError);
    expect(preferences.getString('recall.data.v3'), before);
    final reloaded =
        await RecallStore.load(loadBundledVocabulary: () async => catalog);
    expect(reloaded.searchCards('personal').single.card.primaryMeaning, 'mine');
    expect(reloaded.totalCards, 277);
    reloaded.dispose();
  });

  test('all 288 rows become 276 entries without losing alternative meanings',
      () async {
    expect(catalog.rows, hasLength(288));
    final store = await RecallStore.load(bundledVocabulary: catalog);
    expect(store.totalCards, 276);
    expect(store.decks.single.name, BundledVocabulary.deckName);
    expect(store.decks.single.cards, hasLength(276));
    final byKey = {
      for (final e in store.allCards) vocabularyKey(e.card): e.card
    };
    for (final row in catalog.rows) {
      final card = byKey[vocabularyKey(row.card)]!;
      expect(
          card.effectiveMeanings.any((m) =>
              m.meaningKo == row.card.primaryMeaning &&
              m.definitionEn == row.card.definitionEn &&
              m.explanationKo == row.card.explanationKo),
          isTrue,
          reason: '${row.number}: ${row.card.displayTerm}');
    }
    expect(byKey['skin effect']!.learningPriority, LearningPriority.high);
    expect(byKey['cda']!.vocabularyType, VocabularyType.generalTechnical);
    expect(byKey['cda']!.learningPriority, LearningPriority.low);
    expect(store.categories.map((c) => c.name), contains('전자기학'));
    RecallBackup.parse(store.exportBackup());
    store.dispose();
  });

  test('existing entries, IDs, bookmarks, subjects and progress are unchanged',
      () async {
    final original = await RecallStore.load();
    await original.createDeck('Personal');
    await original.addCard(
        deckId: original.decks.single.id,
        front: 'My Skin effect',
        termEnglish: 'SKIN EFFECT',
        meaning: '내가 작성한 뜻',
        example: 'Keep my example.',
        categoryNames: ['My subject'],
        learningPriority: LearningPriority.low);
    final id = original.allCards.single.card.id;
    await original.toggleBookmark(id);
    await original.toggleReviewExclusion(id);
    await original.markReviewed(id);
    await original.recordCardViewed(id);
    await original.setDailyGoal(15);
    final before = original.cardById(id)!.toJson();
    original.dispose();
    final updated = await RecallStore.load(bundledVocabulary: catalog);
    expect(updated.totalCards, 276);
    expect(updated.cardById(id)!.toJson(), before);
    expect(updated.decks.first.name, 'Personal');
    expect(updated.decks.last.cards.any((c) => c.id == id), isTrue);
    expect(updated.reviewsToday, 1);
    expect(updated.dailyGoal, 15);
    expect(updated.recentCards.single.card.id, id);
    updated.dispose();
  });

  test('relaunch is idempotent and respects deliberate deletion and edits',
      () async {
    final first = await RecallStore.load(bundledVocabulary: catalog);
    final erased = first.allCards.first.card;
    final edited = first.allCards.last.card;
    await first.deleteEntries([erased.id]);
    await first.updateCard(
        deckId: '',
        cardId: edited.id,
        front: edited.front,
        meaning: 'Personal edit',
        example: '');
    final before = RecallBackup.parse(first.exportBackup()).snapshot;
    first.dispose();
    final again = await RecallStore.load(bundledVocabulary: catalog);
    expect(again.totalCards, 275);
    expect(again.cardById(erased.id), isNull);
    expect(again.cardById(edited.id)!.primaryMeaning, 'Personal edit');
    expect(RecallBackup.parse(again.exportBackup()).snapshot, before);
    again.dispose();
  });

  test('deleted default collection stays deleted after backup restore',
      () async {
    final store = await RecallStore.load(bundledVocabulary: catalog);
    await store.deleteDeck(store.decks.single.id);
    final backup = RecallBackup.parse(store.exportBackup());
    expect(backup.entryCount, 0);
    SharedPreferences.setMockInitialValues({});
    final target = await RecallStore.load();
    await target.restoreBackup(backup);
    store.dispose();
    target.dispose();
    final restored = await RecallStore.load(bundledVocabulary: catalog);
    expect(restored.totalCards, 0);
    expect(restored.decks, isEmpty);
    restored.dispose();
  });

  test('older backups remain valid and initialize the catalog on next load',
      () async {
    final original = await RecallStore.load();
    await original.addCard(
        deckId: '', front: 'custom', meaning: '개인', example: '');
    final envelope =
        jsonDecode(original.exportBackup()) as Map<String, dynamic>;
    (envelope['data'] as Map).remove('bundledVocabularyVersion');
    final backup = RecallBackup.parse(jsonEncode(envelope));
    await original.restoreBackup(backup);
    original.dispose();
    final updated = await RecallStore.load(bundledVocabulary: catalog);
    expect(updated.totalCards, 277);
    expect(
        updated.searchCards('custom').single.card.primaryMeaning, '개인');
    updated.dispose();
  });

  test('future catalog adds only missing terms and keeps existing edits',
      () async {
    final first = await RecallStore.load(bundledVocabulary: catalog);
    final before = first.allCards.first.card.toJson();
    first.dispose();
    final next = BundledVocabulary(
        version: 2,
        csvText: '${recallV3Columns.join(',')}\n'
            'Skin effect,technical,Changed,noun,Changed,Changed,Changed,low,,include,,,\n'
            'New term,technical,새 용어,noun,Electronics,Definition.,설명,high,,include,,,');
    final updated = await RecallStore.load(bundledVocabulary: next);
    expect(updated.totalCards, 277);
    expect(updated.cardById(before['id'] as String)!.toJson(), before);
    expect(updated.decks, hasLength(1));
    expect(updated.decks.single.cards, hasLength(277));
    updated.dispose();
  });

  test('invalid catalog is rejected without touching saved data', () async {
    final store = await RecallStore.load();
    await store.createDeck('Keep');
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('recall.data.v3');
    expect(
        () => BundledVocabulary(
            version: 1,
            csvText: '${recallV3Columns.join(',')}\n'
                'term,invalid,뜻,noun,,,,medium,,include,,,'),
        throwsFormatException);
    expect(preferences.getString('recall.data.v3'), saved);
    store.dispose();
  });

  test('failed startup save retains the old snapshot and safely retries',
      () async {
    final original = await RecallStore.load();
    await original.createDeck('Keep');
    original.dispose();
    final preferences =
        _FailingPreferences(await SharedPreferences.getInstance());
    final before = preferences.getString('recall.data.v3');
    await expectLater(
        RecallStore.load(storage: preferences, bundledVocabulary: catalog),
        throwsStateError);
    expect(preferences.getString('recall.data.v3'), before);
    preferences.fail = false;
    final updated = await RecallStore.load(
        storage: preferences, bundledVocabulary: catalog);
    expect(updated.totalCards, 276);
    expect(updated.decks.first.name, 'Keep');
    updated.dispose();
  });

  testWidgets('default app loads bundled assets and searches definitions',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const RecallApp());
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.text('등록된 용어가 없습니다.'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Skin effect');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Skin effect'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Skin effect'));
    await tester.pumpAndSettle();
    expect(find.text(catalog.rows.first.card.definitionEn), findsOneWidget);
    expect(find.text(catalog.rows.first.card.explanationKo), findsOneWidget);
    expect(find.text('include'), findsNothing);
    expect(find.text('review'), findsNothing);
  });
}

class _FailingPreferences extends Fake implements SharedPreferences {
  _FailingPreferences(this.delegate);
  final SharedPreferences delegate;
  bool fail = true;
  String? failedCache;
  @override
  String? getString(String key) => failedCache ?? delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) async {
    if (fail) {
      failedCache = value;
      return false;
    }
    return delegate.setString(key, value);
  }

  @override
  Future<void> reload() async {
    failedCache = null;
    await delegate.reload();
  }
}
