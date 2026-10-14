import 'package:flutter_test/flutter_test.dart';
import 'package:recall/recall_backup.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v3_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<RecallStore> populated() async {
    final store = await RecallStore.load();
    addTearDown(store.dispose);
    await store.importCsvDeck(
        csvText: v3Csv([
      for (final term in ['power', 'power factor', 'reactive power', 'voltage'])
        {
          'term_en': term,
          'primary_meaning_ko': 'meaning $term',
          'definition_en': 'Charge flows in $term.',
          'explanation_ko': 'explanation $term',
          'subject': 'Engineering / Circuits',
          'learning_priority': term == 'power' ? 'high' : 'medium',
          'vocabulary_type':
              term == 'power' ? 'general_technical' : 'technical',
        },
    ]));
    await store.addCard(
      deckId: '',
      front: 'Korean name',
      termEnglish: 'capacitor',
      abbreviation: 'C',
      meaning: 'stores charge',
      example: 'A power supply.',
      relatedTerms: ['dielectric'],
    );
    return store;
  }

  test('cached search preserves relevance, alphabetical order and all fields',
      () async {
    final store = await populated();
    final queries = [
      '',
      'power',
      ' PoW ',
      'c',
      'charge',
      'explanation',
      'meaning',
      'dielectric',
      'voltage',
      'nonexistent',
      for (var i = 0; i < 40; i++) 'query $i',
    ];
    // Independent reference for the pre-optimization search semantics.
    for (final query in queries) {
      final normalized = query.trim().toLowerCase();
      final expected = <({int score, RecallCard card})>[];
      for (final entry in store.allCards) {
        final card = entry.card;
        final names = [card.front, card.displayTerm, card.abbreviation]
            .map((s) => s.toLowerCase());
        final text = [
          for (final m in card.effectiveMeanings)
            '${m.meaningKo}\n${m.definition}\n${m.explanation}\n${m.exampleSentence}\n${m.exampleTranslation}',
          card.meaning,
          ...card.relatedTerms,
        ].join('\n').toLowerCase();
        final score = normalized.isEmpty
            ? 5
            : names.contains(normalized)
                ? 0
                : names.any((s) => s.startsWith(normalized))
                    ? 1
                    : names.any((s) => s.contains(normalized))
                        ? 2
                        : text.contains(normalized)
                            ? 3
                            : null;
        if (score != null) expected.add((score: score, card: card));
      }
      expected.sort((a, b) {
        final score = a.score.compareTo(b.score);
        return score != 0
            ? score
            : a.card.displayTerm
                .toLowerCase()
                .compareTo(b.card.displayTerm.toLowerCase());
      });
      expect(store.searchCards(query).map((e) => e.card.id),
          expected.map((e) => e.card.id),
          reason: query);
    }
    expect(store.searchCards('power').map((e) => e.card.displayTerm),
        ['power', 'power factor', 'reactive power', 'capacitor']);
  });

  test('view history and settings reuse immutable dictionary snapshots',
      () async {
    final store = await populated();
    final all = store.allCards;
    final matches = store.searchCards('PoW');
    final due = store.dueCards;
    final decks = store.decks;
    final categories = store.categories;
    final path = store.categoryPath(categories.last.id);
    final count = store.cardCountInCategory(categories.first.id);
    await store.recordCardViewed(matches.first.card.id);
    await store.setDailyGoal(10);
    await store.completeTutorial();
    expect(identical(store.allCards, all), isTrue);
    expect(identical(store.searchCards(' pow '), matches), isTrue);
    expect(identical(store.dueCards, due), isTrue);
    expect(identical(store.decks, decks), isTrue);
    expect(identical(store.categories, categories), isTrue);
    expect(identical(store.categoryPath(categories.last.id), path), isTrue);
    expect(store.cardCountInCategory(categories.first.id), count);
    expect(store.recentCards.single.card.id, matches.first.card.id);
    expect(() => matches.clear(), throwsUnsupportedError);
    expect(() => due.clear(), throwsUnsupportedError);
    expect(() => decks.single.cards.clear(), throwsUnsupportedError);
    expect(() => path.clear(), throwsUnsupportedError);
  });

  test('content edits and imports invalidate names, definitions and filters',
      () async {
    final store = await populated();
    final power = store.searchCards('power').first.card;
    final subject = store.categories.last.id;
    expect(store.cardCountInCategory(subject), 4);
    expect(store.searchCards('novel'), isEmpty);
    await store.updateCard(
        deckId: '',
        cardId: power.id,
        front: 'novel',
        termEnglish: 'novel',
        meaning: 'new meaning',
        example: '',
        categoryPaths: ['New subject'],
        meanings: const [
          VocabularyMeaning(
              id: 'new-meaning',
              meaningKo: 'new meaning',
              definitionEn: 'A novel definition.'),
        ],
        learningPriority: LearningPriority.low);
    expect(
        store.searchCards('power').any((e) => e.card.id == power.id), isFalse);
    expect(store.searchCards('novel').single.card.id, power.id);
    expect(store.searchCards('new meaning').single.card.id, power.id);
    expect(store.searchCards('', learningPriority: LearningPriority.high),
        isEmpty);
    expect(
        store
            .searchCards('', learningPriority: LearningPriority.low)
            .single
            .card
            .id,
        power.id);
    expect(store.cardCountInCategory(subject), 3);
    await store.importCsvDeck(
        csvText: v3Csv([
      {
        'term_en': 'novel',
        'primary_meaning_ko': 'alternative meaning',
        'definition_en': 'Unique definition',
        'subject': 'Engineering / Circuits'
      },
    ]));
    expect(store.searchCards('unique definition').single.card.id, power.id);
    expect(store.cardCountInCategory(subject), 4);
    await store.deleteEntries([power.id]);
    expect(store.searchCards('novel'), isEmpty);
    expect(store.searchCards('unique definition'), isEmpty);
    expect(store.cardCountInCategory(subject), 3);
  });

  test('deck filters stay separate and follow membership and rename changes',
      () async {
    final store = await populated();
    final originalId = store.decks.single.id;
    final power = store.searchCards('power').first.card;
    await store.createDeck('Selected');
    final selectedId = store.decks.last.id;
    expect(store.searchCards('power', deckId: selectedId), isEmpty);
    await store.addEntryToDeck(deckId: selectedId, cardId: power.id);
    expect(store.searchCards('power', deckId: selectedId).single.card.id,
        power.id);
    expect(store.searchCards('', deckId: originalId), hasLength(4));
    expect(store.searchCards('', deckId: 'missing'), isEmpty);
    await store.updateDeckName(originalId, 'Renamed');
    expect(store.searchCards('power').first.deck.name, 'Renamed');
    expect(store.deckById(originalId)!.name, 'Renamed');
    await store.deleteCard(deckId: originalId, cardId: power.id);
    expect(store.searchCards('power', deckId: originalId), hasLength(2));
    expect(store.searchCards('power', deckId: selectedId).single.deck.id,
        selectedId);
    await store.deleteDeck(selectedId);
    expect(store.searchCards('power', deckId: selectedId), isEmpty);
    expect(
        store.searchCards('power').any((e) => e.card.id == power.id), isFalse);
  });

  test('bookmarks and review state always return fresh cards and counts',
      () async {
    final store = await populated();
    final power = store.searchCards('power').first.card;
    expect(store.searchCards('', bookmarkedOnly: true), isEmpty);
    expect(store.dueCount, 5);
    expect(store.dueCards, hasLength(5));
    await store.toggleBookmark(power.id);
    expect(store.searchCards('', bookmarkedOnly: true).single.card.isBookmarked,
        isTrue);
    expect(store.bookmarkedCards.single.card.id, power.id);
    await store.markReviewed(power.id);
    expect(store.searchCards('power').first.card.lastReviewed, isNotNull);
    expect(store.decks.single.cards.first.lastReviewed, isNotNull);
    expect(
        store.dueCards
            .firstWhere((e) => e.card.id == power.id)
            .card
            .lastReviewed,
        isNotNull);
    await store.toggleReviewExclusion(power.id);
    expect(store.dueCount, 4);
    expect(store.dueCards, hasLength(4));
    await store.toggleReviewExclusion(power.id);
    expect(store.dueCount, 5);
    await store.toggleBookmark(power.id);
    expect(store.bookmarkedCards, isEmpty);
    expect(store.searchCards('', bookmarkedOnly: true), isEmpty);
  });

  test(
      'category counts deduplicate ancestors and refresh after subtree deletion',
      () async {
    final store = await populated();
    final root = store.categories.first;
    final child = store.categories.last;
    expect(store.cardCountInCategory(root.id), 4);
    expect(store.cardCountInCategory(child.id), 4);
    expect(store.cardCountInCategory('missing'), 0);
    expect(store.categoryPath('missing'), isEmpty);
    await store.setCategoryPinned(child.id, true);
    expect(store.categoryById(child.id)!.isPinned, isTrue);
    await expectLater(store.deleteCategory(root.id), throwsStateError);
    await store.setCategoryPinned(child.id, false);
    await store.deleteCategory(child.id);
    expect(store.categoryPath(child.id), isEmpty);
    expect(store.cardsInCategory(child.id), isEmpty);
    expect(store.cardCountInCategory(child.id), 0);
    expect(store.cardCountInCategory(root.id), 4);
    expect(store.totalCards, 5);
    final newChild = await store.createCategory('New child', parentId: root.id);
    expect(store.categoryPath(newChild.id), ['Engineering', 'New child']);
    expect(store.cardCountInCategory(newChild.id), 0);
  });

  test('restoring a backup replaces every cached result and category count',
      () async {
    final store = await populated();
    final backup = RecallBackup.parse(store.exportBackup());
    final root = store.categories.first.id;
    final child = store.categories.last.id;
    final deck = store.decks.single.id;
    final card = store.searchCards('power').first.card.id;
    await store.deleteCategory(root);
    await store.deleteEntries([card]);
    expect(store.searchCards('power', deckId: deck), hasLength(2));
    expect(store.cardCountInCategory(root), 0);
    expect(store.categoryPath(child), isEmpty);
    expect(store.dueCount, 4);
    await store.restoreBackup(backup);
    expect(store.searchCards('power', deckId: deck), hasLength(3));
    expect(store.cardCountInCategory(root), 4);
    expect(store.categoryPath(child), ['Engineering', 'Circuits']);
    expect(store.dueCount, 5);
    expect(store.deckById(deck)!.cards, hasLength(4));
  });
}
