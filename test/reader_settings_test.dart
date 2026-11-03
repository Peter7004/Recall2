import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/reader/reader_settings.dart';
import 'package:recall/recall_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Reader settings persist without writing dictionary or progress',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recall.data.v3', 'keep');
    await prefs.setString('recall.reader.progress.v1.doc', 'keep');
    await const ReaderSettings(highlightAll: true, paged: true).save();
    final settings = await ReaderSettings.load();
    expect(settings.highlightAll, isTrue);
    expect(settings.paged, isTrue);
    expect(prefs.getString('recall.data.v3'), 'keep');
    expect(prefs.getString('recall.reader.progress.v1.doc'), 'keep');
  });
  test('Reader repeated save never unbookmarks or changes existing definitions',
      () async {
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '', front: 'Power factor', meaning: '역률', example: 'example');
    final before = store.allCards.single.card;
    await store.ensureBookmarked(before.id);
    await store.ensureBookmarked(before.id);
    final after = store.cardById(before.id)!;
    expect(after.isBookmarked, isTrue);
    expect({...after.toJson()}..remove('isBookmarked'),
        {...before.toJson()}..remove('isBookmarked'));
    final restored = await RecallStore.load();
    expect(restored.cardById(before.id)!.isBookmarked, isTrue);
    store.dispose();
    restored.dispose();
  });
  test('failed bookmark link restores durable preference cache and card state',
      () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    final disk = <String, Object>{};
    var fail = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method.startsWith('getAll')) return Map<String, Object>.of(disk);
      if (call.method == 'setString') {
        if (fail) return false;
        final args = call.arguments as Map;
        disk[args['key'] as String] = args['value'] as String;
        return true;
      }
      throw StateError('Unexpected call');
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      SharedPreferences.setMockInitialValues({});
    });
    final store = await RecallStore.load();
    await store.addCard(
        deckId: '', front: 'Power factor', meaning: '역률', example: '');
    final card = store.allCards.single.card;
    final before = disk['flutter.recall.data.v3'];
    fail = true;
    await expectLater(store.ensureBookmarked(card.id), throwsStateError);
    expect(store.cardById(card.id)!.isBookmarked, isFalse);
    expect((await SharedPreferences.getInstance()).getString('recall.data.v3'),
        before);
    expect(disk['flutter.recall.data.v3'], before);
    fail = false;
    await store.ensureBookmarked(card.id);
    expect(store.cardById(card.id)!.isBookmarked, isTrue);
    store.dispose();
  });
}
