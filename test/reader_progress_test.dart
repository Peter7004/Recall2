import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/reader_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('content identity is stable and different documents stay independent',
      () async {
    final a = ReaderProgress.documentId(Uint8List.fromList([1, 2, 3]));
    final b = ReaderProgress.documentId(Uint8List.fromList([1, 2, 4]));
    expect(a, ReaderProgress.documentId(Uint8List.fromList([1, 2, 3])));
    expect(a, isNot(b));
    await const ReaderProgress(page: 8, x: .2, y: .7, zoom: 2, paged: true)
        .save(a);
    await const ReaderProgress(page: 3, y: .3).save(b);
    final restored = await ReaderProgress.load(a);
    expect(restored!.page, 8);
    expect(restored.x, .2);
    expect(restored.y, .7);
    expect(restored.zoom, 2);
    expect(restored.paged, isTrue);
    expect((await ReaderProgress.load(b))!.page, 3);
  });

  test('missing and corrupt progress do not prevent opening a PDF', () async {
    expect(await ReaderProgress.load('missing'), isNull);
    SharedPreferences.setMockInitialValues({
      'recall.reader.progress.v1.bad': '{broken',
      'recall.data.v3': 'existing vocabulary data',
    });
    expect(await ReaderProgress.load('bad'), isNull);
    await const ReaderProgress(page: 2).save('new');
    expect((await SharedPreferences.getInstance()).getString('recall.data.v3'),
        'existing vocabulary data');
  });
}
