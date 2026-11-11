import 'package:flutter/material.dart';
import 'corpus_stats.dart';

void showCorpusMethod(BuildContext context, CorpusMetadata metadata) {
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('빈도 집계 기준'),
            content: SingleChildScrollView(
                child: Text('${metadata.date} 재집계\n\n'
                    'PDF ${metadata.textbookDocuments}개 파일과 논문 초록 ${metadata.abstractDocuments}개를 분석했습니다. 논문 전체 본문 빈도가 아닙니다.\n\n'
                    '전공 문맥을 자동 판정한 잠정 채택값입니다. 의미가 불확실한 용례는 보류로 분리하며 빈도와 추천 정렬에 포함하지 않습니다. 채택값 0은 실제 출현이 없다는 뜻이 아닙니다.\n\n'
                    'PDF는 책 수가 아닌 파일 수이며 전체 교재와 장별 파일의 내용이 겹칠 수 있습니다. 초록은 최종 인적 검토 전 후보 자료입니다.\n\n'
                    'TF는 등장 횟수, DF는 등장한 파일·초록 수입니다. 채택 DF와 보류 DF는 같은 문서를 포함할 수 있어 합산하지 않습니다.')),
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
          const Text('전공 문맥 자동 판정 · 잠정 채택값'),
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
                'PDF ${metadata!.textbookDocuments}개 · 초록 ${metadata!.abstractDocuments}개 · 잠정값',
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
