import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/reader/reader_learning.dart';
import 'package:recall/reader/reader_learning_store.dart';
import 'package:recall/reader/reader_learning_view.dart';

void main() {
  testWidgets(
      'saved term source links preserve deleted-document history and filter',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ReaderLearningStore.load();
    final date = DateTime(2026);
    final docA = 'a' * 64, docB = 'b' * 64;
    final term = ReaderSavedTerm(
        cardId: 'term',
        term: 'Power factor',
        meaning: '역률',
        definition: 'definition',
        explanation: '설명',
        createdAt: date);
    ReaderOccurrence source(String doc) => ReaderOccurrence(
        cardId: 'term',
        documentId: doc,
        documentTitle: doc == docA ? 'A' : 'B',
        text: 'Power factor',
        context: 'context',
        page: 1,
        start: 0,
        end: 12,
        rects: [const Rect.fromLTWH(.1, .1, .2, .1)],
        createdAt: date);
    await store.save(term, [source(docA), source(docB)]);
    ReaderOccurrence? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReaderLearningView(
                store: store,
                documentIds: {docA},
                cardById: (_) => null,
                onSource: (s) => selected = s,
                currentDocumentId: docA))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power factor'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(
                find.byKey(ValueKey('reader-source-${source(docB).id}')))
            .onPressed,
        isNull);
    expect(find.textContaining('문서가 삭제되었거나'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('reader-source-${source(docA).id}')));
    expect(selected!.documentId, docA);
    await tester.tap(find.text('이 문서만'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(ValueKey('reader-source-${source(docB).id}')), findsNothing);
    expect(store.occurrencesFor('term'), hasLength(2));
  });
}
