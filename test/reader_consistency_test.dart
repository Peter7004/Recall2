import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/vocabulary.dart';
import 'package:recall/reader/reader_learning.dart';
import 'package:recall/reader/reader_learning_store.dart';
import 'package:recall/reader/reader_learning_guard.dart';
import 'package:recall/reader/reader_learning_view.dart';
import 'package:recall/reader/reader_card_sources_page.dart';
import 'package:recall/reader/library/document_repository.dart';
import 'package:recall/reader/library/document_storage.dart';
import 'package:recall/reader/library/reader_document.dart';

final _date = DateTime(2026);
final _doc = 'a' * 64;
ReaderSavedTerm _term() => ReaderSavedTerm(
    cardId: 'card',
    term: 'Old term',
    meaning: '저장한 뜻',
    definition: 'Saved definition',
    explanation: '저장한 설명',
    createdAt: _date);
ReaderOccurrence _source() => ReaderOccurrence(
    cardId: 'card',
    documentId: _doc,
    documentTitle: 'Textbook',
    text: 'Old term',
    context: 'Original sentence.',
    page: 1,
    start: 0,
    end: 8,
    rects: [const Rect.fromLTWH(.1, .1, .2, .1)],
    createdAt: _date);
RecallCard _card(
        {String definition = 'Current definition',
        String explanation = '현재 설명'}) =>
    RecallCard(
        id: 'card',
        front: 'Current term',
        meaning: 'Legacy field must not be shown',
        example: '',
        dueAt: _date,
        intervalMinutes: 0,
        stabilityDays: 2,
        ease: 2,
        lastReviewed: null,
        meanings: [
          VocabularyMeaning(
              id: 'meaning',
              meaningKo: '현재 뜻',
              type: MeaningType.technical,
              definitionEn: definition,
              explanationKo: explanation)
        ]);

class _Storage extends MemoryDocumentStorage
    implements DocumentStorageDiagnostics {
  final damaged = <DamagedDocumentEntry>[];
  final failing = <String>{};
  final checks = <String>[];
  @override
  List<DamagedDocumentEntry> get damagedEntries => damaged;
  @override
  Future<bool> available(String id) async {
    checks.add(id);
    if (failing.contains(id)) throw StateError('File access denied');
    return super.available(id);
  }

  @override
  Future<Uint8List> read(String id) =>
      throw StateError('Do not load full PDFs for availability');
  void add(String id) {
    documents[id] = ReaderDocument(
        id: id,
        title: 'Textbook',
        byteSize: 20,
        importedAt: _date,
        lastOpenedAt: _date);
    payloads[id] = Uint8List.fromList([1, 2, 3]);
  }
}

// Isolate setup writes from cross-test fake-clock notifications; concurrency
// itself is exercised by reader_learning_test and the real two-tab smoke.
class _DisplayGuard implements LearningWriteGuard {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  void didChange() {}
  @override
  Future<T> read<T>(Future<T> Function() action) => action();
  @override
  Future<T> exclusive<T>(Future<T> Function() action) => action();
}

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'recall.data.v3': 'untouched'}));
  Future<ReaderLearningStore> learning() async {
    final store = await ReaderLearningStore.load(guard: _DisplayGuard());
    addTearDown(store.dispose);
    await store.save(_term(), [_source()]);
    return store;
  }

  testWidgets(
      'current fields stay coherent, empty edits do not revive snapshot, deletion falls back without writes',
      (tester) async {
    final store = (await tester.runAsync(learning))!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ReaderLearningStore.storageKey);
    RecallCard? card = _card();
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReaderLearningView(
                store: store,
                availableDocumentIds: {_doc},
                dictionaryChanges: changes,
                cardById: (_) => card,
                onSource: (_) {}))));
    await tester.tap(find.text('Current term'));
    await tester.pumpAndSettle();
    expect(find.text('현재 뜻'), findsOneWidget);
    expect(find.text('Current definition'), findsOneWidget);
    expect(find.text('현재 설명'), findsOneWidget);
    expect(find.text('Saved definition'), findsNothing);
    expect(find.text('현재 사전 정보'), findsOneWidget);
    card = _card(definition: '', explanation: '');
    changes.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Current definition'), findsNothing);
    expect(find.text('Saved definition'), findsNothing);
    expect(find.text('저장한 설명'), findsNothing);
    card = null;
    changes.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Old term'), findsOneWidget);
    expect(find.text('저장한 뜻'), findsOneWidget);
    expect(find.text('Saved definition'), findsOneWidget);
    expect(find.text('저장한 설명'), findsOneWidget);
    expect(find.textContaining('저장 당시 정보를 표시합니다'), findsOneWidget);
    expect(prefs.getString(ReaderLearningStore.storageKey), saved);
    expect(prefs.getString('recall.data.v3'), 'untouched');
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'shared availability excludes missing bytes, damaged metadata and access failures without reading PDF',
      () async {
    final storage = _Storage();
    final ids = ['a', 'b', 'c', 'd', 'e'].map((s) => s * 64).toList();
    for (final id in ids) {
      storage.add(id);
    }
    storage.payloads.remove(ids[1]);
    storage.damaged.add(DamagedDocumentEntry(ids[2]));
    storage.failing.add(ids[3]);
    final repo = DocumentRepository(storage);
    expect(await repo.availableDocumentIds([...ids, ids[0], 'f' * 64]),
        {ids[0], ids[4]});
    expect(storage.checks.where((id) => id == ids[0]), hasLength(1));
    expect(storage.checks, isNot(contains(ids[2])));
    expect(storage.documents, hasLength(5));
    expect(storage.payloads, hasLength(4));
  });

  testWidgets(
      'source screens agree and recheck missing files and navigation errors',
      (tester) async {
    {
      final store = (await tester.runAsync(learning))!;
      final storage = _Storage()..add(_doc);
      storage.payloads.remove(_doc);
      final repo = DocumentRepository(storage);
      final available = await repo.availableDocumentIds([_doc]);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReaderLearningView(
                  store: store,
                  availableDocumentIds: available,
                  cardById: (_) => null,
                  onSource: (_) => opened = true))));
      await tester.tap(find.text('Old term'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(ValueKey('reader-source-${_source().id}')))
              .onPressed,
          isNull);
      await tester.pumpWidget(MaterialApp(
          home: ReaderCardSourcesPage(
              cardId: 'card',
              repository: repo,
              onOpen: (_) async {
                opened = true;
              })));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<IconButton>(find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'PDF 원문 열기: 위치 1'))
              .onPressed,
          isNull);
      expect(find.textContaining('문서가 삭제되었거나'), findsOneWidget);
      expect(opened, isFalse);
      expect(store.occurrencesFor('card'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    }
    {
      final store = (await tester.runAsync(learning))!;
      final storage = _Storage()..add(_doc);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
          home: ReaderCardSourcesPage(
              cardId: 'card',
              repository: DocumentRepository(storage),
              onOpen: (_) async {
                opened = true;
              })));
      await tester.pumpAndSettle();
      final button = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'PDF 원문 열기: 위치 1');
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      storage.payloads.remove(_doc);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      expect(find.textContaining('원본 PDF를 다시 가져와'), findsOneWidget);
      expect(store.terms, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    }
    {
      final store = (await tester.runAsync(learning))!;
      final storage = _Storage()..add(_doc);
      await tester.pumpWidget(MaterialApp(
          home: ReaderCardSourcesPage(
              cardId: 'card',
              repository: DocumentRepository(storage),
              onOpen: (_) async {
                throw StateError('Viewer failed');
              })));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'PDF 원문 열기: 위치 1'));
      await tester.pumpAndSettle();
      expect(find.text('원문을 열지 못했습니다. 기존 학습 기록은 유지했습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(store.occurrencesFor('card'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
