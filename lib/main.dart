import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recall/recall_store.dart';

void main() {
  runApp(const RecallApp());
}

const _ink = Color(0xFF070235);
const _indigo = Color(0xFF3947DD);
const _muted = Color(0xFF666570);
const _surface = Color(0xFFFBF8FE);
const _soft = Color(0xFFF3F0F6);
const _line = Color(0xFFE9E6ED);

class RecallApp extends StatelessWidget {
  const RecallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lexicon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _indigo,
          primary: _ink,
          secondary: _indigo,
          surface: _surface,
        ),
        fontFamily: 'sans-serif',
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  RecallStore? _store;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final store = await RecallStore.load();
    if (!mounted) {
      store.dispose();
      return;
    }
    setState(() => _store = store);
    if (!store.tutorialCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorial(store);
      });
    }
  }

  static const _destinations = [
    (label: 'Home', icon: Icons.cottage_outlined),
    (label: 'Review', icon: Icons.style_outlined),
    (label: 'Vocab', icon: Icons.menu_book_outlined),
    (label: 'Bookmarks', icon: Icons.bookmark_outline_rounded),
  ];

  void _showTutorial(RecallStore store) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _TutorialDialog(
        onComplete: () async {
          await store.completeTutorial();
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _showAddDeck() {
    final store = _store!;
    showDialog<void>(
      context: context,
      builder: (context) => _EntryDialog(
        title: 'Create a deck',
        label: 'Deck name',
        action: 'Create deck',
        onSubmit: store.createDeck,
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _SettingsPage(store: _store!)),
    );
  }

  void _showHomeActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Create a deck'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddDeck();
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Import CSV'),
                subtitle: const Text('Add words, meanings, and examples'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCsvImport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCsvImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV 파일을 읽을 수 없습니다.')),
        );
        return;
      }

      final csvText = const Utf8Decoder().convert(bytes);
      final fileStem = file.name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
      final title = fileStem.isEmpty ? 'Imported deck' : fileStem;
      final importedCount = await _store!.importCsvDeck(
        deckName: title,
        csvText: csvText,
      );

      if (!mounted) return;
      if (importedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV에서 카드 정보를 찾지 못했습니다.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importedCount개의 카드가 “$title” 덱에 추가되었습니다.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV를 불러오지 못했습니다: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => _buildApp(context, store),
    );
  }

  Widget _buildApp(BuildContext context, RecallStore store) {
    final isHome = _selectedIndex == 0;
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
                onSearch: () => showSearch<void>(
                      context: context,
                      delegate: _VocabularySearch(),
                    ),
                onSettings: _openSettings),
            Expanded(
              child: isHome
                  ? _HomePage(
                      store: store,
                      onOpenDeck: _openDeck,
                      onStartReview: _startReview,
                      onImportCsv: _showCsvImport,
                      onCreateDeck: _showAddDeck,
                    )
                  : _selectedIndex == 3
                      ? _BookmarkedPage(
                          store: store,
                          onEditCard: _openCardEditor,
                        )
                      : _DestinationPage(
                          title: _destinations[_selectedIndex].label,
                          icon: _destinations[_selectedIndex].icon,
                          onStartReview: _startReview,
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHomeActions,
        tooltip: 'Create or import a deck',
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        dueCount: store.remainingToday,
        destinations: _destinations,
        onSelect: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  void _startReview() {
    final store = _store!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReviewPage(store: store)),
    );
  }

  void _openDeck(String deckId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DeckDetailPage(store: _store!, deckId: deckId),
      ),
    );
  }

  void _openCardEditor(String deckId, [RecallCard? card]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CardEditorPage(
          store: _store!,
          deckId: deckId,
          card: card,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearch, required this.onSettings});

  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.96),
        border: const Border(bottom: BorderSide(color: _line, width: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 9),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lexicon',
                  style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.1)),
              SizedBox(height: 2),
              Text('HOME',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onSearch,
            tooltip: 'Search vocabulary',
            icon: const Icon(Icons.search_rounded),
            color: _muted,
          ),
          IconButton(
            onPressed: onSettings,
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            color: _muted,
          ),
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 16,
            backgroundColor: _ink,
            child: Icon(Icons.person_outline, color: Colors.white, size: 19),
          ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.store,
    required this.onOpenDeck,
    required this.onStartReview,
    required this.onImportCsv,
    required this.onCreateDeck,
  });

  final RecallStore store;
  final ValueChanged<String> onOpenDeck;
  final VoidCallback onStartReview;
  final Future<void> Function() onImportCsv;
  final VoidCallback onCreateDeck;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            constraints.maxWidth > 680 ? 620.0 : double.infinity;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
              children: [
                _Greeting(dailyGoal: store.dailyGoal),
                const SizedBox(height: 20),
                const _HomeSectionHeading('Today'),
                const SizedBox(height: 10),
                _ReviewSummary(
                  store: store,
                  onStartReview: onStartReview,
                  onImportCsv: onImportCsv,
                  onCreateDeck: onCreateDeck,
                ),
                const SizedBox(height: 22),
                _DeckSection(store: store, onOpenDeck: onOpenDeck),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.dailyGoal});

  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _StatusDot(),
            SizedBox(width: 7),
            Text('RECALL',
                style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('오늘의 학습',
            style: TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                height: 1.15)),
        const SizedBox(height: 5),
        Text('하루 목표: $dailyGoal개 카드',
            style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: _indigo, shape: BoxShape.circle),
      );
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.store,
    required this.onStartReview,
    required this.onImportCsv,
    required this.onCreateDeck,
  });

  final RecallStore store;
  final VoidCallback onStartReview;
  final Future<void> Function() onImportCsv;
  final VoidCallback onCreateDeck;

  @override
  Widget build(BuildContext context) {
    final remaining = store.remainingToday;
    final goal = store.dailyGoal;
    final completed = store.reviewsToday;

    if (store.decks.isEmpty || remaining <= 0) {
      return _Panel(
        padding: const EdgeInsets.all(18),
        child: _EmptyReviewState(
          title: store.decks.isEmpty ? '현재 덱이 없습니다' : '현재 학습할 카드가 없습니다',
          onImportCsv: onImportCsv,
          onCreateDeck: onCreateDeck,
        ),
      );
    }

    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Eyebrow('READY FOR RECALL'),
                    const SizedBox(height: 2),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$remaining',
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 36,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          const Text('장 남음',
                              style: TextStyle(color: _muted, fontSize: 15))
                        ]),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: _soft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.psychology_alt_outlined,
                    color: _ink, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            '${store.dueCount}장의 카드가 ${store.decks.length}개 덱에 남아 있습니다.',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오늘의 학습 목표',
                  style: TextStyle(color: _muted, fontSize: 11)),
              Text('$completed / $goal 완료',
                  style: const TextStyle(
                      color: _ink, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (completed / goal).clamp(0.0, 1.0),
              minHeight: 7,
              color: _ink,
              backgroundColor: _line,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onStartReview,
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Row(
                children: [
                  Text('카드 리뷰하기',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 19),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState({
    required this.title,
    required this.onImportCsv,
    required this.onCreateDeck,
  });

  final String title;
  final Future<void> Function() onImportCsv;
  final VoidCallback onCreateDeck;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('NO CARDS READY'),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'CSV 파일로 덱을 만들거나 새 덱을 추가해 학습을 시작해 보세요.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onImportCsv(),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('파일 가져오기'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onCreateDeck,
                icon: const Icon(Icons.add),
                label: const Text('새 덱 만들기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeckSection extends StatelessWidget {
  const _DeckSection({required this.store, required this.onOpenDeck});

  final RecallStore store;
  final ValueChanged<String> onOpenDeck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _HomeSectionHeading('Your decks'),
        const SizedBox(height: 10),
        if (store.decks.isEmpty)
          const _EmptyDecks()
        else
          for (final deck in store.decks) ...[
            if (deck != store.decks.first) const SizedBox(height: 8),
            _DeckTile(
              title: deck.name,
              count: '${deck.cards.length} cards',
              due: '${deck.cards.length} to study',
              icon: Icons.folder_outlined,
              progress: 0,
              onTap: () => onOpenDeck(deck.id),
            ),
          ],
      ],
    );
  }
}

class _EmptyDecks extends StatelessWidget {
  const _EmptyDecks();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.folder_open_outlined, color: _muted, size: 25),
            SizedBox(height: 8),
            Text('No decks yet',
                style: TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Use + to create a deck and add your first cards.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );
}

class _DeckTile extends StatelessWidget {
  const _DeckTile(
      {required this.title,
      required this.count,
      required this.due,
      required this.icon,
      required this.progress,
      required this.onTap});

  final String title;
  final String count;
  final String due;
  final IconData icon;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: _soft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: _ink, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(count,
                          style: const TextStyle(color: _muted, fontSize: 10)),
                      const SizedBox(width: 7),
                      const Icon(Icons.circle, color: _line, size: 4),
                      const SizedBox(width: 7),
                      Text(due,
                          style: const TextStyle(
                              color: _indigo,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: _line,
                        color: _indigo),
                    const Icon(Icons.chevron_right_rounded,
                        size: 17, color: _muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _muted,
          fontSize: 9,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A070235), blurRadius: 18, offset: Offset(0, 3))
          ],
        ),
        child: child,
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav(
      {required this.selectedIndex,
      required this.dueCount,
      required this.destinations,
      required this.onSelect});

  final int selectedIndex;
  final int dueCount;
  final List<({String label, IconData icon})> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: _line, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              final selected = selectedIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelect(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 25,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(destination.icon,
                                color: selected ? _indigo : _muted, size: 22),
                            if (index == 1)
                              Positioned(
                                right: -13,
                                top: -5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _indigo,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text('$dueCount',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(destination.label,
                          style: TextStyle(
                              color: selected ? _indigo : _muted,
                              fontSize: 9,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.store});

  final RecallStore store;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _revealed = false;
  bool _reverse = false;
  int _index = 0;
  late final List<({RecallDeck deck, RecallCard card})> _queue =
      widget.store.dueCards.take(widget.store.remainingToday).toList();

  ({RecallDeck deck, RecallCard card})? get _current =>
      _index < _queue.length ? _queue[_index] : null;

  void _toggleOrientation() => setState(() => _reverse = !_reverse);

  Future<void> _advance() async {
    final current = _current;
    if (current == null) return;
    await widget.store.markReviewed(current.card.id);
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  void _repeatCurrent() => setState(() => _revealed = false);

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) {
      final message =
          widget.store.decks.isEmpty ? '현재 덱이 없습니다.' : '현재 학습할 카드가 없습니다.';
      return Scaffold(
        appBar: AppBar(title: const Text('Review'), backgroundColor: _surface),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.file_download_off_rounded,
                    color: _indigo, size: 42),
                const SizedBox(height: 12),
                Text(message,
                    style: const TextStyle(color: _ink, fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final promptText = _reverse ? current.card.meaning : current.card.front;
    final answerText = _reverse ? current.card.front : current.card.meaning;
    final promptLabel = _reverse ? '뒷면' : '앞면';
    final answerLabel = _reverse ? '앞면' : '뒷면';

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        leading: IconButton(
            tooltip: 'Go back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Review',
            style: TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _toggleOrientation,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(_reverse ? '전환 학습' : '기본 학습'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > 680 ? 620.0 : double.infinity;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    _SessionRail(
                      completed: widget.store.reviewsToday,
                      total: widget.store.dailyGoal,
                      deckName: current.deck.name,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: _Flashcard(
                          revealed: _revealed,
                          imageData: current.card.imageData,
                          promptText: promptText,
                          answerText: answerText,
                          promptLabel: promptLabel,
                          answerLabel: answerLabel,
                          onReveal: () =>
                              setState(() => _revealed = !_revealed),
                        ),
                      ),
                    ),
                    _FeedbackDock(
                      revealed: _revealed,
                      onRepeat: _repeatCurrent,
                      onNext: _advance,
                      onReveal: () => setState(() => _revealed = true),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionRail extends StatelessWidget {
  const _SessionRail({
    required this.completed,
    required this.total,
    required this.deckName,
  });

  final int completed;
  final int total;
  final String deckName;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(children: [
          Row(children: [
            IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                tooltip: 'Exit session',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, size: 18)),
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: _soft, borderRadius: BorderRadius.circular(4)),
                child: Text(deckName,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600))),
            const Spacer(),
            Text('$completed',
                style: const TextStyle(
                    color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(' / $total',
                style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(width: 13),
            const Icon(Icons.circle, size: 7, color: _indigo),
            const SizedBox(width: 5),
            const Text('FLASHCARDS',
                style: TextStyle(
                    color: _indigo, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: (completed / total).clamp(0.0, 1.0),
                  minHeight: 4,
                  color: _ink,
                  backgroundColor: _line)),
        ]),
      );
}

class _Flashcard extends StatelessWidget {
  const _Flashcard({
    required this.revealed,
    required this.imageData,
    required this.promptText,
    required this.answerText,
    required this.promptLabel,
    required this.answerLabel,
    required this.onReveal,
  });

  final bool revealed;
  final String? imageData;
  final String promptText;
  final String answerText;
  final String promptLabel;
  final String answerLabel;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onReveal,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 156,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                    Color(0xFF283644),
                    Color(0xFF101A28),
                    Color(0xFF69533C)
                  ])),
              child: Stack(children: [
                Positioned(
                    right: -14,
                    top: -42,
                    child: Icon(Icons.auto_stories_rounded,
                        size: 205,
                        color: Colors.white.withValues(alpha: 0.07))),
                const Positioned(
                    left: 24,
                    top: 15,
                    child: Icon(Icons.auto_stories_rounded,
                        size: 92, color: Color(0xFFC4A477))),
                Positioned(
                    left: 17,
                    right: 17,
                    bottom: 12,
                    child: Row(children: [
                      Expanded(
                          child: Text(promptLabel.toUpperCase(),
                            style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w600))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          color: _ink.withValues(alpha: 0.62),
                          child: const Text('FLASHCARD',
                              style: TextStyle(
                                  color: Color(0xFFE3DFFF),
                                  fontSize: 9,
                                  letterSpacing: 0.5)))
                    ])),
              ]),
            ),
            if (imageData != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _CardImage(
                  imageData: imageData,
                  width: double.infinity,
                  height: 190,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(promptLabel.toUpperCase(),
                                  style: const TextStyle(
                                        color: _indigo,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(promptText,
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 32,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700))
                              ])),
                          IconButton.filledTonal(
                              tooltip: 'Flip card',
                              onPressed: onReveal,
                              icon: const Icon(Icons.flip_to_back_rounded)),
                        ]),
                    const SizedBox(height: 9),
                    const SizedBox(height: 17),
                    if (!revealed)
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                              color: _soft.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(9)),
                          child: const Column(children: [
                            Icon(Icons.touch_app_rounded,
                                color: _indigo, size: 23),
                            SizedBox(height: 5),
                            Text('답을 확인해 보세요',
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 4),
                            Text('카드를 눌러 뒤집기',
                                style: TextStyle(
                                    color: _muted,
                                    fontSize: 9,
                                    letterSpacing: 0.8))
                          ]))
                    else ...[
                      _AnswerPanel(label: answerLabel, text: answerText),
                    ],
                  ]),
            ),
          ]),
        ),
      );
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(9)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(text,
              style: const TextStyle(color: _ink, fontSize: 14, height: 1.45))
        ]),
      );
}

class _FeedbackDock extends StatelessWidget {
  const _FeedbackDock({
    required this.revealed,
    required this.onRepeat,
    required this.onNext,
    required this.onReveal,
  });

  final bool revealed;
  final VoidCallback onRepeat;
  final VoidCallback onNext;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: const BoxDecoration(
            color: _surface, border: Border(top: BorderSide(color: _line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(
              child: Text('FLASHCARD CONTROL',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600)),
            ),
            Text(revealed ? '답 확인 완료' : '답을 보기',
                style: const TextStyle(color: _muted, fontSize: 9))
          ]),
          const SizedBox(height: 8),
          if (!revealed)
            SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                    onPressed: onReveal,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('답 보기'),
                    style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)))))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRepeat,
                    child: const Text('다시 보기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Text('다음 카드'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 7),
          const Text('앞면과 뒷면을 바꿔서 학습할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 9)),
        ]),
      );
}

class _DeckDetailPage extends StatelessWidget {
  const _DeckDetailPage({required this.store, required this.deckId});

  final RecallStore store;
  final String deckId;

  void _editCard(BuildContext context, RecallDeck deck, [RecallCard? card]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CardEditorPage(
          store: store,
          deckId: deck.id,
          card: card,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final deck = store.deckById(deckId);
          if (deck == null) {
            return const Scaffold(
              body: Center(child: Text('This deck is no longer available.')),
            );
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: _surface,
              title: Text(deck.name),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    constraints.maxWidth > 680 ? 620.0 : double.infinity;
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: deck.cards.isEmpty
                        ? const _EmptyCards()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                            itemCount: deck.cards.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final card = deck.cards[index];
                              return _Panel(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  leading: _CardImage(
                                    imageData: card.imageData,
                                    width: 52,
                                    height: 52,
                                  ),
                                  title: Text(card.front),
                                  subtitle: Text(
                                    '${card.meaning}\n${card.example}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: card.example.isNotEmpty,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: card.isBookmarked
                                            ? 'Remove bookmark'
                                            : 'Bookmark card',
                                        onPressed: () =>
                                            store.toggleBookmark(card.id),
                                        icon: Icon(
                                          card.isBookmarked
                                              ? Icons.bookmark_rounded
                                              : Icons.bookmark_outline_rounded,
                                          color: card.isBookmarked
                                              ? _indigo
                                              : _muted,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit card',
                                        onPressed: () =>
                                            _editCard(context, deck, card),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _editCard(context, deck, card),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _editCard(context, deck),
              icon: const Icon(Icons.add),
              label: const Text('Add card'),
            ),
          );
        },
      );
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 34, color: _muted),
              SizedBox(height: 12),
              Text('No cards in this deck yet',
                  style: TextStyle(
                      color: _ink, fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 5),
              Text('Add a card with the button below.',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _BookmarkedPage extends StatelessWidget {
  const _BookmarkedPage({
    required this.store,
    required this.onEditCard,
  });

  final RecallStore store;
  final void Function(String, [RecallCard?]) onEditCard;

  @override
  Widget build(BuildContext context) {
    final cards = store.bookmarkedCards;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 620,
        child: cards.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border_rounded,
                        color: _muted, size: 36),
                    SizedBox(height: 12),
                    Text('저장한 카드가 없습니다',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('덱에서 책갈피 아이콘을 눌러 카드를 저장하세요.',
                        style: TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: cards.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: _HomeSectionHeading('북마크한 카드'),
                    );
                  }
                  final entry = cards[index - 1];
                  return _Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: _CardImage(
                        imageData: entry.card.imageData,
                        width: 52,
                        height: 52,
                      ),
                      title: Text(entry.card.front),
                      subtitle: Text(
                        '${entry.card.meaning} · ${entry.deck.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onEditCard(entry.deck.id, entry.card),
                      trailing: IconButton(
                        tooltip: 'Remove bookmark',
                        onPressed: () => store.toggleBookmark(entry.card.id),
                        icon:
                            const Icon(Icons.bookmark_rounded, color: _indigo),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.imageData,
    required this.width,
    required this.height,
    this.emptyLabel,
  });

  final String? imageData;
  final double width;
  final double height;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          height: height,
          child: imageData == null
              ? Container(
                  color: _soft,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: _muted, size: 30),
                      if (emptyLabel != null) ...[
                        const SizedBox(height: 8),
                        Text(emptyLabel!,
                            style:
                                const TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ],
                  ),
                )
              : Image.memory(
                  base64Decode(imageData!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: _soft,
                    child: Icon(Icons.broken_image_outlined, color: _muted),
                  ),
                ),
        ),
      );
}

class _CardEditorPage extends StatefulWidget {
  const _CardEditorPage({
    required this.store,
    required this.deckId,
    this.card,
  });

  final RecallStore store;
  final String deckId;
  final RecallCard? card;

  @override
  State<_CardEditorPage> createState() => _CardEditorPageState();
}

class _CardEditorPageState extends State<_CardEditorPage> {
  late final TextEditingController _frontController;
  late final TextEditingController _meaningController;
  final _imagePicker = ImagePicker();
  String? _imageData;
  bool _saving = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card?.front ?? '');
    _meaningController =
        TextEditingController(text: widget.card?.meaning ?? '');
    _imageData = widget.card?.imageData;
  }

  @override
  void dispose() {
    _frontController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.store.deckById(widget.deckId);
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(widget.card == null ? '새 플래시카드' : '카드 편집'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('저장'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth > 860 ? 860 : constraints.maxWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Text(deck?.name ?? '',
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('이미지와 단어를 연결해 기억해 보세요',
                    style: TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                _CardImage(
                  imageData: _imageData,
                  width: double.infinity,
                  height: 280,
                  emptyLabel: '연상에 사용할 사진을 추가하세요',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickingImage
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('사진 촬영'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickingImage
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('사진 업로드'),
                    ),
                    if (_imageData != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _imageData = null),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('사진 제거'),
                      ),
                  ],
                ),
                if (_pickingImage) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 28),
                TextField(
                  controller: _frontController,
                  autofocus: widget.card == null,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: '앞면',
                    hintText: '예: apple',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _meaningController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: '뒷면',
                    hintText: '예: 사과',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _imageData = base64Encode(bytes));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진을 불러오지 못했습니다: $error')),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    final front = _frontController.text.trim();
    final meaning = _meaningController.text.trim();
    if (front.isEmpty || meaning.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앞면과 뒷면을 모두 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    if (widget.card == null) {
      await widget.store.addCard(
        deckId: widget.deckId,
        front: front,
        meaning: meaning,
        example: '',
        imageData: _imageData,
      );
    } else {
      await widget.store.updateCard(
        deckId: widget.deckId,
        cardId: widget.card!.id,
        front: front,
        meaning: meaning,
        example: widget.card!.example,
        imageData: _imageData ?? '',
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _step = 0;

  static const _steps = [
    (
      icon: Icons.folder_open_outlined,
      title: '덱부터 시작해요',
      body: '학습 주제별로 덱을 만들고, 직접 카드를 추가하거나 CSV를 가져올 수 있어요.',
    ),
    (
      icon: Icons.flip_rounded,
      title: '양쪽 방향으로 학습해요',
      body: '앞면을 보고 답을 확인한 뒤, 상단 전환 버튼으로 뒷면부터 떠올리는 연습도 해보세요.',
    ),
    (
      icon: Icons.add_a_photo_outlined,
      title: '사진과 북마크를 활용해요',
      body: '카드에 사진을 찍거나 업로드해 단어와 연결하고, 기억할 카드는 책갈피로 모아보세요.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;
    return AlertDialog(
      icon: Icon(step.icon, color: _indigo, size: 34),
      title: Text(step.title, textAlign: TextAlign.center),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(step.body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _step ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _step ? _indigo : _line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('이전'),
          )
        else
          const SizedBox(width: 48),
        FilledButton(
          onPressed: isLast ? widget.onComplete : () => setState(() => _step++),
          child: Text(isLast ? '시작하기' : '다음'),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.store});

  final RecallStore store;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late double _dailyGoal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dailyGoal = widget.store.dailyGoal.toDouble();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('Settings'), backgroundColor: _surface),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _HomeSectionHeading('Daily study'),
                const SizedBox(height: 8),
                const Text(
                  'Choose the maximum number of cards to study each day.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_dailyGoal.round()} cards per day',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Slider(
                        value: _dailyGoal,
                        min: 1,
                        max: 200,
                        divisions: 199,
                        label: _dailyGoal.round().toString(),
                        onChanged: (value) =>
                            setState(() => _dailyGoal = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save settings'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.store.setDailyGoal(_dailyGoal.round());
    if (mounted) Navigator.pop(context);
  }
}

class _DestinationPage extends StatelessWidget {
  const _DestinationPage(
      {required this.title, required this.icon, required this.onStartReview});

  final String title;
  final IconData icon;
  final VoidCallback onStartReview;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: _indigo),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: _ink, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Your learning data will appear here.',
                style: TextStyle(color: _muted, fontSize: 13)),
            if (title == 'Review') ...[
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onStartReview, child: const Text('Start review')),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog(
      {required this.title,
      required this.label,
      required this.action,
      required this.onSubmit});

  final String title;
  final String label;
  final String action;
  final ValueChanged<String> onSubmit;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
            labelText: widget.label, border: const OutlineInputBorder()),
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => _submit(context), child: Text(widget.action)),
      ],
    );
  }

  void _submit(BuildContext context) {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context);
    widget.onSubmit(value);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('“$value” added')));
  }
}

class _VocabularySearch extends SearchDelegate<void> {
  @override
  String get searchFieldLabel => 'Search vocabulary';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _searchResult();

  @override
  Widget buildSuggestions(BuildContext context) => _searchResult();

  Widget _searchResult() {
    final matches = ['Apocryphal', 'Ephemeral', 'Ubiquitous']
        .where((word) => word.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (query.isEmpty) {
      return const Center(child: Text('Search your saved words'));
    }
    if (matches.isEmpty) {
      return const Center(child: Text('No matching vocabulary'));
    }
    return ListView(
      children: matches
          .map((word) => ListTile(
              leading: const Icon(Icons.menu_book_outlined), title: Text(word)))
          .toList(),
    );
  }
}
