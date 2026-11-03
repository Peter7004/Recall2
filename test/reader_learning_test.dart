import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Transitive plugin interface is used only to exercise the real method channel.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:recall/reader/reader_learning.dart';
import 'package:recall/reader/reader_learning_store.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  final time = DateTime.utc(2026, 11, 3);
  final docA = List.filled(64, 'a').join();
  final docB = List.filled(64, 'b').join();
  late Map<String, Object> disk;
  var failWrite = false;
  Completer<void>? gate;
  var writes = 0;

  ReaderSavedTerm term({String card = 'card', DateTime? at}) => ReaderSavedTerm(
        cardId: card,
        term: 'power factor',
        meaning: '역률',
        definition: 'Ratio of real to apparent power.',
        explanation: '전력의 비율',
        createdAt: at ?? time,
      );
  ReaderOccurrence source(
          {String? doc, int start = 10, DateTime? at, String card = 'card'}) =>
      ReaderOccurrence(
        cardId: card,
        documentId: doc ?? docA,
        documentTitle: 'Electrical engineering.pdf',
        text: 'power factor',
        context: 'The power factor is important.',
        page: 2,
        start: start,
        end: start + 12,
        rects: const [Rect.fromLTRB(.1, .2, .4, .3)],
        createdAt: at ?? time,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    disk = {
      'flutter.recall.data.v3': 'original dictionary and bookmarks',
      'flutter.recall.reader.progress.v1.$docA': 'unchanged'
    };
    failWrite = false;
    gate = null;
    writes = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method.startsWith('getAll')) return Map<String, Object>.of(disk);
      if (call.method == 'setString') {
        writes++;
        if (gate != null) await gate!.future;
        if (failWrite) return false;
        final args = call.arguments as Map;
        disk[args['key'] as String] = args['value'] as String;
        return true;
      }
      throw StateError('Unexpected preference mutation: ${call.method}');
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'snapshot persists, deduplicates exact range, preserves dates and meaning',
      () async {
    final store = await ReaderLearningStore.load();
    final original = Map.of(disk);
    await store.save(term(), [source(), source(start: 50), source(doc: docB)]);
    final later = time.add(const Duration(days: 1));
    await store.save(term(at: later), [source(at: later)]);
    final loaded = await ReaderLearningStore.load();
    expect(loaded.terms.single.createdAt, time);
    expect(loaded.terms.single.meaning, '역률');
    expect(loaded.occurrencesFor('card'), hasLength(3));
    expect(loaded.occurrencesFor('card', documentId: docA), hasLength(2));
    expect(loaded.occurrencesForDocument(docB).single.createdAt, time);
    expect(loaded.occurrencesFor('card').first.createdAt, time);
    expect(loaded.occurrencesFor('card')[0].id,
        isNot(loaded.occurrencesFor('card')[1].id));
    expect(() => loaded.terms.clear(), throwsUnsupportedError);
    expect(() => loaded.occurrencesFor('card').first.rects.clear(),
        throwsUnsupportedError);
    for (final entry in original.entries) {
      expect(disk[entry.key], entry.value);
    }
    expect(disk.keys.toSet().difference(original.keys.toSet()),
        {'flutter.${ReaderLearningStore.storageKey}'});
  });

  test('writes serialize and publish only after successful persistence',
      () async {
    final store = await ReaderLearningStore.load();
    var notifications = 0;
    store.addListener(() => notifications++);
    gate = Completer<void>();
    final first = store.save(term(), [source()]);
    final second = store.save(term(card: 'second'), [source(card: 'second')]);
    await Future<void>.delayed(Duration.zero);
    expect(writes, 1);
    expect(store.terms, isEmpty);
    expect(notifications, 0);
    gate!.complete();
    await Future.wait([first, second]);
    expect(store.terms, hasLength(2));
    expect(notifications, 2);
    expect((await ReaderLearningStore.load()).terms, hasLength(2));
  });

  test(
      'failed setString leaves state and durable snapshot intact; queue recovers',
      () async {
    final store = await ReaderLearningStore.load();
    await store.save(term(), [source()]);
    final snapshot = Map.of(disk);
    var notifications = 0;
    store.addListener(() => notifications++);
    failWrite = true;
    await expectLater(
        store.save(term(card: 'new'), [source(card: 'new')]), throwsStateError);
    await expectLater(store.removeTerm('card'), throwsStateError);
    expect(disk, snapshot);
    expect(store.terms.single.cardId, 'card');
    expect(notifications, 0);
    expect((await ReaderLearningStore.load()).terms.single.cardId, 'card');
    failWrite = false;
    await store.removeTerm('card');
    expect(store.terms, isEmpty);
    expect(store.occurrencesForDocument(docA), isEmpty);
    expect((await ReaderLearningStore.load()).terms, isEmpty);
    expect(disk['flutter.recall.data.v3'], 'original dictionary and bookmarks');
  });

  test(
      'reject corrupt, unsupported, duplicate and orphan snapshots without writing',
      () async {
    final snapshots = <Object>[
      '{broken',
      42,
      jsonEncode({'version': 2, 'terms': [], 'occurrences': []}),
      jsonEncode({
        'version': 1,
        'terms': [term().toJson(), term().toJson()],
        'occurrences': []
      }),
      jsonEncode({
        'version': 1,
        'terms': [],
        'occurrences': [source().toJson()]
      }),
      jsonEncode({
        'version': 1,
        'terms': [term().toJson()],
        'occurrences': [source().toJson(), source().toJson()]
      }),
    ];
    for (final raw in snapshots) {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance =
          MethodChannelSharedPreferencesStore();
      disk['flutter.${ReaderLearningStore.storageKey}'] = raw;
      await expectLater(ReaderLearningStore.load(), throwsFormatException);
      expect(disk['flutter.${ReaderLearningStore.storageKey}'], raw);
    }
    expect(writes, 0);
  });

  test(
      'validates source identity, ranges, normalized finite geometry and bounded text',
      () {
    expect(ReaderOccurrence.fromJson(source().toJson()).id, source().id);
    expect(ReaderSavedTerm.fromJson(term().toJson()).term, 'power factor');
    final invalid = <Map<String, dynamic>>[
      {'documentId': 'not-a-sha'},
      {'page': 0},
      {'page': 1.5},
      {'start': -1},
      {'end': 10},
      {'id': 'forged'},
      {'rects': []},
      {
        'rects': [
          [0, 0, 2, 1]
        ]
      },
      {
        'rects': [
          [0, 0, double.nan, 1]
        ]
      },
      {
        'rects': [
          [.5, 0, .4, 1]
        ]
      },
      {
        'rects': [
          [0, 0, 0, 1]
        ]
      },
      {
        'rects': List.filled(4097, [0, 0, 1, 1])
      },
      {'text': List.filled(32769, 'x').join()},
      {'createdAt': 'yesterday'},
    ];
    for (final fields in invalid) {
      expect(() => ReaderOccurrence.fromJson({...source().toJson(), ...fields}),
          throwsFormatException);
    }
    expect(() => ReaderSavedTerm.fromJson({...term().toJson(), 'meaning': 12}),
        throwsFormatException);
  });

  test('queued writes complete after disposal without notifying listeners',
      () async {
    final store = await ReaderLearningStore.load();
    var notifications = 0;
    store.addListener(() => notifications++);
    gate = Completer<void>();
    final first = store.save(term(), [source()]);
    final second = store.save(term(card: 'second'), [source(card: 'second')]);
    await Future<void>.delayed(Duration.zero);
    expect(writes, 1);
    store.dispose();
    gate!.complete();
    await Future.wait([first, second]);
    expect(notifications, 0);
    expect(writes, 2);
    expect((await ReaderLearningStore.load()).terms, hasLength(2));
  });

  test('empty sources reject the entire write without persistence', () async {
    final store = await ReaderLearningStore.load();
    await expectLater(store.save(term(), []), throwsFormatException);
    expect(store.terms, isEmpty);
    expect(writes, 0);
  });

  test(
      'wrong-card source rejects entire write without modifying existing terms',
      () async {
    final store = await ReaderLearningStore.load();
    await expectLater(
        store.save(term(), [source(card: 'other')]), throwsFormatException);
    expect(store.terms, isEmpty);
    expect(writes, 0);
  });
}
