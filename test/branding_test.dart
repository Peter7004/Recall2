import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/branding.dart';
import 'package:recall/main.dart';
import 'package:recall/recall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loading has one finite reveal with the supplied logo',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RecallLoadingScreen())));
    final opacity = find.descendant(
        of: find.byType(RecallLoadingScreen), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(0.35, 0.001));
    await tester.pump(const Duration(milliseconds: 325));
    expect(tester.widget<Opacity>(opacity).opacity, greaterThan(0.35));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        recallLogoAsset);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion and web handoff render a static loading logo',
      (tester) async {
    for (final disableAnimations in [true, false]) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: RecallLoadingScreen(animate: disableAnimations),
      )));
      final opacity = find.descendant(
          of: find.byType(RecallLoadingScreen), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      final transform = find.descendant(
          of: find.byType(RecallLoadingScreen),
          matching: find.byType(Transform));
      expect(
          tester
              .widget<Transform>(transform.first)
              .transform
              .getTranslation()
              .y,
          0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('logo stays during real loading and ready data opens immediately',
      (tester) async {
    final pending = Completer<RecallStore>();
    await tester.pumpWidget(
        MaterialApp(home: HomeShell(loadStore: () => pending.future)));
    expect(find.byType(RecallLoadingScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RecallLoadingScreen), findsOneWidget);
    final store = await RecallStore.load();
    pending.complete(store);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RecallLoadingScreen), findsNothing);
    expect(find.text('등록된 용어가 없습니다.'), findsOneWidget);
    expect(find.byType(RecallHeaderBrand), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'loading and header artwork fit small portrait and landscape screens',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 640), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
          const MaterialApp(home: RecallLoadingScreen(animate: false)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const RecallApp());
      await tester.pumpAndSettle();
      expect(find.byType(RecallHeaderBrand), findsOneWidget);
      final images = find.descendant(
          of: find.byType(RecallHeaderBrand), matching: find.byType(Image));
      expect(images, findsNWidgets(2));
      for (final image in tester.widgetList<Image>(images)) {
        expect((image.image as AssetImage).assetName, recallLogoAsset);
      }
      expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('startup data errors retain the saved data and retry works',
      (tester) async {
    SharedPreferences.setMockInitialValues({'recall.data.v3': '{broken'});
    await tester.pumpWidget(const RecallApp());
    await tester.pumpAndSettle();
    expect(find.byType(RecallLoadingScreen), findsNothing);
    expect(find.text('저장 데이터를 불러오지 못했습니다. 기존 저장본은 보존됩니다.'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('recall.data.v3'), '{broken');
    await preferences.setString(
        'recall.data.v3',
        jsonEncode({
          'schemaVersion': 3,
          'subjectSettingsVersion': 1,
          'entries': [],
          'decks': [],
          'categories': [],
        }));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(RecallLoadingScreen), findsNothing);
    expect(find.text('등록된 용어가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
