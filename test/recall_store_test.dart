import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists deck cards, edits, simple review progress, and daily goal',
      () async {
    final store = await RecallStore.load();
    expect(store.decks, isEmpty);

    await store.createDeck('GRE words');
    final deck = store.decks.single;
    await store.addCard(
      deckId: deck.id,
      front: 'meticulous',
      meaning: '꼼꼼한',
      example: 'She is meticulous.',
    );
    final card = store.decks.single.cards.single;
    expect(store.dueCount, 1);

    await store.updateCard(
      deckId: deck.id,
      cardId: card.id,
      front: 'meticulous work',
      meaning: '매우 세심한 작업',
      example: 'The work was meticulous.',
    );
    await store.setDailyGoal(1);
    expect(store.remainingToday, 1);

    await store.markReviewed(card.id);
    expect(store.reviewsToday, 1);
    expect(store.remainingToday, 0);
    store.dispose();

    final restored = await RecallStore.load();
    final restoredDeck = restored.decks.single;
    final restoredCard = restoredDeck.cards.single;
    expect(restoredDeck.name, 'GRE words');
    expect(restoredCard.front, 'meticulous work');
    expect(restoredCard.meaning, '매우 세심한 작업');
    expect(restored.dailyGoal, 1);
    expect(restored.reviewsToday, 1);
    restored.dispose();
  });

  test('front and back values remain simple flashcard pairs', () async {
    final store = await RecallStore.load();
    await store.createDeck('Basics');
    await store.addCard(
      deckId: store.decks.single.id,
      front: 'apple',
      meaning: '사과',
      example: '',
    );

    final card = store.decks.single.cards.single;
    expect(card.front, 'apple');
    expect(card.meaning, '사과');
    expect(card.example, isEmpty);

    store.dispose();
  });

  test('bookmarks and card images persist across reloads', () async {
    final store = await RecallStore.load();
    await store.createDeck('Visual words');
    final deckId = store.decks.single.id;
    await store.addCard(
      deckId: deckId,
      front: 'apple',
      meaning: '사과',
      example: '',
      imageData: 'AQID',
    );
    final cardId = store.decks.single.cards.single.id;

    await store.toggleBookmark(cardId);
    await store.updateCard(
      deckId: deckId,
      cardId: cardId,
      front: 'apple',
      meaning: '사과',
      example: '',
      imageData: 'BAUG',
    );
    await store.completeTutorial();
    expect(store.bookmarkedCards, hasLength(1));
    expect(store.tutorialCompleted, isTrue);
    store.dispose();

    final restored = await RecallStore.load();
    final restoredCard = restored.decks.single.cards.single;
    expect(restoredCard.isBookmarked, isTrue);
    expect(restoredCard.imageData, 'BAUG');
    expect(restored.tutorialCompleted, isTrue);

    await restored.toggleBookmark(cardId);
    expect(restored.bookmarkedCards, isEmpty);
    restored.dispose();
  });

  test('repairs duplicate legacy card ids before editing or bookmarking',
      () async {
    SharedPreferences.setMockInitialValues({
      'recall.data.v1': jsonEncode({
        'decks': [
          {
            'id': 'deck',
            'name': 'Words',
            'cards': [
              {'id': 'duplicate', 'front': 'first', 'meaning': '첫째'},
              {'id': 'duplicate', 'front': 'second', 'meaning': '둘째'},
            ],
          },
        ],
      }),
    });

    final store = await RecallStore.load();
    final cards = store.decks.single.cards;
    expect(cards.map((card) => card.id).toSet(), hasLength(2));

    await store.toggleBookmark(cards[1].id);
    await store.updateCard(
      deckId: 'deck',
      cardId: cards[1].id,
      front: 'edited second',
      meaning: '수정된 둘째',
      example: '',
    );

    final updatedCards = store.decks.single.cards;
    expect(updatedCards[0].front, 'first');
    expect(updatedCards[0].isBookmarked, isFalse);
    expect(updatedCards[1].front, 'edited second');
    expect(updatedCards[1].isBookmarked, isTrue);
    store.dispose();
  });

  test('imports a CSV deck into a new deck', () async {
    final store = await RecallStore.load();
    final imported = await store.importCsvDeck(
      deckName: 'Imported vocab',
      csvText:
          'front,meaning,example\nmeticulous,꼼꼼한,She is meticulous.\nresilient,회복력 있는,They stayed resilient.',
    );

    expect(imported, 2);
    expect(store.decks, hasLength(1));
    expect(store.decks.single.name, 'Imported vocab');
    expect(store.decks.single.cards, hasLength(2));
    expect(store.decks.single.cards.first.front, 'meticulous');
    expect(store.decks.single.cards.first.meaning, '꼼꼼한');
    store.dispose();
  });

  test('skips Korean CSV headers and gives each imported card a unique id',
      () async {
    final store = await RecallStore.load();
    final imported = await store.importCsvDeck(
      csvText:
          '\uFEFF영어 단어, 뜻, 예문\napple,사과,I eat an apple.\nbook,책,This is my book.',
    );

    final cards = store.decks.single.cards;
    expect(imported, 2);
    expect(cards.map((card) => card.front), ['apple', 'book']);
    expect(cards.map((card) => card.id).toSet(), hasLength(2));
    store.dispose();
  });

  test('renames decks, excludes cards from review, and deletes selected cards',
      () async {
    final store = await RecallStore.load();
    await store.createDeck('Old title');
    final deckId = store.decks.single.id;
    await store.addCard(
      deckId: deckId,
      front: 'keep',
      meaning: '유지',
      example: '',
    );
    await store.addCard(
      deckId: deckId,
      front: 'remove',
      meaning: '삭제',
      example: '',
    );
    final cards = store.decks.single.cards;

    await store.updateDeckName(deckId, 'New title');
    await store.toggleReviewExclusion(cards[0].id);
    expect(store.decks.single.name, 'New title');
    expect(store.totalCards, 2);
    expect(store.dueCards.map((entry) => entry.card.front), ['remove']);

    await store.deleteCard(deckId: deckId, cardId: cards[1].id);
    expect(store.decks.single.cards.map((card) => card.front), ['keep']);
    expect(store.dueCards, isEmpty);
    store.dispose();

    final restored = await RecallStore.load();
    expect(restored.decks.single.name, 'New title');
    expect(restored.decks.single.cards.single.isExcludedFromReview, isTrue);
    expect(restored.dueCards, isEmpty);
    restored.dispose();
  });
}
