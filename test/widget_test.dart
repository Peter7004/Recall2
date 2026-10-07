import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recall/main.dart';
import 'package:recall/recall_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home starts without sample decks', (WidgetTester tester) async {
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();

    expect(find.text('덱부터 시작해요'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 학습'), findsOneWidget);
    expect(find.text('현재 덱이 없습니다'), findsOneWidget);
    expect(find.text('파일 가져오기'), findsOneWidget);
    expect(find.text('새 덱 만들기'), findsOneWidget);

    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('저장한 카드가 없습니다'), findsOneWidget);
  });

  testWidgets('review screen can flip front and back sides', (tester) async {
    final store = await RecallStore.load();
    await store.createDeck('Food');
    await store.addCard(
      deckId: store.decks.single.id,
      front: 'apple',
      meaning: '사과',
      example: 'I eat an apple.',
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
}
