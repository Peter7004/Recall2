import 'package:flutter/material.dart';
import 'corpus_stats.dart';

class CorpusInfo extends StatelessWidget {
  const CorpusInfo({super.key, required this.catalog, required this.term});
  final CorpusCatalog catalog;
  final String term;
  @override
  Widget build(BuildContext context) {
    if (!catalog.available) return const SizedBox.shrink();
    final stats = catalog.forTerm(term);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('코퍼스 관측 정보', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (stats == null)
          const Text('이 용어의 코퍼스 데이터가 제공되지 않았습니다.')
        else ...[
          Text(stats.observation.label),
          Text('교재·강의자료: TF ${stats.textbookTf} · DF ${stats.textbookDf}'),
          Text('논문 초록: TF ${stats.abstractTf} · DF ${stats.abstractDf}'),
          const SizedBox(height: 4),
          Text('TF: 출현 횟수 · DF: 등장 문서 수',
              style: Theme.of(context).textTheme.bodySmall),
        ],
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
      required this.onSourceChanged});
  final CorpusScope scope;
  final CorpusSource? source;
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
                    child: Text(value.label, overflow: TextOverflow.ellipsis))
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
        Text(
            source == null
                ? '코퍼스 관측 범위는 학습 우선순위와 별개입니다.'
                : '${source!.label}의 DF 내림차순 · 같은 DF는 TF순',
            style: Theme.of(context).textTheme.bodySmall),
      ]));
}
