import 'package:flutter/material.dart';
import '../vocabulary.dart';
import 'corpus_stats.dart';
import 'corpus_widgets.dart';

// Recovered from Recall_Master_Guidelines_v3.0, sections 5 and 7.
// These are reference criteria, not proof of a particular card's AI execution.
// Provenance and exact excerpts: docs/development/AI_PRIORITY_CRITERIA.md.
const _priorityCriteria = {
  LearningPriority.high:
      '전공 필수 과목의 핵심 개념, 공식·법칙·계산에 직접 쓰이는 물리량, 다른 개념의 토대, 여러 과목에 반복적으로 등장하는 개념, 실습·설계·분석에 필수적인 용어.',
  LearningPriority.medium:
      '전공 학습과 기술 문서에 유용하나 핵심 원리를 이해하는 데 필수적이지 않은 장비·부품·응용 표현.',
  LearningPriority.low: '전공 관련성이 약하거나 독립적인 학습 가치가 낮은 일반 표현·주변 용어.',
};

/// Read-only decision aid: categorical priority and DF/N are separate axes.
class StudyEvidence extends StatefulWidget {
  const StudyEvidence(
      {super.key,
      required this.catalog,
      required this.card,
      this.initialSource = CorpusSource.textbook});
  final CorpusCatalog catalog;
  final RecallCard card;
  final CorpusSource initialSource;

  @override
  State<StudyEvidence> createState() => _StudyEvidenceState();
}

class _StudyEvidenceState extends State<StudyEvidence> {
  late CorpusSource _source = widget.initialSource;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final stats = widget.catalog.forTerm(card.displayTerm);
    final metadata = widget.catalog.metadata;
    final total = metadata == null
        ? null
        : _source == CorpusSource.textbook
            ? metadata.textbookDocuments
            : metadata.abstractDocuments;
    final df = stats?.df(_source);
    final ratio = df != null && total != null && total > 0 && df <= total
        ? df / total
        : null;
    final pending = metadata?.pending[normalizeCorpusTerm(card.displayTerm)];
    final priorityTitle = card.isPersonal ? '내 학습 우선순위' : 'AI 판단 학습 우선순위';
    final color = _source == CorpusSource.textbook
        ? const Color(0xFF087F79)
        : const Color(0xFF526BA8);
    final summary = stats == null
        ? '관측 자료가 없어 우선순위만 표시합니다.'
        : df == 0
            ? '선택한 자료에서 채택된 용례가 없습니다.'
            : '${card.learningPriority.label} 우선순위 · ${_source.label} $df개에서 관측';
    return Container(
      key: const ValueKey('study-evidence'),
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0E8ED))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(priorityTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('저장된 등급',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Chip(label: Text(card.learningPriority.label))
            ]),
        if (!card.isPersonal) ...[
          const Text('등급 기준 · Recall 지침 v3.0',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_priorityCriteria[card.learningPriority]!),
          const SizedBox(height: 12),
        ],
        const Text('이 단어에 저장된 판단 이유',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (card.priorityReason.trim().isNotEmpty)
          Text(card.priorityReason.trim())
        else
          const Text('우선순위 근거가 등록되지 않았습니다.'),
        const SizedBox(height: 20),
        const Text('코퍼스 관측 정보', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final source in CorpusSource.values)
            ChoiceChip(
                label: Text(
                    source == CorpusSource.textbook ? '교재 기준' : '논문 초록 기준'),
                selected: _source == source,
                onSelected: (_) => setState(() => _source = source)),
        ]),
        const SizedBox(height: 16),
        if (ratio != null) ...[
          PriorityCoverageMap(
              priority: card.learningPriority,
              coverage: ratio,
              sourceLabel: _source.label,
              priorityLabel: priorityTitle,
              color: color),
          const SizedBox(height: 12),
          Text('${_source.label} 등장 문서 비율 ${(ratio * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
        if (stats != null) ...[
          Wrap(spacing: 20, runSpacing: 8, children: [
            Text(
                total == null ? '등장 문서 $df개 (DF)' : '등장 문서 $df / $total개 (DF)'),
            Text('총 출현 ${stats.tf(_source)}회 (TF)'),
          ]),
          if (ratio == null) const Text('전체 문서 수 미제공 · 비율 그래프를 표시할 수 없습니다.'),
          if (pending != null && pending.tf(_source) > 0)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '의미 보류 ${pending.tf(_source)}회 · ${pending.df(_source)}개 문서 (그래프 제외)')),
        ] else
          const Text('이 용어의 코퍼스 데이터가 제공되지 않았습니다.'),
        const SizedBox(height: 16),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(summary,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(stats == null
                  ? '자료가 없으면 관측 범위를 판단할 수 없습니다. 등록된 우선순위의 근거를 먼저 확인하세요.'
                  : df == 0
                      ? '관측되지 않았다고 중요하지 않은 단어는 아닙니다. 우선순위 근거와 읽는 문서를 함께 확인하세요.'
                      : '위쪽은 높은 우선순위, 오른쪽은 넓은 관측 범위입니다. 지금 읽는 분야와 뜻이 맞는지도 확인하세요.'),
            ])),
        TextButton.icon(
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('판단 기준'),
          onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('학습 판단 기준'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          if (card.isPersonal)
                            const Text(
                                '내 단어에 저장된 우선순위입니다. AI 판단 결과로 표시하지 않습니다.')
                          else ...[
                            const Text('AI 판단 학습 우선순위',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            const Text(
                                '출처: Recall Master Guidelines v3.0 · 5절 학습 우선순위, 7절 판단 근거'),
                            const SizedBox(height: 12),
                            const Text(
                                '과거 분류 지침에서 확인한 기준입니다. 어휘 유형과 독립적으로, 단어의 길이·난이도·친숙함·일상 빈도가 아닌 전공에서의 개념적·교육적 중요성을 평가합니다.'),
                            for (final level in LearningPriority.values) ...[
                              const SizedBox(height: 12),
                              Text('${level.label} (${level.value})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(_priorityCriteria[level]!),
                            ],
                            const SizedBox(height: 12),
                            const Text(
                                '장비 이름이라는 이유만으로 높음을 부여하거나, 익숙하고 쉬운 핵심 용어라는 이유로 낮음을 부여하지 않습니다. 대상 전공과 제공된 교육과정에 따라 조정하며, 강의자료 없이 실제 교육과정 출현 빈도를 확인했다고 단정하지 않습니다.'),
                            const SizedBox(height: 12),
                            const Text(
                                '보통·낮음의 경계가 모호하면 보통으로 잠정 평가하고 검토 필요를 기록합니다. 모든 단어를 보통으로 분류하거나 높음의 비율을 인위적으로 맞추지 않습니다.'),
                            const SizedBox(height: 12),
                            const Text(
                                '단어별 판단 이유는 기존에 작성된 교육적 중요도 근거입니다. 이유가 없는 항목은 미등록으로 표시합니다.'),
                            const SizedBox(height: 12),
                            const Text('확인되지 않은 부분',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const Text(
                                '현재 데이터만으로는 각 단어의 실제 적용 프롬프트·AI 모델·검수 완료 여부를 확인할 수 없습니다. 저장된 등급은 이후 수정됐을 수 있으며, 검증된 중요도 점수는 아닙니다. 지침에는 수치 점수·가중치·등급별 빈도 임계값이 명시되어 있지 않습니다.'),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                              '세로축은 높음·보통·낮음의 범주이고, 가로축은 선택 자료의 DF ÷ 전체 문서 수입니다. 두 값을 합산한 점수나 자동 학습 순서는 만들지 않습니다. 논문은 초록 기준입니다.'),
                          if (metadata != null)
                            TextButton(
                                onPressed: () =>
                                    showCorpusMethod(context, metadata),
                                child: const Text('집계 기준')),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'))
                    ],
                  )),
        ),
      ]),
    );
  }
}

/// Plot with a categorical Y axis. Endpoint markers remain fully inside the plot.
class PriorityCoverageMap extends StatelessWidget {
  const PriorityCoverageMap(
      {super.key,
      required this.priority,
      required this.coverage,
      required this.sourceLabel,
      required this.priorityLabel,
      required this.color});
  final LearningPriority priority;
  final double coverage;
  final String sourceLabel, priorityLabel;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label:
            '$priorityLabel ${priority.label}, $sourceLabel 등장 문서 비율 ${(coverage * 100).toStringAsFixed(1)}%',
        child: ExcludeSemantics(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$priorityLabel ↑',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              for (final level in LearningPriority.values)
                SizedBox(
                    height: 54,
                    child: Center(
                        child: Text(level.label,
                            style: TextStyle(
                                fontWeight: level == priority
                                    ? FontWeight.w800
                                    : FontWeight.w400))))
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Column(children: [
              SizedBox(
                  height: 162,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final x = 10 +
                        coverage.clamp(0.0, 1.0) * (constraints.maxWidth - 20);
                    final y = priority.index * 54.0 + 27;
                    return Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                          child: Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF5F8FA),
                                  borderRadius: BorderRadius.circular(12)))),
                      Positioned(
                          left: 0,
                          right: 0,
                          top: priority.index * 54.0,
                          height: 54,
                          child:
                              ColoredBox(color: color.withValues(alpha: .08))),
                      for (final top in [54.0, 108.0])
                        Positioned(
                            left: 0,
                            right: 0,
                            top: top,
                            child: const Divider(
                                height: 1, color: Color(0xFFE0E8ED))),
                      Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          width: 1,
                          child:
                              ColoredBox(color: color.withValues(alpha: .35))),
                      Positioned(
                          left: x - 8,
                          top: y - 8,
                          width: 16,
                          height: 16,
                          child: Container(
                              key: const ValueKey('study-evidence-dot'),
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2)))),
                    ]);
                  })),
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('0%',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                if (constraints.maxWidth >=
                                    160 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(12) /
                                        12)
                                  Text('50%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                Text('100%',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]))),
            ])),
          ]),
          const Align(
              alignment: Alignment.centerRight, child: Text('등장 문서 비율 →')),
        ])),
      );
}
