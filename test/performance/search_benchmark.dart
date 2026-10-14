import 'package:flutter_test/flutter_test.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Run explicitly with `flutter test test/performance/search_benchmark.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('dictionary performance with 3000 synthetic entries', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await RecallStore.load();
    addTearDown(store.dispose);
    await store.importCsvDeck(
      csvText: [
        'word,meaning,definition,category,subcategory',
        for (var i = 0; i < 3000; i++)
          'power term ${i.toString().padLeft(4, '0')},meaning $i,'
              'Definition with charge and current $i,Engineering,Subject ${i % 20}',
      ].join('\n'),
    );
    final subjects = store.categories.map((c) => c.id).toList();
    var checksum = 0;
    void measure(String label, int iterations, int Function(int) action) {
      for (var i = 0; i < iterations; i++) {
        checksum += action(i);
      }
      final samples = <int>[];
      for (var sample = 0; sample < 5; sample++) {
        final watch = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          checksum += action(i);
        }
        watch.stop();
        samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      // Timing is informational, not a flaky pass/fail threshold.
      // ignore: avoid_print
      print('$label: median ${samples[2]} us / $iterations calls');
    }

    measure(
        'Repeated search',
        100,
        (i) => store
            .searchCards(['', 'power', 'charge', 'missing'][i % 4])
            .length);
    measure(
        'Distinct search',
        100,
        (i) =>
            store.searchCards('term ${i.toString().padLeft(4, '0')}').length);
    measure('Review count', 500, (_) => store.dueCount);
    measure('Subject list counts', 100,
        (i) => store.cardsInCategory(subjects[i % subjects.length]).length);
    expect(checksum, greaterThan(0));
    expect(store.totalCards, 3000);
  });
}
