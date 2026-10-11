import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall/recall_backup.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<RecallStore> populated() async {
    final store = await RecallStore.load();
    await store.createDeck('Circuits');
    await store.addCard(
      deckId: store.decks.single.id,
      front: 'current',
      meaning: '전류',
      example: 'Current flows.',
      imageData: 'data:image/png;base64,AQID',
      termEnglish: 'current',
      categoryPaths: ['Engineering / Circuits'],
      vocabularyType: VocabularyType.technical,
      learningPriority: LearningPriority.high,
      inclusionRecommendation: InclusionRecommendation.include,
      priorityReason: 'Core term',
      collector: 'Teacher',
      notes: 'Keep this',
      partOfSpeech: ['noun'],
      relatedTerms: ['voltage'],
      meanings: const [
        VocabularyMeaning(
            id: 'meaning-1',
            meaningKo: '전류',
            type: MeaningType.technical,
            definitionEn: 'Flow of charge.',
            explanationKo: '전하의 흐름')
      ],
      sources: const [
        VocabularySource(title: 'Circuits textbook', year: '2026')
      ],
    );
    final id = store.allCards.single.card.id;
    await store.createDeck('Shared');
    await store.addEntryToDeck(deckId: store.decks.last.id, cardId: id);
    await store.setCategoryPinned(store.categories.first.id, true);
    await store.toggleBookmark(id);
    await store.toggleReviewExclusion(id);
    await store.markReviewed(id);
    await store.recordCardViewed(id);
    await store.addCard(
        deckId: '', front: 'voltage', meaning: '전압', example: '');
    await store.setDailyGoal(40);
    await store.completeTutorial();
    return store;
  }

  test('full backup round trip preserves canonical vocabulary and settings',
      () async {
    final store = await populated();
    final backup = RecallBackup.parse(store.exportBackup());
    expect(backup.entryCount, 2);
    expect(backup.deckCount, 2);
    final expected = backup.snapshot;
    await store.deleteDeck(store.decks.first.id);
    await store.restoreBackup(backup);
    expect(RecallBackup.parse(store.exportBackup()).snapshot, expected);
    expect(store.decks.every((d) => d.cards.single.isBookmarked), isTrue);
    expect(store.categories.first.isPinned, isTrue);
    expect(store.dailyGoal, 40);
    store.dispose();
    final reloaded = await RecallStore.load();
    expect(RecallBackup.parse(reloaded.exportBackup()).snapshot, expected);
    reloaded.dispose();
  });

  test('empty backup is valid and snapshots cannot be mutated by callers',
      () async {
    final store = await RecallStore.load();
    final backup = RecallBackup.parse(store.exportBackup());
    backup.snapshot['entries'] = ['bad'];
    await store.restoreBackup(backup);
    expect(store.totalCards, 0);
    store.dispose();
  });

  test('invalid or future backup leaves saved and live data unchanged',
      () async {
    final store = await populated();
    final before = RecallBackup.parse(store.exportBackup()).snapshot;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('recall.data.v3');
    final changes = <void Function(Map<String, dynamic>)>[
      (b) => b['backupVersion'] = 2,
      (b) => b['data']['schemaVersion'] = 4,
      (b) => b['data']['entries'].add(b['data']['entries'].first),
      (b) => b['data']['entries'].first['learning_priority'] = 'urgent',
      (b) => b['data']['entries'].first['dueAt'] = 'not a date',
      (b) => b['data']['entries'].first.remove('isBookmarked'),
      (b) => b['data']['decks'].first['entryIds'] = ['missing'],
      (b) => b['data']['categories'].first['parentId'] = 'missing',
      (b) => b['data']['categories'].first['parentId'] =
          b['data']['categories'].first['id'],
      (b) => b['data']['dailyGoal'] = 0,
      (b) => b['data']['unknownFutureSetting'] = true,
    ];
    for (final change in changes) {
      final envelope = jsonDecode(store.exportBackup()) as Map<String, dynamic>;
      change(envelope);
      expect(() => RecallBackup.parse(jsonEncode(envelope)),
          throwsFormatException);
    }
    expect(() => RecallBackup.parse('{'), throwsFormatException);
    expect(RecallBackup.parse(store.exportBackup()).snapshot, before);
    expect(preferences.getString('recall.data.v3'), saved);
    store.dispose();
  });

  test('failed restore does not mutate live data or poisoned preferences cache',
      () async {
    final source = await populated();
    final backup = RecallBackup.parse(source.exportBackup());
    source.dispose();
    SharedPreferences.setMockInitialValues({});
    final preferences =
        _ControlledPreferences(await SharedPreferences.getInstance());
    final target = await RecallStore.load(storage: preferences);
    await target.createDeck('Original');
    final before = RecallBackup.parse(target.exportBackup()).snapshot;
    preferences.fail = true;
    await expectLater(target.restoreBackup(backup), throwsStateError);
    expect(RecallBackup.parse(target.exportBackup()).snapshot, before);
    expect(jsonDecode(preferences.getString('recall.data.v3')!), before);
    preferences.fail = false;
    await target.restoreBackup(backup);
    expect(target.totalCards, 2);
    target.dispose();
  });

  test('restore blocks concurrent edits until its atomic write completes',
      () async {
    final preferences =
        _ControlledPreferences(await SharedPreferences.getInstance());
    final target = await RecallStore.load(storage: preferences);
    final backup = RecallBackup.parse(target.exportBackup());
    preferences.gate = Completer<bool>();
    final restoring = target.restoreBackup(backup);
    await Future<void>.delayed(Duration.zero);
    await expectLater(target.createDeck('Blocked'), throwsStateError);
    await expectLater(target.setDailyGoal(10), throwsStateError);
    preferences.gate!.complete(true);
    await restoring;
    expect(target.decks, isEmpty);
    await target.createDeck('Allowed');
    expect(target.decks.single.name, 'Allowed');
    target.dispose();
  });
}

class _ControlledPreferences extends Fake implements SharedPreferences {
  _ControlledPreferences(this.delegate);
  final SharedPreferences delegate;
  bool fail = false;
  Completer<bool>? gate;
  String? failedCache;
  @override
  String? getString(String key) => failedCache ?? delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) async {
    if (gate != null) await gate!.future;
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
