import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/corpus/corpus_stats.dart';
import 'package:recall/corpus/study_evidence.dart';
import 'package:recall/vocabulary.dart';

CorpusCatalog catalog({bool zero = false, bool metadata = true}) {
  final csv =
      '${corpusColumns.join(',')}\nPower,${zero ? '0,0,0,0' : '20,11,300,64'}';
  final data = CorpusCatalog.parse(csv);
  return metadata
      ? data.withMetadata(
          jsonEncode({
            'schema_version': 1,
            'basis': 'provisional_accepted',
            'date': '2026-11-12',
            'textbook_documents': 22,
            'abstract_documents': 639,
            'csv_sha256': sha256.convert(utf8.encode(csv)).toString(),
            'pending': {
              'power': [100, 20, 500, 200]
            },
          }),
          csv)
      : data;
}

RecallCard card(
        {LearningPriority priority = LearningPriority.high,
        bool personal = false}) =>
    RecallCard(
        id: 'unchanged-id',
        front: 'Power',
        meaning: '전력',
        example: '',
        dueAt: DateTime(2026),
        intervalMinutes: 30,
        stabilityDays: 2,
        ease: 2.5,
        lastReviewed: null,
        isBookmarked: true,
        learningPriority: priority,
        priorityReason: '회로 학습의 기본 용어',
        collector: personal ? 'reader:personal' : '');

Widget view(CorpusCatalog data, RecallCard value, {double scale = 1}) =>
    MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: StudyEvidence(catalog: data, card: value))))));

void main() {
  testWidgets(
      'source toggle moves coverage without changing priority or card data',
      (tester) async {
    final value = card();
    final before = jsonEncode(value.toJson());
    await tester.pumpWidget(view(catalog(), value));
    final initial =
        tester.widget<PriorityCoverageMap>(find.byType(PriorityCoverageMap));
    expect(initial.coverage, .5);
    expect(initial.priority, LearningPriority.high);
    expect(find.text('등장 문서 11 / 22개 (DF)'), findsOneWidget);
    expect(find.text('총 출현 20회 (TF)'), findsOneWidget);
    expect(find.text(value.priorityReason), findsOneWidget);
    expect(find.text('AI 판단 학습 우선순위'), findsOneWidget);
    expect(find.text('등급 기준 · Recall 지침 v3.0'), findsOneWidget);
    final oldPoint =
        tester.getCenter(find.byKey(const ValueKey('study-evidence-dot')));
    await tester.tap(find.text('논문 초록 기준'));
    await tester.pumpAndSettle();
    final changed =
        tester.widget<PriorityCoverageMap>(find.byType(PriorityCoverageMap));
    final newPoint =
        tester.getCenter(find.byKey(const ValueKey('study-evidence-dot')));
    expect(changed.coverage, 64 / 639);
    expect(changed.priority, LearningPriority.high);
    expect(newPoint.dx, lessThan(oldPoint.dx));
    expect(newPoint.dy, oldPoint.dy);
    expect(find.text('등장 문서 64 / 639개 (DF)'), findsOneWidget);
    expect(find.text('총 출현 300회 (TF)'), findsOneWidget);
    await tester.ensureVisible(find.text('판단 기준'));
    await tester.tap(find.text('판단 기준'));
    await tester.pumpAndSettle();
    expect(find.text('학습 판단 기준'), findsOneWidget);
    expect(find.textContaining('검증된 중요도 점수는 아닙니다'), findsOneWidget);
    expect(find.text('높음 (high)'), findsOneWidget);
    expect(find.text('보통 (medium)'), findsOneWidget);
    expect(find.text('낮음 (low)'), findsOneWidget);
    expect(find.textContaining('실제 적용 프롬프트·AI 모델·검수 완료 여부'), findsOneWidget);
    expect(find.textContaining('수치 점수·가중치·등급별 빈도 임계값'), findsOneWidget);
    await tester.ensureVisible(find.text('집계 기준'));
    await tester.tap(find.text('집계 기준'));
    await tester.pumpAndSettle();
    expect(find.text('빈도 집계 기준'), findsOneWidget);
    expect(jsonEncode(value.toJson()), before);
  });

  testWidgets('zero excludes pending, missing data never becomes zero coverage',
      (tester) async {
    await tester.pumpWidget(view(catalog(zero: true), card()));
    expect(
        tester
            .widget<PriorityCoverageMap>(find.byType(PriorityCoverageMap))
            .coverage,
        0);
    expect(find.text('의미 보류 100회 · 20개 문서 (그래프 제외)'), findsOneWidget);
    expect(find.text('선택한 자료에서 채택된 용례가 없습니다.'), findsOneWidget);
    await tester.pumpWidget(
        view(const CorpusCatalog.empty(), card().copyWith(priorityReason: '')));
    expect(find.byType(PriorityCoverageMap), findsNothing);
    expect(find.textContaining('제공되지'), findsOneWidget);
    expect(find.textContaining('0.0%'), findsNothing);
    expect(find.text('우선순위 근거가 등록되지 않았습니다.'), findsOneWidget);
    await tester.pumpWidget(view(catalog(metadata: false), card()));
    expect(find.byType(PriorityCoverageMap), findsNothing);
    expect(find.text('등장 문서 11개 (DF)'), findsOneWidget);
    expect(find.textContaining('전체 문서 수 미제공'), findsOneWidget);
  });

  testWidgets(
      'all categorical levels and personal provenance fit 320px at 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? previousY;
    for (final priority in LearningPriority.values) {
      await tester.pumpWidget(
          view(catalog(), card(priority: priority, personal: true), scale: 2));
      await tester.pumpAndSettle();
      final graph = find.byType(PriorityCoverageMap);
      final point =
          tester.getCenter(find.byKey(const ValueKey('study-evidence-dot')));
      final localY = point.dy - tester.getTopLeft(graph).dy;
      if (previousY != null) expect(localY, greaterThan(previousY));
      previousY = localY;
      expect(find.text('내 학습 우선순위'), findsOneWidget);
      expect(find.text('AI 판단 학습 우선순위'), findsNothing);
      expect(find.text('등급 기준 · Recall 지침 v3.0'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
