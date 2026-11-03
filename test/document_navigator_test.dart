import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/document_navigator.dart';
import 'package:recall/reader/page_bookmark.dart';

void main() {
  testWidgets('preview combines lazy thumbnails and bookmark toggles/filter',
      (tester) async {
    var outlineLoads = 0, rendered = 0;
    int? destination;
    var bookmarks = <ReaderPageBookmark>[];
    final date = DateTime(2026);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 640,
                    height: 500,
                    child: ReaderDocumentNavigator(
                      pageCount: 500,
                      currentPage: 250,
                      loadBookmarks: () async => bookmarks,
                      loadOutline: () async {
                        outlineLoads++;
                        return [];
                      },
                      onBookmark: (b) => destination = b.page,
                      toggleBookmark: (page) async {
                        bookmarks = bookmarks.isEmpty
                            ? [
                                ReaderPageBookmark(
                                    page: page,
                                    x: .5,
                                    y: .5,
                                    zoom: 1,
                                    createdAt: date)
                              ]
                            : [];
                      },
                      onPage: (page) => destination = page,
                      thumbnailBuilder: (_, page) {
                        rendered++;
                        return Text('image $page');
                      },
                    ))))));
    await tester.pumpAndSettle();
    expect(outlineLoads, 0);
    expect(rendered, greaterThan(0));
    expect(rendered, lessThan(20));
    await tester.tap(find.byTooltip('250쪽 북마크 추가'));
    await tester.pumpAndSettle();
    expect(destination, isNull); // Toggling a star must not navigate.
    expect(find.byTooltip('250쪽 북마크 해제'), findsOneWidget);
    await tester.tap(find.text('북마크만 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('image 250'), findsOneWidget);
    expect(find.text('image 251'), findsNothing);
    await tester.tap(find.text('250쪽으로 이동'));
    expect(destination, 250);
    await tester.tap(find.byTooltip('250쪽 북마크 해제'));
    await tester.pumpAndSettle();
    expect(find.text('저장한 페이지가 없습니다.'), findsOneWidget);
  });

  testWidgets('outline opens directly without loading thumbnails or bookmarks',
      (tester) async {
    var destination = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReaderDocumentNavigator(
      pageCount: 5,
      currentPage: 1,
      outlineOnly: true,
      loadBookmarks: () async => throw StateError('must not load bookmarks'),
      loadOutline: () async => [
        ReaderOutlineEntry(
            title: 'Chapter',
            depth: 0,
            page: 3,
            onNavigate: () => destination = 3)
      ],
      onBookmark: (_) {},
      toggleBookmark: (_) async {},
      onPage: (_) {},
      thumbnailBuilder: (_, page) => throw StateError('must not render'),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('목차로 이동: Chapter'));
    expect(destination, 3);
    expect(find.text('북마크만 (0)'), findsNothing);
  });
}
