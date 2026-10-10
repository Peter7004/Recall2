import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recall/main.dart';
import 'package:recall/recall_store.dart';
import 'v3_fixtures.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('dictionary is the first page and has five destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();

    expect(find.text('등록된 용어가 없습니다.'), findsOneWidget);
    expect(find.text('과목'), findsWidgets);
    expect(find.text('모음'), findsOneWidget);
    expect(find.text('플래시카드'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(find.text('북마크한 용어가 없습니다.'), findsOneWidget);
  });

  testWidgets('dictionary searches English and opens a bookmarkable term',
      (WidgetTester tester) async {
    final store = await RecallStore.load();
    await store.createDeck('전력공학');
    final deckId = store.decks.single.id;
    await store.addCard(
      deckId: deckId,
      front: '전압',
      meaning: '두 점 사이의 전위차',
      example: '',
      termEnglish: 'electric potential',
      abbreviation: 'V',
      formula: 'V = W/Q',
      vocabularyType: VocabularyType.technical,
      categoryPaths: ['전력공학 / 전력계통'],
    );
    await store.completeTutorial();
    store.dispose();

    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'electric potential');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'electric potential'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'electric potential'));
    await tester.pumpAndSettle();
    expect(find.text('두 점 사이의 전위차'), findsOneWidget);
    expect(find.text('V = W/Q'), findsNothing);
    expect(find.text('검토 필요'), findsNothing);
    expect(find.text('우선순위 보통'), findsOneWidget);

    await tester.tap(find.byTooltip('북마크 추가'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(find.text('전압'), findsOneWidget);
  });

  testWidgets('review screen can flip front and back sides', (tester) async {
    final store = await RecallStore.load();
    await store.createDeck('Food');
    await store.addCard(
      deckId: store.decks.single.id,
      front: 'apple',
      meaning: '사과',
      example: 'I eat an apple.',
      termEnglish: 'apple',
    );

    await tester.pumpWidget(MaterialApp(home: ReviewPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('사과'), findsNothing);
    expect(find.text('I eat an apple.'), findsNothing);

    await tester.tap(find.text('답 보기'));
    await tester.pump();
    expect(find.text('사과'), findsOneWidget);
    expect(find.text('I eat an apple.'), findsOneWidget);

    await tester.tap(find.text('기본 학습'));
    await tester.pump();
    expect(find.text('사과'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('I eat an apple.'), findsOneWidget);

    store.dispose();
  });

  testWidgets('mixed meanings and missing optional fields render clearly',
      (tester) async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'current',
        termEnglish: 'current',
        meaning: '현재의',
        example: '',
        vocabularyType: VocabularyType.generalTechnical,
        meanings: const [
          VocabularyMeaning(
              id: 'general',
              meaningKo: '현재의',
              definition: 'At the present time.'),
          VocabularyMeaning(
              id: 'technical',
              meaningKo: '전류',
              type: MeaningType.technical,
              explanation: '시간당 이동하는 전하량',
              formula: 'i = dq/dt',
              unit: 'A'),
        ]);
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('current'));
    await tester.pumpAndSettle();
    expect(find.text('뜻'), findsOneWidget);
    expect(find.text('영어 정의'), findsOneWidget);
    expect(find.text('한국어 설명'), findsOneWidget);
    expect(find.text('현재의'), findsOneWidget);
    expect(find.text('전류'), findsOneWidget);
    expect(find.text('출처'), findsNothing);
    expect(find.text('관련 용어'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmarks support query and vocabulary type filters',
      (tester) async {
    final store = await RecallStore.load();
    await store.importCsvDeck(
        csvText: 'term_en,vocabulary_type,primary_meaning_ko\n'
            'maintain,general,유지하다\nimpedance,technical,임피던스');
    for (final entry in store.allCards) {
      await store.toggleBookmark(entry.card.id);
    }
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('북마크').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '전공 용어'));
    await tester.pumpAndSettle();
    expect(find.text('impedance'), findsOneWidget);
    expect(find.text('maintain'), findsNothing);
    await tester.enterText(find.byType(TextField), '없는단어');
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
  });

  testWidgets(
      'subject navigation filters the dictionary without duplicating terms',
      (tester) async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'impedance',
        meaning: '임피던스',
        example: '',
        vocabularyType: VocabularyType.technical,
        categoryNames: const ['Circuit Theory', 'Electronics']);
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('과목').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('회로이론'));
    await tester.pumpAndSettle();
    expect(find.text('impedance'), findsOneWidget);
    expect(find.text('1개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dictionary and detail fit a small mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'electromagnetic induction',
        meaning: '전자기 유도',
        example: '',
        vocabularyType: VocabularyType.technical,
        categoryNames: const ['Electromagnetics']);
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('electromagnetic induction'));
    await tester.pumpAndSettle();
    expect(find.text('전자기 유도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a term can be created without a collection', (tester) async {
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('용어·모음 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 용어'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '영어 용어'), 'maintain');
    await tester.enterText(find.widgetWithText(TextField, '한국어 뜻'), '유지하다');
    await tester.tap(find.byTooltip('저장'));
    await tester.pumpAndSettle();
    expect(find.text('maintain'), findsOneWidget);
    expect(find.text('유지하다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a shared term can be searched in its second collection and survives deletion',
      (tester) async {
    final store = await RecallStore.load();
    await store.createDeck('First');
    await store.addCard(
        deckId: store.decks.single.id,
        front: 'apple',
        meaning: '사과',
        example: '');
    final id = store.allCards.single.card.id;
    await store.createDeck('Second');
    await store.addEntryToDeck(deckId: store.decks.last.id, cardId: id);
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('모음').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이 모음에서 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'apple'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('용어 모음 삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('사전에 유지됩니다.'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사전').last);
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a corrupt legacy photo does not break collection browsing',
      (tester) async {
    final store = await RecallStore.load();
    await store.createDeck('Photos');
    await store.addCard(
        deckId: store.decks.single.id,
        front: 'apple',
        meaning: '사과',
        example: '',
        imageData: '%%%not-base64');
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('모음').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority display and filters work in dictionary and bookmarks',
      (tester) async {
    final store = await RecallStore.load();
    await store.importCsvDeck(
        csvText: v3Csv([
      {
        'term_en': 'impedance',
        'primary_meaning_ko': '임피던스',
        'vocabulary_type': 'technical',
        'learning_priority': 'high'
      },
      {
        'term_en': 'current',
        'primary_meaning_ko': '전류',
        'learning_priority': 'medium'
      },
      {
        'term_en': 'maintain',
        'primary_meaning_ko': '유지하다',
        'learning_priority': 'low'
      },
    ]));
    for (final entry in store.allCards) {
      await store.toggleBookmark(entry.card.id);
    }
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    expect(find.text('일반 영어'), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text('우선순위 높음'), findsOneWidget);
    expect(find.text('우선순위 보통'), findsOneWidget);
    expect(find.text('우선순위 낮음'), findsOneWidget);
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, '학습 우선순위'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('높음').last);
    await tester.pumpAndSettle();
    expect(find.text('impedance'), findsOneWidget);
    expect(find.text('current'), findsNothing);
    expect(find.text('maintain'), findsNothing);
    await tester.tap(find.text('북마크').last);
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, '학습 우선순위'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('낮음').last);
    await tester.pumpAndSettle();
    expect(find.text('maintain'), findsOneWidget);
    expect(find.text('impedance'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'v3 detail and editor hide management fields and preserve old formulas',
      (tester) async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'impedance',
        meaning: '임피던스',
        example: '',
        vocabularyType: VocabularyType.technical,
        learningPriority: LearningPriority.high,
        inclusionRecommendation: InclusionRecommendation.exclude,
        priorityReason: 'PRIVATE_REASON',
        collector: 'PRIVATE_COLLECTOR',
        notes: 'PRIVATE_NOTES',
        formula: 'PRIVATE_FORMULA',
        symbol: 'PRIVATE_SYMBOL',
        unit: 'PRIVATE_UNIT',
        meanings: const [
          VocabularyMeaning(
              id: 'm',
              meaningKo: '임피던스',
              type: MeaningType.technical,
              definitionEn: 'Opposition to AC flow.',
              explanationKo: '교류의 흐름을 방해하는 정도',
              formula: 'PRIVATE_FORMULA',
              applicationContext: 'PRIVATE_CONTEXT')
        ]);
    final id = store.allCards.single.card.id;
    store.dispose();
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    expect(find.text('impedance'),
        findsOneWidget); // exclude does not hide the term.
    await tester.tap(find.text('impedance'));
    await tester.pumpAndSettle();
    expect(find.text('Opposition to AC flow.'), findsOneWidget);
    expect(find.text('교류의 흐름을 방해하는 정도'), findsOneWidget);
    expect(find.text('우선순위 높음'), findsOneWidget);
    for (final value in [
      'exclude',
      'review',
      'include',
      'PRIVATE_REASON',
      'PRIVATE_COLLECTOR',
      'PRIVATE_NOTES',
      'PRIVATE_FORMULA',
      'PRIVATE_CONTEXT'
    ]) {
      expect(find.textContaining(value), findsNothing);
    }
    await tester.tap(find.byTooltip('용어 편집'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.widgetWithText(TextField, '영어 정의'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.widgetWithText(TextField, '영어 정의'), findsOneWidget);
    expect(find.widgetWithText(TextField, '간단한 한국어 설명'), findsOneWidget);
    expect(find.widgetWithText(TextField, '수식'), findsNothing);
    expect(find.text('검증 상태'), findsNothing);
    expect(find.textContaining('inclusion_recommendation'), findsNothing);
    await tester.scrollUntilVisible(
        find.widgetWithText(
            DropdownButtonFormField<LearningPriority>, '학습 우선순위'),
        -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(
        DropdownButtonFormField<LearningPriority>, '학습 우선순위'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('낮음').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('저장'));
    await tester.pumpAndSettle();
    expect(find.text('우선순위 낮음'), findsOneWidget);
    final restored = await RecallStore.load();
    final card = restored.cardById(id)!;
    expect(card.learningPriority, LearningPriority.low);
    expect(card.inclusionRecommendation, InclusionRecommendation.exclude);
    expect(card.notes, 'PRIVATE_NOTES');
    expect(card.formula, 'PRIVATE_FORMULA');
    expect(card.symbol, 'PRIVATE_SYMBOL');
    expect(card.unit, 'PRIVATE_UNIT');
    expect(card.meanings.single.formula, 'PRIVATE_FORMULA');
    expect(card.meanings.single.applicationContext, 'PRIVATE_CONTEXT');
    expect(tester.takeException(), isNull);
    restored.dispose();
  });

  testWidgets(
      'simple flashcards show both languages without management data or formulas',
      (tester) async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '',
        front: 'current',
        meaning: '전류',
        example: '',
        inclusionRecommendation: InclusionRecommendation.exclude,
        notes: 'PRIVATE_NOTES',
        priorityReason: 'PRIVATE_REASON',
        meanings: const [
          VocabularyMeaning(
              id: 'm',
              meaningKo: '전류',
              definitionEn: 'A flow of electric charge.',
              explanationKo: '전하의 흐름',
              type: MeaningType.technical,
              formula: 'PRIVATE_FORMULA')
        ]);
    await tester.pumpWidget(MaterialApp(home: ReviewPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('current'), findsOneWidget);
    await tester.tap(find.text('답 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A flow of electric charge.'), findsOneWidget);
    expect(find.textContaining('전하의 흐름'), findsOneWidget);
    expect(find.textContaining('PRIVATE_'), findsNothing);
    expect(find.text('exclude'), findsNothing);
    expect(tester.takeException(), isNull);
    store.dispose();
  });
}
