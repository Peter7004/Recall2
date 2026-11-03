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
import 'package:recall/reader/reader_learning_guard_factory.dart';

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

  Future<ReaderLearningStore> loadStore() async {
    final store = await ReaderLearningStore.load();
    addTearDown(store.dispose);
    return store;
  }

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
    final store = await loadStore();
    final original = Map.of(disk);
    await store.save(term(), [source(), source(start: 50), source(doc: docB)]);
    final later = time.add(const Duration(days: 1));
    await store.save(term(at: later), [source(at: later)]);
    final loaded = await loadStore();
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
    final store = await loadStore();
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
    expect((await loadStore()).terms, hasLength(2));
  });

  test(
      'failed setString leaves state and durable snapshot intact; queue recovers',
      () async {
    final store = await loadStore();
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
    expect((await loadStore()).terms.single.cardId, 'card');
    failWrite = false;
    await store.removeTerm('card');
    expect(store.terms, isEmpty);
    expect(store.occurrencesForDocument(docA), isEmpty);
    expect((await loadStore()).terms, isEmpty);
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
      await expectLater(loadStore(), throwsFormatException);
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
    final store = await loadStore();
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
    expect((await loadStore()).terms, hasLength(2));
  });

  test('empty sources reject the entire write without persistence', () async {
    final store = await loadStore();
    await expectLater(store.save(term(), []), throwsFormatException);
    expect(store.terms, isEmpty);
    expect(writes, 0);
  });

  test(
      'wrong-card source rejects entire write without modifying existing terms',
      () async {
    final store = await loadStore();
    await expectLater(
        store.save(term(), [source(card: 'other')]), throwsFormatException);
    expect(store.terms, isEmpty);
    expect(writes, 0);
  });
  test(
      'independent stores serialize concurrent saves without losing either term',
      () async {
    final first = await loadStore(), second = await loadStore();
    await Future.wait([
      first.save(term(card: 'A'), [source(card: 'A')]),
      second.save(term(card: 'B'), [source(card: 'B')]),
    ]);
    final restored = await loadStore();
    expect(restored.terms.map((t) => t.cardId), unorderedEquals(['A', 'B']));
    expect(restored.occurrencesForDocument(docA), hasLength(2));
  });

  test(
      'latest persisted state prevents resurrection even without change notification',
      () async {
    final first = await loadStore();
    await first.save(term(card: 'A'), [source(card: 'A')]);
    final stale = await loadStore();
    disk['flutter.${ReaderLearningStore.storageKey}'] =
        jsonEncode({'version': 1, 'terms': [], 'occurrences': []});
    expect(stale.terms.single.cardId, 'A');
    await stale.save(term(card: 'B'), [source(card: 'B')]);
    expect((await loadStore()).terms.map((t) => t.cardId), ['B']);
  });

  test('stale removal preserves unrelated records added by another writer',
      () async {
    final store = await loadStore();
    await store.save(term(card: 'A'), [source(card: 'A')]);
    final stale = await loadStore();
    disk['flutter.${ReaderLearningStore.storageKey}'] = jsonEncode({
      'version': 1,
      'terms': [term(card: 'A').toJson(), term(card: 'B').toJson()],
      'occurrences': [source(card: 'A').toJson(), source(card: 'B').toJson()]
    });
    await stale.removeTerm('A');
    final loaded = await loadStore();
    expect(loaded.terms.single.cardId, 'B');
    expect(loaded.occurrencesFor('B'), hasLength(1));
  });

  test('other loaded instances receive successful save and removal updates',
      () async {
    final first = await loadStore(), observer = await loadStore();
    final saved = Completer<void>(), removed = Completer<void>();
    observer.addListener(() {
      if (observer.terms.isNotEmpty && !saved.isCompleted) saved.complete();
      if (saved.isCompleted && observer.terms.isEmpty && !removed.isCompleted) {
        removed.complete();
      }
    });
    await first.save(term(), [source()]);
    await saved.future.timeout(const Duration(seconds: 2));
    await first.removeTerm('card');
    await removed.future.timeout(const Duration(seconds: 2));
    expect(observer.terms, isEmpty);
  });

  test(
      'external corruption after load is never overwritten; later valid data recovers',
      () async {
    final store = await loadStore();
    await store.save(term(), [source()]);
    final valid = disk['flutter.${ReaderLearningStore.storageKey}'];
    disk['flutter.${ReaderLearningStore.storageKey}'] = '{broken';
    final beforeWrites = writes;
    await expectLater(store.save(term(card: 'new'), [source(card: 'new')]),
        throwsFormatException);
    expect(writes, beforeWrites);
    expect(disk['flutter.${ReaderLearningStore.storageKey}'], '{broken');
    expect(store.terms.single.cardId, 'card');
    disk['flutter.${ReaderLearningStore.storageKey}'] = valid!;
    await store.save(term(card: 'new'), [source(card: 'new')]);
    expect((await loadStore()).terms, hasLength(2));
  });
  test(
      'external refresh failure preserves last good state and reports recovery',
      () async {
    final store = await loadStore();
    await store.save(term(), [source()]);
    final valid = disk['flutter.${ReaderLearningStore.storageKey}'];
    final failed = Completer<void>(), recovered = Completer<void>();
    store.addListener(() {
      if (store.synchronizationError != null && !failed.isCompleted) {
        failed.complete();
      }
      if (failed.isCompleted &&
          store.synchronizationError == null &&
          !recovered.isCompleted) {
        recovered.complete();
      }
    });
    disk['flutter.${ReaderLearningStore.storageKey}'] = '{broken';
    learningWriteGuard.didChange();
    await failed.future.timeout(const Duration(seconds: 2));
    expect(store.terms.single.cardId, 'card');
    final beforeWrites = writes;
    disk['flutter.${ReaderLearningStore.storageKey}'] = valid!;
    learningWriteGuard.didChange();
    await recovered.future.timeout(const Duration(seconds: 2));
    expect(store.terms.single.cardId, 'card');
    expect(writes, beforeWrites);
  });
}
