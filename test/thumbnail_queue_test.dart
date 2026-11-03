import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/thumbnail_queue.dart';

void main() {
  test('two running jobs only; cancelled offscreen work never starts',
      () async {
    final discarded = <int>[];
    final queue = ThumbnailQueue<int>(discard: discarded.add);
    final a = Completer<int?>(), b = Completer<int?>();
    final first = queue.submit(() => a.future);
    final second = queue.submit(() => b.future);
    var starts = 0;
    final offscreen = queue.submit(() async {
      starts++;
      return 3;
    });
    expect(queue.activeCount, 2);
    expect(queue.pendingCount, 1);
    offscreen.cancel();
    expect(await offscreen.future, isNull);
    expect(queue.pendingCount, 0);
    a.complete(1);
    b.complete(2);
    expect(await first.future, 1);
    expect(await second.future, 2);
    expect(starts, 0);
    expect(discarded, isEmpty);
    queue.dispose();
  });

  test('closing panel cancels active work and frees late image results',
      () async {
    final discarded = <int>[];
    var cancelled = 0;
    final queue = ThumbnailQueue<int>(discard: discarded.add);
    final pending = Completer<int?>();
    final job = queue.submit(() => pending.future, onCancel: () => cancelled++);
    queue.dispose();
    expect(await job.future, isNull);
    expect(cancelled, 1);
    pending.complete(42);
    await Future<void>.delayed(Duration.zero);
    expect(discarded, [42]);
    expect(queue.activeCount, 0);
    final afterClose = queue.submit(() async => 99);
    expect(await afterClose.future, isNull);
  });
}
