import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/reader/term_hover_region.dart';

void main() {
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
}
