import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'v3_fixtures.dart';

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
    expect(store.searchCards('remove'), hasLength(1));
    expect(store.dueCards.map((entry) => entry.card.front), ['remove']);
    store.dispose();

    final restored = await RecallStore.load();
    expect(restored.decks.single.name, 'New title');
    expect(restored.decks.single.cards.single.isExcludedFromReview, isTrue);
    expect(restored.dueCards.map((entry) => entry.card.front), ['remove']);
    restored.dispose();
  });

  test('imports extended dictionary CSV and searches terms and categories',
      () async {
    final store = await RecallStore.load();
    const csvText = 'id,term_ko,term_en,abbreviation,definition,category,'
        'subcategory,symbol,formula,unit,related_terms,source\n'
        'v1,전압,electric potential,V,두 점 사이의 전위차,전력공학,'
        '전력계통,V,"V = W/Q",V,전위;전기장,기초전기공학\n'
        'v2,전압,electric potential,V,두 점 사이의 전위차,전자기학,'
        '자기장,V,"V = W/Q",V,자기유도,기초전기공학\n'
        ',,missing,,,,,,,,';
    expect(store.previewCsvImport(csvText), 1);
    expect(store.decks, isEmpty);
    final report = await store.importCsvDeckDetailed(
      deckName: '전력 용어',
      csvText: csvText,
    );

    expect(report.importedCount, 1);
    expect(report.duplicateCount, 1);
    expect(report.invalidRowCount, 1);
    final entry = store.searchCards('electric potential').single;
    expect(entry.card.front, '전압');
    expect(entry.card.termEnglish, 'electric potential');
    expect(entry.card.abbreviation, 'V');
    expect(entry.card.meaning, '두 점 사이의 전위차');
    expect(entry.card.formula, 'V = W/Q');
    expect(entry.card.relatedTerms, ['전위', '전기장', '자기유도']);

    final category = store.categories.firstWhere((item) => item.name == '전력계통');
    expect(store.cardsInCategory(category.id).single.card.id, entry.card.id);
    final secondCategory =
        store.categories.firstWhere((item) => item.name == '자기장');
    expect(
        store.cardsInCategory(secondCategory.id).single.card.id, entry.card.id);
    expect(store.searchCards('전위차').single.card.id, entry.card.id);
    store.dispose();
  });

  test('recently viewed terms are deduplicated and persist', () async {
    final store = await RecallStore.load();
    await store.createDeck('전기기초');
    final deckId = store.decks.single.id;
    await store.addCard(
      deckId: deckId,
      front: '저항',
      meaning: '전류 흐름을 방해하는 정도',
      example: '',
    );
    final cardId = store.decks.single.cards.single.id;

    await store.recordCardViewed(cardId);
    await store.recordCardViewed(cardId);
    expect(store.recentCards, hasLength(1));
    store.dispose();

    final restored = await RecallStore.load();
    expect(restored.recentCards.single.card.id, cardId);
    expect(restored.recentCards, hasLength(1));
    restored.dispose();
  });

  test('deleting a collection leaves unrelated collections intact', () async {
    final store = await RecallStore.load();
    await store.createDeck('회로이론');
    final deletedId = store.decks.single.id;
    await store.addCard(
      deckId: deletedId,
      front: '옴의 법칙',
      meaning: 'V = IR',
      example: '',
    );
    await store.createDeck('전자기학');
    final preservedId = store.decks.last.id;
    await store.addCard(
      deckId: preservedId,
      front: '자기장',
      meaning: '자기력이 작용하는 공간',
      example: '',
    );

    await store.deleteDeck(deletedId);
    expect(store.decks, hasLength(1));
    expect(store.decks.single.id, preservedId);
    expect(store.totalCards, 1);
    expect(store.searchCards('옴의 법칙'), isEmpty);
    store.dispose();
  });

  test('legacy three types map to two without losing meanings or sources',
      () async {
    final store = await RecallStore.load();
    const csv =
        'term_en,vocabulary_type,primary_meaning_ko,meaning_type,part_of_speech,subject,definition,explanation,example_sentence,example_translation,formula,symbol,unit,application_context,verification_status,source_title,source_author,source_year,source_url,source_license\n'
        'maintain,general,유지하다,general,verb,,Keep in a state,,Maintain the system.,시스템을 유지하라.,,,,,needs_review,,,,,\n'
        'current,general_technical,현재의,general,adjective,Circuit Theory,At the present time,,The current system works.,현재 시스템은 작동한다.,,,,,ai_draft,,,,,\n'
        'current,general_technical,전류,technical,noun,Circuit Theory,Rate of charge flow,시간당 이동하는 전하량,Current flows.,전류가 흐른다.,i = dq/dt,I,A,Circuit analysis,ai_draft,User supplied text,A. Author,2024,https://example.org/text,CC BY\n'
        'impedance,technical,임피던스,technical,noun,Electronics,Voltage to current ratio,교류에 대한 전압과 전류의 비,,,,,,,needs_review,,,,,';
    final preview = store.previewCsvImportDetailed(csv);
    expect(preview.errors, isEmpty);
    expect(preview.newEntryCount, 3);
    expect(store.totalCards, 0);
    final report = await store.importCsvDeckDetailed(csvText: csv);
    expect(report.importedCount, 3);
    final current = store.searchCards('CURRENT').first.card;
    expect(current.vocabularyType, VocabularyType.generalTechnical);
    expect(current.meanings, hasLength(2));
    expect(current.partOfSpeech, containsAll(['adjective', 'noun']));
    expect(current.meanings.last.formula, 'i = dq/dt');
    expect(current.sources.single.author, 'A. Author');
    expect(current.verificationStatus, VerificationStatus.aiDraft);
    expect(store.searchCards('전류').map((e) => e.card.id), contains(current.id));
    expect(
        store.searchCards('', vocabularyType: VocabularyType.generalTechnical),
        hasLength(2));
    expect(
        store
            .searchCards('maintain')
            .single
            .card
            .extraFields['legacy_vocabulary_type'],
        'general');
    final subject = store.categories.firstWhere((s) => s.name == '회로이론');
    expect(store.searchCards('', categoryId: subject.id).single.card.id,
        current.id);
    await store.toggleBookmark(current.id);
    for (final card in store.decks.single.cards) {
      await store.deleteCard(deckId: store.decks.single.id, cardId: card.id);
    }
    await store.deleteDeck(store.decks.single.id);
    expect(store.totalCards, 3);
    expect(store.bookmarkedCards.single.card.id, current.id);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.cardById(current.id)!.meanings, hasLength(2));
    expect(restored.cardById(current.id)!.sources.single.license, 'CC BY');
    expect(restored.bookmarkedCards, hasLength(1));
    expect(restored.decks, isEmpty);
    expect(restored.cardById(current.id)!.reviewAnswer, contains('전류'));
    expect(
        restored.searchCards('impedance').single.card.meanings.single.formula,
        isEmpty);
    restored.dispose();
  });

  test(
      'CSV preserves UTF-8, multiline quotes, leading zero ids and unknown columns',
      () async {
    final store = await RecallStore.load();
    final csv = utf8.decode(utf8.encode(
        '\uFEFFid,word,meaning,example_sentence,custom_note\r\n'
        '0001,power,전력,"Power, measured in watts.\r\nHe said ""power"".",검토 메모'));
    final preview = store.previewCsvImportDetailed(csv);
    expect(preview.unknownHeaders, ['custom_note']);
    await store.importCsvDeckDetailed(csvText: csv);
    final card = store.searchCards('power').single.card;
    expect(card.id, '0001');
    expect(card.example, 'Power, measured in watts.\nHe said "power".');
    expect(card.extraFields['custom_note'], '검토 메모');
    expect(card.primaryMeaning, '전력');
    store.dispose();
  });

  test('repeated imports link one global entry without repeating meanings',
      () async {
    final store = await RecallStore.load();
    const csv = 'word,meaning,example_sentence\napple,사과,An apple.';
    await store.importCsvDeckDetailed(csvText: csv, deckName: 'First');
    final id = store.allCards.single.card.id;
    await store.toggleBookmark(id);
    final preview = store.previewCsvImportDetailed(csv);
    expect(preview.newEntryCount, 0);
    expect(preview.existingEntryCount, 1);
    final report =
        await store.importCsvDeckDetailed(csvText: csv, deckName: 'Second');
    expect(report.importedCount, 0);
    expect(report.linkedCount, 1);
    expect(store.totalCards, 1);
    expect(store.decks.map((d) => d.cards.single.id).toSet(), {id});
    expect(store.cardById(id)!.meanings, hasLength(1));
    await store.deleteCard(deckId: store.decks.first.id, cardId: id);
    expect(store.decks.first.cards, isEmpty);
    expect(store.decks.last.cards.single.isBookmarked, isTrue);
    await store.deleteDeck(store.decks.last.id);
    expect(store.bookmarkedCards, isEmpty);
    expect(store.decks.single.cards, isEmpty);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.totalCards, 0);
    expect(restored.bookmarkedCards, isEmpty);
    restored.dispose();
  });

  test('CSV reports invalid records and rejects malformed headers and quotes',
      () async {
    final store = await RecallStore.load();
    final preview = store
        .previewCsvImportDetailed('term_en,vocabulary_type,primary_meaning_ko\n'
            'good,general,좋은\nbad,unknown,나쁜\nmissing,general,');
    expect(preview.newEntryCount, 1);
    expect(preview.errors, hasLength(2));
    expect(preview.errors.first, contains('3번째 레코드'));
    expect(() => store.previewCsvImport('word,meaning\na,"unclosed'),
        throwsA(isA<FormatException>()));
    expect(() => store.previewCsvImport('word,term_en,meaning\na,a,뜻'),
        throwsA(isA<FormatException>()));
    expect(() => store.previewCsvImport('word,type\na,general'),
        throwsA(isA<FormatException>()));
    final report =
        await store.importCsvDeckDetailed(csvText: 'word,meaning\n,\nvalid,유효');
    expect(report.importedCount, 1);
    store.dispose();
  });

  test(
      'migration retains original v1 save, ids, images, bookmarks and review history',
      () async {
    final encoded = jsonEncode({
      'decks': [
        {
          'id': 'legacy',
          'name': 'Old',
          'cards': [
            {
              'id': 'old-word',
              'front': '전류',
              'meaning': '전하의 흐름',
              'termEnglish': 'current',
              'formula': 'i = dq/dt',
              'isBookmarked': true,
              'imageData': 'AQID',
              'isExcludedFromReview': true,
              'lastReviewed': '2025-01-01T00:00:00.000'
            },
          ]
        }
      ],
      'dailyGoal': 10,
      'tutorialCompleted': true
    });
    SharedPreferences.setMockInitialValues({'recall.data.v1': encoded});
    final store = await RecallStore.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recall.data.v1'), encoded);
    final saved = jsonDecode(prefs.getString('recall.data.v3')!) as Map;
    expect(saved['schemaVersion'], 3);
    expect((saved['decks'] as List).single['entryIds'], ['old-word']);
    expect((saved['decks'] as List).single.containsKey('cards'), isFalse);
    final card = store.cardById('old-word')!;
    expect(card.front, '전류');
    expect(card.meanings.single.definition, '전하의 흐름');
    expect(card.meanings.single.formula, 'i = dq/dt');
    expect(card.imageData, 'AQID');
    expect(card.isBookmarked, isTrue);
    expect(card.lastReviewed, DateTime(2025));
    expect(store.dueCards, isEmpty);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.decks.single.cards.single.id, 'old-word');
    restored.dispose();
  });

  test('corrupt saves fail without being overwritten', () async {
    SharedPreferences.setMockInitialValues({'recall.data.v1': '{broken'});
    await expectLater(RecallStore.load(), throwsA(isA<FormatException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recall.data.v1'), '{broken');
    expect(prefs.getString('recall.data.v2'), isNull);
    expect(prefs.getString('recall.data.v3'), isNull);
  });

  test('related terms resolve without requiring collection membership',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'resistance',
        meaning: '저항',
        example: '',
        relatedTerms: ['impedance']);
    await store.addCard(
        deckId: '', front: 'impedance', meaning: '임피던스', example: '');
    expect(store.resolveRelatedTerm('IMPEDANCE')!.primaryMeaning, '임피던스');
    expect(store.resolveRelatedTerm('missing'), isNull);
    expect(store.decks, isEmpty);
    expect(store.categories, isEmpty);
    store.dispose();
  });

  test(
      'shared entry edits propagate to every collection and review stays unique',
      () async {
    final store = await RecallStore.load();
    await store.createDeck('First');
    final first = store.decks.single.id;
    await store.addCard(
        deckId: first, front: 'maintain', meaning: '유지하다', example: '');
    final id = store.allCards.single.card.id;
    await store.createDeck('Second');
    await store.addEntryToDeck(deckId: store.decks.last.id, cardId: id);
    await store.updateCard(
        deckId: first,
        cardId: id,
        front: 'maintain',
        meaning: '보존하다',
        example: 'Maintain it.');
    expect(store.decks.every((d) => d.cards.single.meaning == '보존하다'), isTrue);
    expect(store.dueCount, 1);
    await store.markReviewed(id);
    expect(store.reviewsToday, 1);
    expect(store.cardById(id)!.lastReviewed, isNotNull);
    store.dispose();
  });

  test('duplicate legacy term names remain editable after safe migration',
      () async {
    SharedPreferences.setMockInitialValues({
      'recall.data.v1': jsonEncode({
        'decks': [
          {
            'id': 'old',
            'name': 'Old',
            'cards': [
              {'id': 'a', 'front': 'current', 'meaning': '현재의'},
              {'id': 'b', 'front': 'current', 'meaning': '흐름'},
            ]
          }
        ],
      })
    });
    final store = await RecallStore.load();
    await store.updateCard(
        deckId: 'old',
        cardId: 'b',
        front: 'current',
        meaning: '전류',
        example: '');
    expect(store.cardById('a')!.meaning, '현재의');
    expect(store.cardById('b')!.meaning, '전류');
    store.dispose();
  });

  test('merging an AI draft into a verified entry does not verify new content',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'current',
        meaning: '현재의',
        example: '',
        verificationStatus: VerificationStatus.verified,
        meanings: const [VocabularyMeaning(id: 'g', meaningKo: '현재의')]);
    await store.importCsvDeck(
        csvText:
            'term_en,vocabulary_type,primary_meaning_ko,meaning_type,verification_status\n'
            'current,general_technical,전류,technical,ai_draft');
    expect(store.totalCards, 1);
    expect(store.allCards.single.card.vocabularyType,
        VocabularyType.generalTechnical);
    expect(store.allCards.single.card.verificationStatus,
        VerificationStatus.aiDraft);
    store.dispose();
  });

  test(
      'partial case-insensitive search includes multiword technical expressions',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'power',
        meaning: '전력',
        example: '',
        vocabularyType: VocabularyType.generalTechnical);
    await store.addCard(
        deckId: '',
        front: 'power factor',
        meaning: '역률',
        example: '',
        vocabularyType: VocabularyType.technical,
        categoryNames: const ['Power Engineering']);
    expect(store.searchCards('PoW').map((e) => e.card.displayTerm),
        ['power', 'power factor']);
    expect(store.searchCards('역률').single.card.displayTerm, 'power factor');
    expect(
        store
            .searchCards('power', vocabularyType: VocabularyType.technical)
            .single
            .card
            .displayTerm,
        'power factor');
    expect(store.searchCards('power factor').first.card.meanings.single.formula,
        isEmpty);
    store.dispose();
  });

  test('fixed v3 columns import every field, defaults and management metadata',
      () async {
    final store = await RecallStore.load();
    final csv = v3Csv([
      {
        'term_en': 'impedance',
        'vocabulary_type': 'technical',
        'primary_meaning_ko': '임피던스',
        'part_of_speech': 'noun',
        'subject': 'Circuit Theory;Electronics',
        'definition_en':
            'Opposition to alternating current, including reactance.',
        'explanation_ko': '교류의 흐름을 방해하는 정도',
        'learning_priority': 'high',
        'priority_reason': '핵심 어휘',
        'inclusion_recommendation': 'exclude',
        'collector': 'Researcher',
        'source_title': 'User-supplied notes',
        'notes': '관리 메모\n두 번째 줄',
      },
      {'term_en': 'maintain', 'primary_meaning_ko': '유지하다'},
    ]);
    final preview = store.previewCsvImportDetailed('\uFEFF$csv');
    expect(preview.errors, isEmpty);
    expect(preview.unknownHeaders, isEmpty);
    expect(store.totalCards, 0);
    await store.importCsvDeck(csvText: csv);
    final card = store.searchCards('impedance').single.card;
    expect(card.vocabularyType, VocabularyType.technical);
    expect(card.learningPriority, LearningPriority.high);
    expect(card.definitionEn, contains('including reactance'));
    expect(card.explanationKo, '교류의 흐름을 방해하는 정도');
    expect(card.priorityReason, '핵심 어휘');
    expect(card.inclusionRecommendation, InclusionRecommendation.exclude);
    expect(card.collector, 'Researcher');
    expect(card.notes, '관리 메모\n두 번째 줄');
    expect(card.sources.single.title, 'User-supplied notes');
    expect(store.categoryNamesForCard(card), contains('회로이론'));
    expect(store.categoryNamesForCard(card), contains('전자공학'));
    expect(store.dueCount,
        2); // A recommendation is not a learner review exclusion.
    expect(store.searchCards('reactance').single.card.id, card.id);
    expect(store.searchCards('방해').single.card.id, card.id);
    expect(store.searchCards('Researcher'), isEmpty);
    final maintain = store.searchCards('maintain').single.card;
    expect(maintain.vocabularyType, VocabularyType.generalTechnical);
    expect(maintain.learningPriority, LearningPriority.medium);
    expect(maintain.inclusionRecommendation, InclusionRecommendation.review);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.cardById(card.id)!.notes, card.notes);
    expect(restored.cardById(card.id)!.learningPriority, LearningPriority.high);
    expect(restored.cardById(card.id)!.inclusionRecommendation,
        InclusionRecommendation.exclude);
    expect(restored.cardById(card.id)!.meanings.single.toJson(),
        containsPair('definition_en', card.definitionEn));
    restored.dispose();
  });

  test('v3 rejects wrong header order, width, missing cells and invalid enums',
      () async {
    final store = await RecallStore.load();
    final valid = v3Csv([
      {'term_en': 'current', 'primary_meaning_ko': '전류'}
    ]);
    expect(
        () => store.previewCsvImport(valid.replaceFirst(
            'term_en,vocabulary_type', 'vocabulary_type,term_en')),
        throwsA(isA<FormatException>()));
    expect(() => store.previewCsvImport(valid.replaceFirst(',notes', '')),
        throwsA(isA<FormatException>()));
    expect(
        () => store
            .previewCsvImport(valid.replaceFirst(',notes', ',notes,extra')),
        throwsA(isA<FormatException>()));
    final preview = store.previewCsvImportDetailed(v3Csv([
      {'term_en': 'a', 'primary_meaning_ko': '뜻', 'vocabulary_type': 'general'},
      {
        'term_en': 'b',
        'primary_meaning_ko': '뜻',
        'learning_priority': 'urgent'
      },
      {
        'term_en': 'c',
        'primary_meaning_ko': '뜻',
        'inclusion_recommendation': 'hide'
      },
      {'term_en': 'd', 'definition_en': 'Not a Korean meaning'},
      {'primary_meaning_ko': '뜻'},
      {'term_en': 'valid', 'primary_meaning_ko': '유효'},
    ]));
    expect(preview.errors, hasLength(5));
    expect(preview.rows.single.card.displayTerm, 'valid');
    expect(
        store
            .previewCsvImportDetailed('${recallV3Columns.join(',')}\na,,뜻')
            .errors
            .single,
        contains('13개 열'));
    expect(store.totalCards, 0);
    store.dispose();
  });

  test('priority filters combine with query, type, subject and bookmark',
      () async {
    final store = await RecallStore.load();
    await store.importCsvDeck(
        csvText: v3Csv([
      {
        'term_en': 'power factor',
        'primary_meaning_ko': '역률',
        'vocabulary_type': 'technical',
        'subject': 'Power Engineering',
        'learning_priority': 'high'
      },
      {
        'term_en': 'power',
        'primary_meaning_ko': '전력',
        'learning_priority': 'low'
      },
      {'term_en': 'maintain', 'primary_meaning_ko': '유지하다'},
    ]));
    final card = store.searchCards('power factor').first.card;
    await store.toggleBookmark(card.id);
    final subject = store.categories.firstWhere((s) => s.name == '전력공학');
    expect(
        store
            .searchCards('PoW',
                categoryId: subject.id,
                vocabularyType: VocabularyType.technical,
                learningPriority: LearningPriority.high,
                bookmarkedOnly: true)
            .single
            .card
            .id,
        card.id);
    expect(
        store
            .searchCards('', learningPriority: LearningPriority.low)
            .single
            .card
            .displayTerm,
        'power');
    expect(
        store
            .searchCards('', learningPriority: LearningPriority.medium)
            .single
            .card
            .displayTerm,
        'maintain');
    store.dispose();
  });

  test('v2 migration preserves the original save and every legacy entry',
      () async {
    final encoded = jsonEncode({
      'schemaVersion': 2,
      'entries': [
        {
          'id': 'a',
          'front': 'maintain',
          'meaning': '유지하다',
          'vocabulary_type': 'general',
          'isBookmarked': true,
          'imageData': 'AQID',
          'lastReviewed': '2025-01-01T00:00:00.000',
          'isExcludedFromReview': true,
          'categoryIds': ['subject'],
          'meanings': [
            {
              'id': 'm',
              'meaning_ko': '유지하다',
              'definition': 'Keep in a state.',
              'explanation': '상태를 유지하다',
              'formula': 'legacy formula',
              'unit': 'legacy unit',
              'application_context': 'legacy detailed context'
            }
          ]
        },
        {
          'id': 'b',
          'front': 'maintain',
          'meaning': '보존하다',
          'vocabulary_type': 'general_technical'
        },
        {
          'id': 'c',
          'front': 'impedance',
          'meaning': '임피던스',
          'vocabulary_type': 'technical'
        },
      ],
      'decks': [
        {
          'id': 'deck',
          'name': 'Old collection',
          'entryIds': ['a', 'b']
        }
      ],
      'categories': [
        {'id': 'subject', 'name': 'Custom'}
      ],
      'recentViews': [
        {'cardId': 'a', 'viewedAt': '2025-01-01T00:00:00.000'}
      ],
      'dailyGoal': 10,
      'tutorialCompleted': true,
    });
    SharedPreferences.setMockInitialValues({'recall.data.v2': encoded});
    final store = await RecallStore.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recall.data.v2'), encoded);
    expect(jsonDecode(prefs.getString('recall.data.v3')!)['schemaVersion'], 3);
    expect(store.totalCards, 3);
    expect(store.decks.single.cards.map((c) => c.id), ['a', 'b']);
    final card = store.cardById('a')!;
    expect(card.vocabularyType, VocabularyType.generalTechnical);
    expect(card.learningPriority, LearningPriority.medium);
    expect(card.definitionEn, 'Keep in a state.');
    expect(card.explanationKo, '상태를 유지하다');
    expect(card.meanings.single.formula, 'legacy formula');
    expect(card.meanings.single.applicationContext, 'legacy detailed context');
    expect(card.isBookmarked, isTrue);
    expect(card.imageData, 'AQID');
    expect(card.lastReviewed, DateTime(2025));
    expect(store.categoryNamesForCard(card), 'Custom');
    expect(store.recentCards.single.card.id, 'a');
    expect(store.dailyGoal, 10);
    expect(store.dueCount, 2);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.cardById('a')!.meanings.single.unit, 'legacy unit');
    expect(prefs.getString('recall.data.v2'), encoded);
    restored.dispose();
  });

  test('reimport updates explicit v3 metadata without resetting learning state',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'current',
        meaning: '전류',
        example: '',
        formula: 'i = dq/dt');
    final id = store.allCards.single.card.id;
    await store.toggleBookmark(id);
    await store.markReviewed(id);
    final csv = v3Csv([
      {
        'term_en': 'current',
        'primary_meaning_ko': '전류',
        'vocabulary_type': 'general_technical',
        'learning_priority': 'high',
        'inclusion_recommendation': 'review',
        'collector': 'Collector',
        'notes': 'memo'
      }
    ]);
    await store.importCsvDeck(csvText: csv);
    final meanings = store.cardById(id)!.meanings.length;
    await store.importCsvDeck(csvText: csv);
    await store.importCsvDeck(csvText: 'word,meaning\ncurrent,電流');
    await store.importCsvDeck(
        csvText: v3Csv([
      {'term_en': 'current', 'primary_meaning_ko': '전류'}
    ]));
    final card = store.cardById(id)!;
    expect(store.totalCards, 1);
    expect(card.vocabularyType, VocabularyType.generalTechnical);
    expect(card.learningPriority, LearningPriority.high);
    expect(card.isBookmarked, isTrue);
    expect(card.lastReviewed, isNotNull);
    expect(card.formula, 'i = dq/dt');
    expect(card.meanings.any((m) => m.formula == 'i = dq/dt'), isTrue);
    expect(card.meanings.length, meanings + 1);
    expect(card.notes, 'memo');
    expect(card.collector, 'Collector');
    expect(store.reviewsToday, 1);
    store.dispose();
  });

  test('corrupt v3 never falls back to old data or overwrites it', () async {
    SharedPreferences.setMockInitialValues(
        {'recall.data.v3': '{broken', 'recall.data.v2': '{old'});
    await expectLater(RecallStore.load(), throwsA(isA<FormatException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recall.data.v3'), '{broken');
    expect(prefs.getString('recall.data.v2'), '{old');
  });

  test(
      'collection deletion cascades shared words but preserves unrelated entries',
      () async {
    final store = await RecallStore.load();
    await store.createDeck('First');
    final first = store.decks.single.id;
    await store.addCard(
        deckId: first, front: 'current', meaning: '전류', example: '');
    final shared = store.allCards.single.card.id;
    await store.toggleBookmark(shared);
    await store.recordCardViewed(shared);
    await store.markReviewed(shared);
    await store.createDeck('Second');
    final second = store.decks.last.id;
    await store.addEntryToDeck(deckId: second, cardId: shared);
    await store.addCard(
        deckId: second, front: 'impedance', meaning: '임피던스', example: '');
    final preserved = store.searchCards('impedance').single.card.id;
    await store.toggleBookmark(preserved);
    await store.recordCardViewed(preserved);
    await store.deleteDeck(first);
    expect(store.deckById(first), isNull);
    expect(store.cardById(shared), isNull);
    expect(store.decks.single.cards.single.id, preserved);
    expect(store.searchCards('current'), isEmpty);
    expect(store.bookmarkedCards.single.card.id, preserved);
    expect(store.recentCards.single.card.id, preserved);
    expect(store.dueCards.single.card.id, preserved);
    expect(store.reviewsToday,
        1); // Aggregate daily activity is not entry history.
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.cardById(shared), isNull);
    expect(restored.decks.single.cards.single.id, preserved);
    expect(restored.totalCards, 1);
    restored.dispose();
  });

  test('bulk deletion is deduplicated and clears every entry reference',
      () async {
    final store = await RecallStore.load();
    await store.importCsvDeck(
        csvText: 'word,meaning\ncurrent,전류\nimpedance,임피던스\nmaintain,유지하다');
    final current = store.searchCards('current').single.card.id;
    final impedance = store.searchCards('impedance').single.card.id;
    await store.createDeck('Shared');
    await store.addEntryToDeck(deckId: store.decks.last.id, cardId: current);
    await store.toggleBookmark(current);
    await store.toggleBookmark(impedance);
    await store.recordCardViewed(current);
    await store.recordCardViewed(impedance);
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.deleteEntries([current, impedance, current, 'missing']);
    expect(notifications, 1);
    expect(store.totalCards, 1);
    expect(store.allCards.single.card.displayTerm, 'maintain');
    expect(store.decks.first.cards.single.displayTerm, 'maintain');
    expect(store.decks.last.cards, isEmpty);
    expect(store.bookmarkedCards, isEmpty);
    expect(store.recentCards, isEmpty);
    await store.deleteEntries([]);
    await store.deleteDeck('missing');
    expect(notifications, 1);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.totalCards, 1);
    expect(restored.decks.last.cards, isEmpty);
    restored.dispose();
  });

  test('deleting an empty collection keeps dictionary-only vocabulary',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '', front: 'current', meaning: '전류', example: '');
    await store.createDeck('Empty');
    await store.deleteDeck(store.decks.single.id);
    expect(store.decks, isEmpty);
    expect(store.totalCards, 1);
    store.dispose();
  });

  test('failed delete writes restore entries, references and preferences cache',
      () async {
    final preferences =
        _FailingPreferences(await SharedPreferences.getInstance());
    final store = await RecallStore.load(storage: preferences);
    await store.importCsvDeck(csvText: 'word,meaning\ncurrent,전류');
    final id = store.allCards.single.card.id;
    final deckId = store.decks.single.id;
    await store.toggleBookmark(id);
    await store.recordCardViewed(id);
    final encoded = preferences.getString('recall.data.v3');
    preferences.failWrites = true;
    await expectLater(store.deleteEntries([id]), throwsStateError);
    expect(store.cardById(id), isNotNull);
    expect(store.searchCards('current'), hasLength(1));
    expect(store.decks.single.cards.single.id, id);
    expect(store.bookmarkedCards.single.card.id, id);
    expect(store.recentCards.single.card.id, id);
    await expectLater(store.deleteDeck(deckId), throwsStateError);
    expect(store.deckById(deckId)!.cards.single.id, id);
    expect(preferences.getString('recall.data.v3'), encoded);
    store.dispose();
    final restored = await RecallStore.load(storage: preferences);
    expect(restored.cardById(id), isNotNull);
    expect(restored.deckById(deckId), isNotNull);
    restored.dispose();
  });
  test(
      'no subjects are seeded and previous default names are ordinary subjects',
      () async {
    final store = await RecallStore.load();
    expect(store.categories, isEmpty);
    final electrical = await store.createCategory('Electrical Engineering');
    final semiconductor = await store.createCategory('반도체공학');
    expect(electrical.name, '전기공학');
    expect(electrical.isPinned, isFalse);
    expect(semiconductor.isPinned, isFalse);
    final ids = store.categories.map((c) => c.id).toList();
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.categories.map((c) => c.id), ids);
    for (final id in ids) {
      expect(restored.isCategoryDeletionProtected(id), isFalse);
      await restored.deleteCategory(id);
    }
    restored.dispose();
    final empty = await RecallStore.load();
    expect(empty.categories, isEmpty);
    empty.dispose();
  });

  test('upgrade retires mandatory roots once, keeping children and vocabulary',
      () async {
    final store = await RecallStore.load();
    await store.importCsvDeck(csvText: 'word,meaning\ncurrent,전류');
    await store.addCard(
        deckId: store.decks.single.id,
        front: 'impedance',
        meaning: '임피던스',
        example: '',
        categoryPaths: [
          'Electrical Engineering / Circuits / AC',
          'Semiconductor Engineering / Devices',
          'Circuit Theory',
        ]);
    final fixed = store.categories.firstWhere((c) => c.name == '전기공학');
    final semiconductor = store.categories.firstWhere((c) => c.name == '반도체공학');
    final child = store.categories.firstWhere((c) => c.name == 'Circuits');
    final grandchild = store.categories.firstWhere((c) => c.name == 'AC');
    final otherChild = store.categories.firstWhere((c) => c.name == 'Devices');
    final id = store.searchCards('impedance').single.card.id;
    await store.setCategoryPinned(child.id, true);
    await store.toggleBookmark(id);
    await store.recordCardViewed(id);
    await store.markReviewed(id);
    final before = Map<String, Object?>.of(store.cardById(id)!.toJson());
    final prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(prefs.getString('recall.data.v3')!) as Map
      ..remove('subjectSettingsVersion');
    final subjects = (json['categories'] as List).cast<Map>();
    subjects.firstWhere((c) => c['id'] == fixed.id)['name'] =
        'Electrical Engineering';
    store.dispose();
    SharedPreferences.setMockInitialValues(
        {'recall.data.v3': jsonEncode(json)});
    final upgraded = await RecallStore.load();
    expect(upgraded.categoryById(fixed.id), isNull);
    expect(upgraded.categoryById(semiconductor.id), isNull);
    expect(upgraded.categoryById(child.id)!.parentId, isNull);
    expect(upgraded.categoryById(otherChild.id)!.parentId, isNull);
    expect(upgraded.categoryById(child.id)!.isPinned, isTrue);
    expect(upgraded.categoryById(grandchild.id)!.parentId, child.id);
    expect(upgraded.categoryPath(grandchild.id), ['Circuits', 'AC']);
    before['categoryIds'] = (before['categoryIds'] as List)
        .where((value) => value != fixed.id && value != semiconductor.id)
        .toList();
    expect(upgraded.cardById(id)!.toJson(), before);
    expect(upgraded.decks.single.cards, hasLength(2));
    expect(upgraded.bookmarkedCards.single.card.id, id);
    expect(upgraded.recentCards.single.card.id, id);
    expect(upgraded.reviewsToday, 1);
    final recreated = await upgraded.createCategory('전기공학');
    upgraded.dispose();
    final restored = await RecallStore.load();
    expect(restored.categoryById(recreated.id), isNotNull);
    expect(restored.cardById(id)!.toJson(), before);
    expect(restored.totalCards, 2);
    restored.dispose();
  });

  test('custom subject creation supports parents and rejects ambiguous names',
      () async {
    final store = await RecallStore.load();
    final root = await store.createCategory('  Materials  ');
    final child = await store.createCategory('Devices', parentId: root.id);
    final other = await store.createCategory('Devices');
    expect(store.categoryPath(child.id), ['Materials', 'Devices']);
    expect(root.isPinned, isFalse);
    expect(
        store.categorySubtree(root.id).map((c) => c.id), [root.id, child.id]);
    for (final invalid in ['', ' / ', 'Materials/Devices', 'materials']) {
      await expectLater(
          store.createCategory(invalid), throwsA(isA<FormatException>()));
    }
    await expectLater(store.createCategory('devices', parentId: root.id),
        throwsA(isA<FormatException>()));
    await expectLater(store.createCategory('Missing', parentId: 'missing'),
        throwsA(isA<FormatException>()));
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.categoryPath(child.id), ['Materials', 'Devices']);
    expect(restored.categoryById(other.id), isNotNull);
    restored.dispose();
  });

  test('deleting a subject tree clears assignments without deleting vocabulary',
      () async {
    final store = await RecallStore.load();
    final root = await store.createCategory('Materials');
    final child = await store.createCategory('Devices', parentId: root.id);
    final grandchild = await store.createCategory('MOSFET', parentId: child.id);
    await store.importCsvDeck(csvText: 'word,meaning\ncurrent,전류');
    final id = store.allCards.single.card.id;
    await store.updateCard(
        deckId: store.decks.single.id,
        cardId: id,
        front: 'current',
        meaning: '전류',
        example: 'Measured current.',
        imageData: 'AQID',
        categoryPaths: [
          'Materials / Devices / MOSFET',
          'Electrical Engineering'
        ]);
    await store.toggleBookmark(id);
    await store.recordCardViewed(id);
    await store.markReviewed(id);
    final before = Map<String, Object?>.of(store.cardById(id)!.toJson());
    final fixedId = store.categories.firstWhere((c) => c.name == '전기공학').id;
    await store.deleteCategory(root.id);
    for (final removedId in [root.id, child.id, grandchild.id]) {
      expect(store.categoryById(removedId), isNull);
    }
    before['categoryIds'] = [fixedId];
    expect(store.cardById(id)!.toJson(), before);
    expect(store.decks.single.cards.single.categoryIds, [fixedId]);
    expect(store.bookmarkedCards.single.card.id, id);
    expect(store.recentCards.single.card.id, id);
    expect(store.reviewsToday, 1);
    expect(store.cardsInCategory(root.id), isEmpty);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.cardById(id)!.toJson(), before);
    expect(restored.categories, hasLength(1));
    restored.dispose();
  });

  test('deleting a child keeps its parent, siblings and unrelated assignments',
      () async {
    final store = await RecallStore.load();
    final root = await store.createCategory('Materials');
    final child = await store.createCategory('Devices', parentId: root.id);
    final sibling = await store.createCategory('Signals', parentId: root.id);
    await store.addCard(
        deckId: '',
        front: 'current',
        meaning: '전류',
        example: '',
        categoryPaths: ['Materials / Devices', 'Materials / Signals']);
    await store.deleteCategory(child.id);
    expect(store.allCards.single.card.categoryIds, [root.id, sibling.id]);
    expect(store.categoryById(root.id), isNotNull);
    expect(store.categoryById(sibling.id), isNotNull);
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.deleteCategory('missing');
    expect(notifications, 0);
    store.dispose();
  });

  test(
      'failed subject creation and deletion restore data and preferences cache',
      () async {
    final preferences =
        _FailingPreferences(await SharedPreferences.getInstance());
    final store = await RecallStore.load(storage: preferences);
    final subject = await store.createCategory('Materials');
    await store.addCard(
        deckId: '',
        front: 'current',
        meaning: '전류',
        example: '',
        categoryNames: ['Materials']);
    final before = preferences.getString('recall.data.v3');
    preferences.failWrites = true;
    await expectLater(store.createCategory('Failed'), throwsStateError);
    expect(store.categories.any((c) => c.name == 'Failed'), isFalse);
    await expectLater(store.deleteCategory(subject.id), throwsStateError);
    expect(store.categoryById(subject.id), isNotNull);
    expect(store.allCards.single.card.categoryIds, [subject.id]);
    expect(preferences.getString('recall.data.v3'), before);
    store.dispose();
    final restored = await RecallStore.load(storage: preferences);
    expect(restored.categoryById(subject.id), isNotNull);
    expect(restored.allCards.single.card.categoryIds, [subject.id]);
    restored.dispose();
  });

  test('pinning persists, protects a subtree, and unpinning enables deletion',
      () async {
    final store = await RecallStore.load();
    final root = await store.createCategory('Materials');
    final child = await store.createCategory('Devices', parentId: root.id);
    await store.setCategoryPinned(child.id, true);
    expect(store.isCategoryDeletionProtected(root.id), isTrue);
    await expectLater(store.deleteCategory(root.id), throwsStateError);
    await expectLater(store.deleteCategory(child.id), throwsStateError);
    store.dispose();
    final restored = await RecallStore.load();
    expect(restored.categoryById(child.id)!.isPinned, isTrue);
    expect(restored.categoryById(child.id)!.parentId, root.id);
    await restored.setCategoryPinned(child.id, false);
    expect(restored.isCategoryDeletionProtected(root.id), isFalse);
    await restored.deleteCategory(root.id);
    expect(restored.categories, isEmpty);
    restored.dispose();
  });

  test(
      'pinning a parent allows removing unpinned children but never the parent',
      () async {
    final store = await RecallStore.load();
    final root = await store.createCategory('Materials');
    final child = await store.createCategory('Devices', parentId: root.id);
    await store.setCategoryPinned(root.id, true);
    await expectLater(store.deleteCategory(root.id), throwsStateError);
    await store.deleteCategory(child.id);
    expect(store.categoryById(root.id)!.isPinned, isTrue);
    store.dispose();
  });

  test('missing and unchanged pin commands cannot create or duplicate subjects',
      () async {
    final store = await RecallStore.load();
    final subject = await store.createCategory('Materials');
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.setCategoryPinned(subject.id, false);
    await expectLater(
        store.setCategoryPinned('missing', true), throwsStateError);
    expect(notifications, 0);
    expect(store.categories.single.id, subject.id);
    store.dispose();
  });

  test(
      'failed pin and unpin restore the saved protection and preferences cache',
      () async {
    final preferences =
        _FailingPreferences(await SharedPreferences.getInstance());
    final store = await RecallStore.load(storage: preferences);
    final subject = await store.createCategory('Materials');
    final beforePin = preferences.getString('recall.data.v3');
    preferences.failWrites = true;
    await expectLater(
        store.setCategoryPinned(subject.id, true), throwsStateError);
    expect(store.categoryById(subject.id)!.isPinned, isFalse);
    expect(preferences.getString('recall.data.v3'), beforePin);
    preferences.failWrites = false;
    await store.setCategoryPinned(subject.id, true);
    final beforeUnpin = preferences.getString('recall.data.v3');
    preferences.failWrites = true;
    await expectLater(
        store.setCategoryPinned(subject.id, false), throwsStateError);
    expect(store.categoryById(subject.id)!.isPinned, isTrue);
    expect(preferences.getString('recall.data.v3'), beforeUnpin);
    await expectLater(store.deleteCategory(subject.id), throwsStateError);
    store.dispose();
    final restored = await RecallStore.load(storage: preferences);
    expect(restored.categoryById(subject.id)!.isPinned, isTrue);
    restored.dispose();
  });

  test('failed subject migration preserves the old save and retries safely',
      () async {
    final json = jsonEncode({
      'schemaVersion': 2,
      'entries': [],
      'decks': [],
      'categories': [
        {'id': 'old-root', 'name': '전기공학'},
        {'id': 'child', 'name': '회로', 'parentId': 'old-root'},
      ],
    });
    SharedPreferences.setMockInitialValues({'recall.data.v2': json});
    final preferences =
        _FailingPreferences(await SharedPreferences.getInstance())
          ..failWrites = true;
    await expectLater(RecallStore.load(storage: preferences), throwsStateError);
    expect(preferences.getString('recall.data.v3'), isNull);
    expect(preferences.getString('recall.data.v2'), json);
    preferences.failWrites = false;
    final upgraded = await RecallStore.load(storage: preferences);
    expect(upgraded.categories.single.id, 'child');
    expect(upgraded.categories.single.parentId, isNull);
    expect(preferences.getString('recall.data.v2'), json);
    upgraded.dispose();
  });
}

class _FailingPreferences extends Fake implements SharedPreferences {
  _FailingPreferences(this.delegate);
  final SharedPreferences delegate;
  bool failWrites = false;
  final Map<String, String> _failedCache = {};
  @override
  String? getString(String key) => _failedCache[key] ?? delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) {
    if (failWrites) {
      _failedCache[key] = value;
      return Future.value(false);
    }
    return delegate.setString(key, value);
  }

  @override
  Future<void> reload() async {
    await delegate.reload();
    _failedCache.clear();
  }
}
