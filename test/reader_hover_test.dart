import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/term_hover_region.dart';

void main() {
  testWidgets(
      'dictionary changes discard old analysis notifications and highlights',
      (tester) async {
    var dictionary = 1;
    final states = <TermAnalysisState>[];
    final old = Completer<List<TermHoverArea>>();
    const term = TermHoverArea('Old', [Rect.fromLTWH(0, 0, 1, 1)]);
    Widget view() => MaterialApp(
        home: SizedBox(
            width: 200,
            height: 200,
            child: TermHoverRegion(
                cacheKey: dictionary,
                highlightAll: true,
                onAnalysisChanged: states.add,
                loadAreas: () =>
                    dictionary == 1 ? old.future : Future.value([]))));
    await tester.pumpWidget(view());
    dictionary = 2;
    await tester.pumpWidget(view());
    await tester.pump();
    old.complete([term]);
    await tester.pump();
    await tester.pump();
    expect(states.last, const TermAnalysisState(TermAnalysisStatus.ready));
    expect(states.where((state) => state.matchCount != 0), isEmpty);
    final paint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<TermHoverPainter>()
        .single;
    expect(paint.areas, isEmpty);
  });
  testWidgets('zero matches, unavailable, error and explicit hover-only retry',
      (tester) async {
    final states = <TermAnalysisState>[];
    var retry = 0;
    var loads = 0;
    var outcome = 0;
    const term = TermHoverArea('Known', [Rect.fromLTWH(0, 0, 1, 1)]);
    Widget view() => MaterialApp(
        home: SizedBox(
            width: 200,
            height: 200,
            child: TermHoverRegion(
                cacheKey: 1,
                retryToken: retry,
                onAnalysisChanged: states.add,
                loadAreas: () async {
                  loads++;
                  if (outcome == 1) throw const TermTextUnavailable('텍스트 없음');
                  if (outcome == 2) throw StateError('native failure');
                  return outcome == 3 ? [term] : [];
                })));
    await tester.pumpWidget(view());
    expect(states.last.status, TermAnalysisStatus.idle);
    expect(loads, 0);
    retry++;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(states.last, const TermAnalysisState(TermAnalysisStatus.ready));
    expect(states.any((s) => s.status == TermAnalysisStatus.loading), isTrue);
    outcome = 1;
    retry++;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(states.last.status, TermAnalysisStatus.unavailable);
    expect(states.last.message, '텍스트 없음');
    outcome = 2;
    retry++;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(states.last.status, TermAnalysisStatus.error);
    expect(states.last.message, contains('다시 시도'));
    outcome = 3;
    retry++;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(states.last,
        const TermAnalysisState(TermAnalysisStatus.ready, matchCount: 1));
    final paints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<TermHoverPainter>()
        .single;
    expect(paints.area, isNull);
    expect(paints.areas, isEmpty);
    expect(loads, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry clears highlights and ignores stale success and failure',
      (tester) async {
    var retry = 0;
    final states = <TermAnalysisState>[];
    final oldSuccess = Completer<List<TermHoverArea>>();
    final oldFailure = Completer<List<TermHoverArea>>();
    final fresh = Completer<List<TermHoverArea>>();
    const term = TermHoverArea('Known', [Rect.fromLTWH(0, 0, 1, 1)]);
    Widget view() => MaterialApp(
        home: SizedBox(
            width: 200,
            height: 200,
            child: TermHoverRegion(
                cacheKey: 1,
                retryToken: retry,
                highlightAll: true,
                onAnalysisChanged: states.add,
                loadAreas: () => switch (retry) {
                      0 => Future.value([term]),
                      1 => oldSuccess.future,
                      2 => oldFailure.future,
                      _ => fresh.future
                    })));
    TermHoverPainter paint() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<TermHoverPainter>()
        .single;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(paint().areas, [term]);
    retry = 1;
    await tester.pumpWidget(view());
    expect(paint().areas, isEmpty);
    retry = 2;
    await tester.pumpWidget(view());
    retry = 3;
    await tester.pumpWidget(view());
    oldSuccess.complete([term]);
    oldFailure.completeError(StateError('stale'));
    await tester.pump();
    expect(paint().areas, isEmpty);
    expect(states.last.status, TermAnalysisStatus.loading);
    fresh.complete([]);
    await tester.pump();
    await tester.pump();
    expect(states.last, const TermAnalysisState(TermAnalysisStatus.ready));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'post-frame callback can rebuild parent without notification loop',
      (tester) async {
    var callbacks = 0;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, update) {
      return SizedBox(
          width: 200,
          height: 200,
          child: TermHoverRegion(
              cacheKey: 1,
              highlightAll: true,
              loadAreas: () async => [],
              onAnalysisChanged: (_) {
                callbacks++;
                update(() {});
              }));
    })));
    await tester.pumpAndSettle();
    expect(callbacks, inInclusiveRange(2, 3));
    expect(tester.takeException(), isNull);
  });
  test('PDF rectangles normalize width and height independently', () {
    expect(
        normalizedPageRect(
            const Rect.fromLTWH(20, 80, 40, 40), const Size(200, 400)),
        const Rect.fromLTRB(.1, .2, .3, .3));
  });
  TermHoverPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<TermHoverPainter>()
      .single;

  testWidgets(
      'mouse hover highlights full term fragments, clears on whitespace, caches page',
      (tester) async {
    var loads = 0;
    var taps = 0;
    const term = TermHoverArea('Power factor',
        [Rect.fromLTWH(.1, .2, .2, .1), Rect.fromLTWH(.1, .4, .2, .1)]);
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(children: [
                  Positioned.fill(
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => taps++,
                          child: const SizedBox.expand())),
                  Positioned.fill(
                      child: TermHoverRegion(
                          cacheKey: 1,
                          loadAreas: () async {
                            loads++;
                            return [term];
                          })),
                ])))));
    final box = tester.getRect(find.byType(TermHoverRegion));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: box.topLeft);
    await mouse.moveTo(box.topLeft + const Offset(40, 50));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(painter(tester).area!.term, 'Power factor');
    expect(painter(tester).area!.rects.length, 2);
    await mouse.moveTo(box.topLeft + const Offset(40, 90));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(painter(tester).area, same(term));
    expect(loads, 1);
    await tester.tapAt(box.topLeft + const Offset(40, 50));
    expect(
        taps, 1); // Decorative overlay must not intercept the viewer's input.
    await mouse.moveTo(box.topLeft + const Offset(40, 70));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(painter(tester).area, isNull);
    await mouse.removePointer();
  });

  testWidgets(
      'late hover result after exit is ignored; touch does not load text',
      (tester) async {
    final pending = Completer<List<TermHoverArea>>();
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 200,
                height: 200,
                child: TermHoverRegion(
                    cacheKey: 1,
                    loadAreas: () {
                      loads++;
                      return pending.future;
                    })))));
    final box = tester.getRect(find.byType(TermHoverRegion));
    await tester.tapAt(box.center);
    expect(loads, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: box.topLeft);
    await mouse.moveTo(box.center);
    await tester.pump(const Duration(milliseconds: 60));
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    pending.complete([
      const TermHoverArea('Term', [Rect.fromLTWH(0, 0, 1, 1)])
    ]);
    await tester.pump();
    expect(painter(tester).area, isNull);
    expect(loads, 1);
    await mouse.removePointer();
  });
  testWidgets(
      'always-on loads without pointer, survives exit, returns to hover; stale dictionary ignored',
      (tester) async {
    var all = true;
    var key = 1;
    final late = Completer<List<TermHoverArea>>();
    const term = TermHoverArea('Known', [Rect.fromLTWH(.1, .1, .2, .2)]);
    Future<List<TermHoverArea>> load() =>
        key == 1 ? Future.value([term]) : late.future;
    Widget view() => MaterialApp(
        home: Center(
            child: SizedBox(
                width: 200,
                height: 200,
                child: TermHoverRegion(
                    cacheKey: key, highlightAll: all, loadAreas: load))));
    await tester.pumpWidget(view());
    await tester.pump();
    expect(painter(tester).areas, [term]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    expect(painter(tester).areas, [term]);
    all = false;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(painter(tester).areas, isEmpty);
    expect(painter(tester).area, isNull);
    final box = tester.getRect(find.byType(TermHoverRegion));
    await mouse.moveTo(box.topLeft + const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(painter(tester).area, term);
    key = 2;
    all = true;
    await tester.pumpWidget(view());
    await tester.pump();
    expect(painter(tester).areas, isEmpty);
    all = false;
    await tester.pumpWidget(view());
    late.complete([term]);
    await tester.pump();
    expect(painter(tester).areas, isEmpty);
    expect(painter(tester).area, isNull);
    await mouse.removePointer();
  });
}
