import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/reader_navigation.dart';

void main() {
  testWidgets(
      'page entry rejects invalid pages and returns a valid destination',
      (tester) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<int>(
                      context: context,
                      builder: (_) =>
                          const ReaderPageDialog(page: 23, pageCount: 500));
                },
                child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final value in ['', '0', '501', '-1', '1.5', 'word']) {
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text('이동'));
      await tester.pump();
      expect(find.text('1부터 500 사이의 정수를 입력해 주세요.'), findsOneWidget);
      expect(result, isNull);
    }
    await tester.enterText(find.byType(TextField), '125');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(result, 125);
    expect(find.byType(ReaderPageDialog), findsNothing);
  });

  testWidgets('rail previews during drag and navigates only on release',
      (tester) async {
    final navigated = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 48,
                height: 400,
                child: ReaderPageRail(
                    page: 1, pageCount: 500, onNavigate: navigated.add)))));
    final rect = tester.getRect(find.byType(ReaderPageRail));
    final gesture =
        await tester.startGesture(rect.topCenter + const Offset(0, 24));
    await gesture.moveTo(rect.bottomCenter - const Offset(0, 24));
    await tester.pump();
    expect(navigated, isEmpty);
    expect(find.text('500 / 500'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(navigated, [500]);
    await tester.tapAt(rect.topCenter);
    expect(navigated, [500, 1]);
  });

  testWidgets('cancelled drag does not navigate; single-page PDF needs no rail',
      (tester) async {
    final navigated = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 48,
                height: 400,
                child: ReaderPageRail(
                    page: 2, pageCount: 5, onNavigate: navigated.add)))));
    final rect = tester.getRect(find.byType(ReaderPageRail));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(navigated, isEmpty);
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 48,
            height: 400,
            child: ReaderPageRail(
                page: 1, pageCount: 1, onNavigate: navigated.add))));
    expect(find.byType(GestureDetector), findsNothing);
  });
}
