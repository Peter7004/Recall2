import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/corpus/corpus_stats.dart';
import 'package:recall/corpus/corpus_loader.dart';
import 'package:recall/corpus/corpus_widgets.dart';
import 'package:recall/recall_store.dart';
import 'package:recall/reader/terminology_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final header = corpusColumns.join(',');
  String metadataFor(String csv, {Map<String, Object> pending = const {}}) =>
      jsonEncode({
        'schema_version': 1,
        'basis': 'provisional_accepted',
        'date': '2026-11-11',
        'textbook_documents': 22,
        'abstract_documents': 639,
        'csv_sha256': sha256.convert(utf8.encode(csv)).toString(),
        'pending': pending,
      });
  late CorpusCatalog catalog;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    catalog = CorpusCatalog.parse(
        File('test/fixtures/corpus_small.csv').readAsStringSync());
  });
  test(
      'fixture parses UTF8/BOM and CRLF; normalization is deliberately limited',
      () {
    final unicode =
        CorpusCatalog.parse('\uFEFF$header\r\n"  Flux   한글  ",2,1,0,0\r\n');
    expect(unicode.available, isTrue);
    expect(unicode.forTerm('FLUX 한글')?.textbookTf, 2);
    expect(catalog.forTerm('  SKIN  effect ')?.abstractDf, 3);
    expect(catalog.forTerm('skin-effect'), isNull);
    expect(catalog.forTerm('skin effects'), isNull);
    expect(catalog.forTerm('SE'), isNull);
  });
  for (final invalid in [
    'Power,,0,0,0',
    'Power,-1,0,0,0',
    'Power,1.2,1,0,0',
    'Power,no,1,0,0',
    'Power,1e3,1,0,0',
    'Power,1,2,0,0',
    'Power,0,0,1,2',
    'Power,1,0,0,0',
    'Power,0,0,1,0',
    'Power,9007199254740992,1,0,0',
    ',0,0,0,0',
    'Power,0,0,0',
    '"Power,0,0,0,0',
  ]) {
    test('invalid row is diagnosed and entire dataset disabled: $invalid', () {
      final result = CorpusCatalog.parse('$header\nValid,1,1,0,0\n$invalid');
      expect(result.errors, isNotEmpty);
      expect(result.available, isFalse);
      expect(result.forTerm('Valid'), isNull);
    });
  }
  test('duplicates are rejected after only case and whitespace normalization',
      () {
    final duplicate = CorpusCatalog.parse(
        '$header\nPower factor,1,1,0,0\n POWER   FACTOR ,1,1,0,0');
    expect(duplicate.errors.single, contains('중복'));
    expect(duplicate.available, isFalse);
    expect(
        CorpusCatalog.parse(
                '$header\nPower factor,1,1,0,0\nPower-factor,1,1,0,0')
            .records
            .length,
        2);
    expect(CorpusCatalog.parse('wrong,header').errors, isNotEmpty);
  });
  test(
      'classification separates unobserved from missing and inclusive filters overlap',
      () {
    final terms = [
      'Skin effect',
      'Absorption',
      'Voltage',
      'Power',
      'Power factor',
      'Missing'
    ];
    expect(catalog.select(terms, (s) => s, scope: CorpusScope.both),
        ['Skin effect']);
    expect(catalog.select(terms, (s) => s, scope: CorpusScope.textbook),
        ['Skin effect', 'Absorption', 'Power factor']);
    expect(catalog.select(terms, (s) => s, scope: CorpusScope.abstracts),
        ['Skin effect', 'Voltage']);
    expect(catalog.select(terms, (s) => s, scope: CorpusScope.unobserved),
        ['Power']);
    expect(catalog.select(terms, (s) => s, scope: CorpusScope.textbookOnly),
        ['Absorption', 'Power factor']);
    expect(catalog.select(terms, (s) => s, scope: CorpusScope.abstractOnly),
        ['Voltage']);
    expect(catalog.select(terms, (s) => s), terms);
  });
  test('DF first, TF tie-breaker within one chosen corpus; missing last', () {
    final terms = [
      'Skin effect',
      'Absorption',
      'Voltage',
      'Power',
      'Power factor',
      'Missing'
    ];
    expect(catalog.select(terms, (s) => s, source: CorpusSource.textbook), [
      'Absorption',
      'Skin effect',
      'Power factor',
      'Power',
      'Voltage',
      'Missing'
    ]);
    expect(
        catalog.select(terms, (s) => s, source: CorpusSource.abstracts).take(2),
        ['Skin effect', 'Voltage']);
    expect(terms.first, 'Skin effect'); // Never mutate cached search results.
  });
  test('matching diagnostics and research completeness do not manufacture rows',
      () {
    final report =
        catalog.diagnose(['Skin effect', ' SKIN  EFFECT ', 'Absent']);
    expect(report['matched'], 1);
    expect(report['duplicateDictionaryTerms'], ['skin effect']);
    expect(report['missingStatistics'], ['absent']);
    expect((report['unmatchedStatistics'] as List).length, 4);
    expect(catalog.verifyResearch(['Skin effect']), isNotEmpty);
    expect((report['categories'] as Map)['unobserved'], 1);
  });
  test('missing, invalid and header-only assets do not prevent startup',
      () async {
    expect((await loadCorpusStats(bundle: _Bundle(null))).available, isFalse);
    expect((await loadCorpusStats(bundle: _Bundle('bad'))).errors, isNotEmpty);
    expect((await loadCorpusStats(bundle: _Bundle('$header\n'))).available,
        isFalse);
    expect(
        (await loadCorpusStats(
                bundle: _Bundle('$header\nPower,0,0,0,0',
                    metadata: metadataFor('$header\nPower,0,0,0,0'))))
            .forTerm('Power')
            ?.textbookTf,
        0);
  });
  test('real recount matches all 834 terms, sizes, counts and pending ledger',
      () async {
    final actual = await loadCorpusStats();
    final rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
        .convert(File('assets/vocabulary/recall_core_v1.csv')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final i = rows.first.indexOf('term_en');
    final terms =
        rows.skip(1).where((r) => r.length == 13).map((r) => r[i].toString());
    expect(actual.available, isTrue);
    expect(actual.verifyResearch(terms, recount: true), isEmpty);
    expect(actual.metadata!.textbookDocuments, 22);
    expect(actual.metadata!.abstractDocuments, 639);
    expect(actual.forTerm('Voltage')!.textbookTf, 7294);
    expect(actual.forTerm('Voltage')!.abstractDf, 107);
    expect(actual.forTerm('Frequency')!.abstractTf, 180);
    expect(actual.metadata!.pending['frequency']!.abstractTf, 106);
    expect(actual.metadata!.pending.values.fold(0, (n, r) => n + r.textbookTf),
        14733);
    expect(actual.metadata!.pending.values.fold(0, (n, r) => n + r.abstractTf),
        2130);
  });
  test(
      'metadata mismatch, missing metadata and impossible pending DF disable statistics',
      () async {
    final csv = '$header\nPower,0,0,0,0';
    final base = CorpusCatalog.parse(csv);
    expect(base.withMetadata(metadataFor('$csv\n'), csv).available, isFalse);
    expect(
        base
            .withMetadata(
                metadataFor(csv, pending: {
                  'power': [4, 5, 0, 0]
                }),
                csv)
            .available,
        isFalse);
    expect(
        base
            .withMetadata(
                metadataFor(csv, pending: {
                  'missing': [1, 1, 0, 0]
                }),
                csv)
            .available,
        isFalse);
    expect((await loadCorpusStats(bundle: _Bundle(csv))).available, isFalse);
  });
  testWidgets('provisional zero and pending evidence are distinguished',
      (tester) async {
    final csv = '$header\nPower,0,0,0,0';
    final data = CorpusCatalog.parse(csv).withMetadata(
        metadataFor(csv, pending: {
          'power': [2, 1, 0, 0]
        }),
        csv);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CorpusInfo(catalog: data, term: 'Power')))));
    expect(find.text('채택 용례 미관측'), findsOneWidget);
    expect(find.textContaining('의미 보류 — PDF: 2회'), findsOneWidget);
    expect(data.forTerm('Power')!.textbookTf, 0);
    expect(
        data.select(['Power'], (s) => s, scope: CorpusScope.textbook), isEmpty);
    await tester.tap(find.text('집계 기준'));
    await tester.pumpAndSettle();
    expect(find.textContaining('논문 전체 본문 빈도가 아닙니다.'), findsOneWidget);
  });
  test(
      'read-only integration preserves serialized user data and priority/search/PDF lookup',
      () async {
    final initial = await RecallStore.load();
    await initial.addCard(
        deckId: '',
        front: 'Skin effect',
        meaning: '표피 효과',
        example: '',
        learningPriority: LearningPriority.high);
    await initial.addCard(
        deckId: '',
        front: 'Absorption',
        meaning: '흡수',
        example: '',
        learningPriority: LearningPriority.low);
    final id = initial.searchCards('Skin effect').single.card.id;
    await initial.toggleBookmark(id);
    await initial.markReviewed(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'recall.reader.learning.v1', '{"terms":[],"occurrences":[]}');
    final before = prefs.getString('recall.data.v3');
    final readerBefore = prefs.getString('recall.reader.learning.v1');
    final store = await RecallStore.load(corpus: catalog);
    final found = store.searchCards('표피',
        learningPriority: LearningPriority.high, bookmarkedOnly: true);
    expect(found.single.card.id, id);
    expect(store.searchCards('표피', learningPriority: LearningPriority.low),
        isEmpty);
    final recommended = store.corpus.select(found, (e) => e.card.displayTerm,
        scope: CorpusScope.both, source: CorpusSource.textbook);
    expect(recommended.single.card.id, id);
    final lookup =
        DictionaryTerminologyLookup([ReaderConcept(found.single.card)]);
    expect(lookup.lookup('Skin effect').single.concept.card.id, id);
    expect(prefs.getString('recall.data.v3'), before);
    expect(prefs.getString('recall.reader.learning.v1'), readerBefore);
    final without = await RecallStore.load();
    expect(without.corpus.available, isFalse);
    expect(without.cardById(id)!.toJson(), store.cardById(id)!.toJson());
  });
  testWidgets('zero, missing and disabled displays remain distinct',
      (tester) async {
    Future<void> show(CorpusCatalog data, String term) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CorpusInfo(catalog: data, term: term))));
    }

    await show(catalog, 'Power');
    expect(find.text('미관측'), findsOneWidget);
    expect(find.text('교재·강의자료: TF 0 · DF 0'), findsOneWidget);
    await show(catalog, 'Missing');
    expect(find.textContaining('제공되지'), findsOneWidget);
    expect(find.textContaining('TF 0'), findsNothing);
    await show(const CorpusCatalog.empty(), 'Power');
    expect(find.text('코퍼스 관측 정보'), findsNothing);
  });
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.value, {this.metadata});
  final String? value;
  final String? metadata;
  @override
  Future<ByteData> load(String key) async {
    final content = key.endsWith('corpus_metadata.json') ? metadata : value;
    if (content == null) throw FlutterError('Missing fixture');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}
