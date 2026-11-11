part of '../main.dart';

// Presentation only: all vocabulary and progress remain owned by RecallStore.
class _DashboardPage extends StatelessWidget {
  const _DashboardPage(
      {required this.store,
      required this.onStudy,
      required this.onSearch,
      required this.onSubjects,
      required this.onCollections,
      required this.onBookmarks,
      required this.onReader,
      required this.onTerm,
      required this.onCategory});
  final RecallStore store;
  final VoidCallback onStudy, onSubjects, onCollections, onBookmarks, onReader;
  final ValueChanged<String> onSearch, onCategory;
  final void Function(String, RecallCard) onTerm;

  @override
  Widget build(BuildContext context) {
    final entries = store.allCards;
    final day = DateTime.now().difference(DateTime(2020)).inDays;
    final suggestion = entries.isEmpty ? null : entries[day % entries.length];
    return _DashboardScroll(children: [
      const _PageHeading('오늘의 전공 영어', '매일 조금씩, 확실하게 기억하세요.'),
      _Panel(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Expanded(child: _HomeSectionHeading('오늘의 목표')),
              Icon(Icons.flag_outlined, color: _indigo, size: 30)
            ]),
            const SizedBox(height: 22),
            Text('${store.reviewsToday} / ${store.dailyGoal}회',
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 18),
            _GoalProgress(store: store),
            const SizedBox(height: 20),
            Row(children: [
              _DashboardCount('${store.totalCards}', '전체 단어'),
              _DashboardCount('${store.bookmarkedCards.length}', '북마크'),
              _DashboardCount('${store.remainingToday}', '남은 목표'),
            ]),
            const SizedBox(height: 22),
            FilledButton.icon(
                onPressed: store.dueCount == 0 ? null : onStudy,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('오늘 학습 시작하기')),
          ])),
      const SizedBox(height: 28),
      const _HomeSectionHeading('빠른 단어 검색'),
      const SizedBox(height: 12),
      TextField(
          onSubmitted: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
              hintText: '영어 또는 한국어 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  tooltip: '사전 열기',
                  onPressed: () => onSearch(''),
                  icon: const Icon(Icons.arrow_forward)))),
      const SizedBox(height: 28),
      Row(children: [
        const Expanded(child: _HomeSectionHeading('분야별 학습')),
        TextButton(onPressed: onSubjects, child: const Text('과목 관리'))
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final category
            in store.categories.where((c) => c.parentId == null))
          ActionChip(
              label: Text(category.name),
              onPressed: () => onCategory(category.id)),
        if (store.categories.isEmpty) const Text('과목을 추가해 학습 분야를 정리하세요.'),
      ]),
      const SizedBox(height: 24),
      if (suggestion != null)
        _Panel(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('오늘의 추천 단어',
                  style:
                      TextStyle(color: _indigo, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(suggestion.card.displayTerm,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 8),
              Text(suggestion.card.primaryMeaning),
              TextButton(
                  onPressed: () => onTerm(suggestion.deck.id, suggestion.card),
                  child: const Text('뜻과 설명 보기 →')),
            ])),
      const SizedBox(height: 24),
      _Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
                leading:
                    const Icon(Icons.picture_as_pdf_outlined, color: _indigo),
                title: const Text('Recall Reader'),
                subtitle: const Text('PDF 읽기 · 단어 저장 · 원문 복귀'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onReader),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.folder_open_outlined, color: _indigo),
                title: const Text('단어 모음 관리'),
                subtitle: const Text('CSV 가져오기와 모음 편집'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onCollections),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.bookmark_outline, color: _indigo),
                title: const Text('북마크 단어'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onBookmarks),
          ])),
    ]);
  }
}

class _RecordsPage extends StatelessWidget {
  const _RecordsPage({required this.store, required this.onTerm});
  final RecallStore store;
  final void Function(String, RecallCard) onTerm;
  @override
  Widget build(BuildContext context) {
    final learned =
        store.allCards.where((e) => e.card.lastReviewed != null).length;
    final percent =
        (100 * store.reviewsToday / store.dailyGoal).clamp(0, 100).round();
    return _DashboardScroll(children: [
      const _PageHeading('학습 기록', '매일의 작은 성장을 한눈에 확인하세요.'),
      LayoutBuilder(
          builder: (context, constraints) =>
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final metric in [
                  (Icons.check, '${store.reviewsToday}', '오늘 학습 횟수'),
                  (Icons.auto_stories_outlined, '$learned', '학습한 단어'),
                  (
                    Icons.bookmark_outline,
                    '${store.bookmarkedCards.length}',
                    '북마크 단어'
                  ),
                  (Icons.track_changes, '$percent%', '오늘 목표 달성률'),
                ])
                  SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _Panel(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(metric.$1, color: _indigo),
                                const SizedBox(height: 14),
                                Text(metric.$2,
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: _ink)),
                                const SizedBox(height: 6),
                                Text(metric.$3,
                                    style: const TextStyle(color: _muted)),
                              ]))),
              ])),
      const SizedBox(height: 28),
      const _HomeSectionHeading('학습 기록 안내'),
      const SizedBox(height: 12),
      const _Panel(
          child: Text(
              '오늘 학습 횟수는 같은 단어를 다시 학습한 횟수도 포함합니다. '
              '현재 저장 데이터에는 날짜별 전체 이력이 없어 최근 7일 그래프는 표시하지 않습니다.',
              style: TextStyle(color: _muted, height: 1.7))),
      const SizedBox(height: 28),
      Row(children: [
        const Expanded(child: _HomeSectionHeading('저장한 단어')),
        Text('${store.bookmarkedCards.length}개',
            style: const TextStyle(color: _muted))
      ]),
      const SizedBox(height: 12),
      if (store.bookmarkedCards.isEmpty)
        const _Panel(
            padding: EdgeInsets.all(32),
            child: Column(children: [
              Icon(Icons.bookmark_outline, color: _muted, size: 40),
              SizedBox(height: 16),
              Text('아직 저장한 단어가 없어요.', style: TextStyle(color: _muted)),
            ]))
      else
        for (final entry in store.bookmarkedCards)
          _VocabularyTile(
              store: store,
              card: entry.card,
              onTap: () => onTerm(entry.deck.id, entry.card)),
    ]);
  }
}

class _DashboardScroll extends StatelessWidget {
  const _DashboardScroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              children: children)));
}

class _PageHeading extends StatelessWidget {
  const _PageHeading(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 10),
        Text(subtitle, style: const TextStyle(color: _muted, height: 1.6)),
      ]));
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.store});
  final RecallStore store;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
      value: (store.reviewsToday / store.dailyGoal).clamp(0, 1),
      minHeight: 8,
      borderRadius: BorderRadius.circular(8),
      backgroundColor: _soft,
      color: _indigo,
      semanticsLabel: '오늘 목표 진행률');
}

class _DashboardCount extends StatelessWidget {
  const _DashboardCount(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
      ]));
}
