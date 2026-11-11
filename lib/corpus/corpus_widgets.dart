import 'package:flutter/material.dart';
import 'corpus_stats.dart';

/// Independent document coverage, not a combined importance or confidence score.
class CorpusRecommendationEvidence extends StatelessWidget {
  const CorpusRecommendationEvidence({
    super.key,
    required this.catalog,
    required this.term,
    required this.selectedSource,
  });

  final CorpusCatalog catalog;
  final String term;
  final CorpusSource selectedSource;

  @override
  Widget build(BuildContext context) {
    final stats = catalog.forTerm(term);
    if (stats == null) return const SizedBox.shrink();
    final metadata = catalog.metadata;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('추천 근거', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >=
            360 * MediaQuery.textScalerOf(context).scale(14) / 14;
        final width =
            twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final source in CorpusSource.values)
            SizedBox(
              width: width,
              child: _CorpusCoverage(
                source: source,
                df: stats.df(source),
                tf: stats.tf(source),
                total: metadata == null
                    ? null
                    : source == CorpusSource.textbook
                        ? metadata.textbookDocuments
                        : metadata.abstractDocuments,
                selected: source == selectedSource,
              ),
            ),
        ]);
      }),
      const SizedBox(height: 10),
      Text('원형: 등장 문서 비율 (DF ÷ 자료 수)',
          style: Theme.of(context).textTheme.bodySmall),
      if (metadata != null) ...[
        Text('문맥 필터 적용 · 보류 제외', style: Theme.of(context).textTheme.bodySmall),
        TextButton(
            onPressed: () => showCorpusMethod(context, metadata),
            child: const Text('집계 기준')),
      ],
    ]);
  }
}

class _CorpusCoverage extends StatelessWidget {
  const _CorpusCoverage(
      {required this.source,
      required this.df,
      required this.tf,
      required this.total,
      required this.selected});
  final CorpusSource source;
  final int df, tf;
  final int? total;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = source == CorpusSource.textbook
        ? const Color(0xFF087F79)
        : const Color(0xFF526BA8);
    final ratio =
        total != null && total! > 0 && df <= total! ? df / total! : null;
    final percentage =
        ratio == null ? null : '${(ratio * 100).toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: selected ? color : const Color(0xFFE7EDF1),
            width: selected ? 2 : 1),
      ),
      child: Column(children: [
        Text(source.label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        if (selected) const Text('선택한 기준', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          if (ratio != null)
            Semantics(
              label: '${source.label} 등장 문서 비율 $percentage, $df / $total개',
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 78,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(
                        child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 8,
                      color: color,
                      backgroundColor: const Color(0xFFE7EDF1),
                    )),
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(percentage!,
                                style: TextStyle(
                                    fontSize: 18,
                                    color: color,
                                    fontWeight: FontWeight.w800)))),
                  ]),
                ),
              ),
            )
          else
            const SizedBox(
                width: 78,
                child: Text('전체 문서 수 미제공', textAlign: TextAlign.center)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(ratio == null
                    ? '등장 문서 $df개 (DF)'
                    : '등장 문서 $df / $total개 (DF)'),
                const SizedBox(height: 6),
                Text('총 출현 $tf회 (TF)'),
              ])),
        ]),
      ]),
    );
  }
}

void showCorpusMethod(BuildContext context, CorpusMetadata metadata) {
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('빈도 집계 기준'),
            content: SingleChildScrollView(
                child: Text('${metadata.date} 재집계\n\n'
                    'PDF ${metadata.textbookDocuments}개 파일과 논문 초록 ${metadata.abstractDocuments}개를 분석했습니다. 논문 전체 본문 빈도가 아닙니다.\n\n'
                    '전공 문맥 자동 필터를 적용한 집계입니다. 원문 위치와 판정 규칙으로 재현할 수 있지만, 모든 용례의 의미를 사람이 검수한 통계는 아닙니다. 의미가 불확실한 용례는 보류로 분리하며 빈도와 추천 정렬에 포함하지 않습니다. 채택값 0은 실제 출현이 없다는 뜻이 아닙니다.\n\n'
                    'PDF는 책 수가 아닌 파일 수이며 전체 교재와 장별 파일의 내용이 겹칠 수 있습니다. 초록은 최종 인적 검토 전 후보 자료입니다.\n\n'
                    'TF는 등장 횟수, DF는 등장한 파일·초록 수입니다. 채택 DF와 보류 DF는 같은 문서를 포함할 수 있어 합산하지 않습니다.\n\n'
                    '원형 그래프는 각 자료의 DF를 전체 파일·초록 수로 나눈 비율입니다. 두 비율의 합이 100%일 필요는 없으며, 중요도나 의미 판정의 정확도를 나타내지 않습니다. 추천은 선택 자료의 DF, 같은 DF일 때 TF 순입니다. 복습 단어는 오래전에 학습한 순서를 먼저 적용합니다.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'))
            ],
          ));
}

class CorpusInfo extends StatelessWidget {
  const CorpusInfo({super.key, required this.catalog, required this.term});
  final CorpusCatalog catalog;
  final String term;
  @override
  Widget build(BuildContext context) {
    if (!catalog.available) return const SizedBox.shrink();
    final stats = catalog.forTerm(term);
    final metadata = catalog.metadata;
    final pending = metadata?.pending[normalizeCorpusTerm(term)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('코퍼스 관측 정보', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (metadata != null) ...[
          Text(
              'PDF ${metadata.textbookDocuments}개 · 논문 초록 ${metadata.abstractDocuments}개'),
          const Text('문맥 필터 적용 · 보류 제외'),
        ],
        if (stats == null)
          const Text('이 용어의 코퍼스 데이터가 제공되지 않았습니다.')
        else ...[
          Text(metadata != null && stats.observation == CorpusScope.unobserved
              ? '채택 용례 미관측'
              : stats.observation.label),
          Text('교재·강의자료: TF ${stats.textbookTf} · DF ${stats.textbookDf}'),
          Text('논문 초록: TF ${stats.abstractTf} · DF ${stats.abstractDf}'),
          if (pending != null) ...[
            Text(
                '의미 보류 — PDF: ${pending.textbookTf}회 · ${pending.textbookDf}개 파일'),
            Text(
                '의미 보류 — 초록: ${pending.abstractTf}회 · ${pending.abstractDf}개 초록'),
          ],
          const SizedBox(height: 4),
          Text('TF: 출현 횟수 · DF: 등장 문서 수',
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (metadata != null)
          TextButton(
              onPressed: () => showCorpusMethod(context, metadata),
              child: const Text('집계 기준')),
      ]),
    );
  }
}

class CorpusControls extends StatelessWidget {
  const CorpusControls(
      {super.key,
      required this.scope,
      required this.source,
      required this.onScopeChanged,
      required this.onSourceChanged,
      this.metadata});
  final CorpusScope scope;
  final CorpusSource? source;
  final CorpusMetadata? metadata;
  final ValueChanged<CorpusScope> onScopeChanged;
  final ValueChanged<CorpusSource?> onSourceChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<CorpusScope>(
            key: ValueKey(scope),
            initialValue: scope,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: '코퍼스 관측 범위',
                isDense: true,
                border: OutlineInputBorder()),
            items: [
              for (final value in CorpusScope.values)
                DropdownMenuItem(
                    value: value,
                    child: Text(
                        metadata != null && value == CorpusScope.unobserved
                            ? '채택 용례 미관측'
                            : value.label,
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: (value) {
              if (value != null) onScopeChanged(value);
            },
          )),
          const SizedBox(width: 10),
          Expanded(
              child: DropdownButtonFormField<String>(
            key: ValueKey(source),
            initialValue: source?.name ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: '코퍼스 추천 정렬',
                isDense: true,
                border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('기존 검색순')),
              for (final value in CorpusSource.values)
                DropdownMenuItem(
                    value: value.name,
                    child: Text('${value.label} DF순',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => onSourceChanged(value == null || value.isEmpty
                ? null
                : CorpusSource.values.byName(value)),
          )),
        ]),
        const SizedBox(height: 4),
        if (metadata != null)
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(
                'PDF ${metadata!.textbookDocuments}개 · 초록 ${metadata!.abstractDocuments}개 · 문맥 필터 적용',
                style: Theme.of(context).textTheme.bodySmall),
            TextButton(
                onPressed: () => showCorpusMethod(context, metadata!),
                child: const Text('집계 기준')),
          ]),
        Text(
            source == null
                ? '코퍼스 관측 범위는 학습 우선순위와 별개입니다.'
                : '${source!.label}의 DF 내림차순 · 같은 DF는 TF순',
            style: Theme.of(context).textTheme.bodySmall),
      ]));
}
