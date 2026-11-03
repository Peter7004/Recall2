import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/document_navigator.dart';

void main() {
  testWidgets(
      'outline and thumbnails load only on their tab; 500 pages are virtualized',
      (tester) async {
    var outlineLoads = 0;
    var rendered = 0;
    int? destination;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
      width: 640,
      height: 500,
      child: ReaderDocumentNavigator(
          pageCount: 500,
          currentPage: 250,
          loadBookmarks: () async => [],
          loadOutline: () async {
            outlineLoads++;
            return [
              ReaderOutlineEntry(
                  title: 'Chapter',
                  depth: 0,
                  page: 3,
                  onNavigate: () => destination = 3)
            ];
          },
          onBookmark: (_) {},
          removeBookmark: (_) async {},
          onPage: (page) => destination = page,
          thumbnailBuilder: (_, page) {
            rendered++;
            return ColoredBox(color: Colors.white, child: Text('image $page'));
          }),
    )))));
    await tester.pumpAndSettle();
    expect(outlineLoads, 0);
    expect(rendered, 0);
    await tester.tap(find.text('문서 목차'));
    await tester.pumpAndSettle();
    expect(outlineLoads, 1);
    await tester.tap(find.byTooltip('목차로 이동: Chapter'));
    expect(destination, 3);
    await tester.tap(find.text('미리보기'));
    await tester.pumpAndSettle();
    expect(rendered, greaterThan(0));
    expect(rendered, lessThan(20));
    await tester.tap(find.text('250쪽으로 이동'));
    expect(destination, 250);
    await tester.tap(find.text('내 북마크'));
    await tester.pumpAndSettle();
    expect(find.text('image 250'), findsNothing);
  });
}
