import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:recall/branding.dart';
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
typedef StudyCards = List<({RecallDeck deck, RecallCard card})>;
typedef TermDetailValue = ({String label, String value});

class RecallApp extends StatelessWidget {
  const RecallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recall',
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
  const HomeShell({super.key, this.loadStore});
  final Future<RecallStore> Function()? loadStore;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  String _dictionaryQuery = '';
  String? _dictionaryCategoryId;
  RecallStore? _store;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    RecallStore store;
    try {
      store = await (widget.loadStore?.call() ?? RecallStore.load());
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
      return;
    }
    if (!mounted) {
      store.dispose();
      return;
    }
    setState(() => _store = store);
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  static const _destinations = [
    (label: '사전', icon: Icons.menu_book_outlined),
    (label: '과목', icon: Icons.school_outlined),
    (label: '북마크', icon: Icons.bookmark_outline_rounded),
    (label: '플래시카드', icon: Icons.style_outlined),
    (label: '모음', icon: Icons.folder_open_outlined),
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

  void _openDictionary({String query = '', String? categoryId}) {
    setState(() {
      _selectedIndex = 0;
      _dictionaryQuery = query;
      _dictionaryCategoryId = categoryId;
    });
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
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('새 용어'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _CardEditorPage(store: _store!, deckId: ''),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('학습 안내'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTutorial(_store!);
                },
              ),
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
      final preview = _store!.previewCsvImportDetailed(csvText);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('CSV 미리보기'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$title · ${preview.entryCount}개 용어'),
                  Text(
                      '새 항목 ${preview.newEntryCount}개 · 기존 항목 ${preview.existingEntryCount}개'),
                  if (preview.duplicateCount > 0)
                    Text('동일 용어 ${preview.duplicateCount}개 행은 의미와 과목을 병합합니다.'),
                  if (preview.unknownHeaders.isNotEmpty)
                    Text('추가 정보로 보존할 열: ${preview.unknownHeaders.join(', ')}'),
                  const Divider(),
                  for (final row in preview.rows.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.card.displayTerm),
                      subtitle: Text(
                          '${row.card.primaryMeaning} · ${row.card.vocabularyType.label}'),
                    ),
                  for (final error in preview.errors.take(10))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  if (preview.errors.length > 10)
                    Text('외 ${preview.errors.length - 10}개 오류'),
                  if (preview.entryCount == 0) const Text('가져올 수 있는 용어가 없습니다.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: preview.entryCount == 0
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('가져오기'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;

      final report = await _store!.importCsvDeckDetailed(
        deckName: title,
        csvText: csvText,
      );

      if (!mounted) return;
      if (report.linkedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report.invalidRowCount == 0
                ? 'CSV에서 용어와 정의를 찾지 못했습니다.'
                : '가져온 용어가 없습니다. 필수 항목이 없는 행 '
                    '${report.invalidRowCount}개를 확인해 주세요.'),
          ),
        );
        return;
      }

      final notes = [
        if (report.duplicateCount > 0) '동일 용어 ${report.duplicateCount}개 행 병합',
        if (report.invalidRowCount > 0) '잘못된 행 ${report.invalidRowCount}개 제외',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '새 항목 ${report.importedCount}개, 용어 ${report.linkedCount}개를 “$title” 모음에 연결했습니다.'
            '${notes.isEmpty ? '' : ' (${notes.join(', ')})'}',
          ),
        ),
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
      if (_loadError == null) {
        return const Scaffold(body: RecallLoadingScreen(animate: !kIsWeb));
      }
      return Scaffold(
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('저장 데이터를 불러오지 못했습니다. 기존 저장본은 보존됩니다.'),
            const SizedBox(height: 12),
            Text('$_loadError'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _loadError = null);
                _loadStore();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ]),
        )),
      );
    }
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => _buildApp(context, store),
    );
  }

  Widget _buildApp(BuildContext context, RecallStore store) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(onSearch: _openDictionary, onSettings: _openSettings),
            Expanded(
              child: _selectedIndex == 0
                  ? _DictionaryPage(
                      store: store,
                      initialQuery: _dictionaryQuery,
                      initialCategoryId: _dictionaryCategoryId,
                      onOpenTerm: _openTerm,
                      onCategorySelected: (categoryId) =>
                          _openDictionary(categoryId: categoryId),
                    )
                  : _selectedIndex == 1
                      ? _SubjectsPage(
                          store: store, onOpenSubject: _openCategory)
                      : _selectedIndex == 2
                          ? _BookmarkedPage(
                              store: store,
                              onOpenTerm: _openTerm,
                            )
                          : _selectedIndex == 3
                              ? _FlashcardLaunchPage(
                                  store: store,
                                  onStartReview: _startReview,
                                )
                              : _HomePage(
                                  store: store,
                                  onOpenDeck: _openDeck,
                                  onStartReview: _startReview,
                                  onImportCsv: _showCsvImport,
                                  onCreateDeck: _showAddDeck,
                                  onSearch: (q) => _openDictionary(query: q),
                                  onOpenBookmarks: () =>
                                      setState(() => _selectedIndex = 2),
                                  onOpenTerm: _openTerm,
                                  onOpenCategory: _openCategory,
                                ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHomeActions,
        tooltip: '용어·모음 추가',
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

  void _startReview({StudyCards? cards}) {
    final store = _store!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(store: store, initialCards: cards),
      ),
    );
  }

  void _openDeck(String deckId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DeckDetailPage(
          store: _store!,
          deckId: deckId,
          onOpenTerm: _openTerm,
          onCategorySelected: _openCategory,
        ),
      ),
    );
  }

  void _openCategory(String categoryId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _openDictionary(categoryId: categoryId);
  }

  void _openTerm(String deckId, RecallCard card) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DictionaryTermPage(
          store: _store!,
          deckId: deckId,
          cardId: card.id,
          onOpenTerm: _openTerm,
          onCategorySelected: _openCategory,
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line, width: 0.6)),
      ),
      child: Row(
        children: [
          const Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RecallHeaderBrand())),
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
    required this.onSearch,
    required this.onOpenBookmarks,
    required this.onOpenTerm,
    required this.onOpenCategory,
  });
  final RecallStore store;
  final ValueChanged<String> onOpenDeck;
  final VoidCallback onStartReview;
  final Future<void> Function() onImportCsv;
  final VoidCallback onCreateDeck;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenBookmarks;
  final void Function(String, RecallCard) onOpenTerm;
  final ValueChanged<String> onOpenCategory;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              const Text('모음',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton.icon(
                    onPressed: onCreateDeck,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('새 모음')),
                OutlinedButton.icon(
                    onPressed: onImportCsv,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('CSV 가져오기')),
              ]),
              const SizedBox(height: 20),
              _DeckSection(store: store, onOpenDeck: onOpenDeck),
              if (store.recentCards.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _HomeSectionHeading('최근 본 용어'),
                for (final entry in store.recentCards.take(5))
                  _VocabularyTile(
                      store: store,
                      card: entry.card,
                      onTap: () => onOpenTerm(entry.deck.id, entry.card)),
              ],
              const SizedBox(height: 24),
              _ReviewSummary(
                  store: store,
                  onStartReview: onStartReview,
                  onImportCsv: onImportCsv,
                  onCreateDeck: onCreateDeck),
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A070235), blurRadius: 18, offset: Offset(0, 3))
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
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
                            if (index == 3 && dueCount > 0)
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
  const ReviewPage({super.key, required this.store, this.initialCards});

  final RecallStore store;
  final StudyCards? initialCards;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _revealed = false;
  bool _reverse = false;
  int _index = 0;
  late final List<({RecallDeck deck, RecallCard card})> _queue =
      widget.initialCards ??
          widget.store.dueCards.take(widget.store.remainingToday).toList();

  ({RecallDeck deck, RecallCard card})? get _current {
    while (_index < _queue.length &&
        widget.store.cardById(_queue[_index].card.id) == null) {
      _index++;
    }
    if (_index >= _queue.length) return null;
    return (
      deck: _queue[_index].deck,
      card: widget.store.cardById(_queue[_index].card.id)!
    );
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refreshQueue);
  }

  void _refreshQueue() {
    if (mounted) {
      setState(() {
        while (_index < _queue.length &&
            widget.store.cardById(_queue[_index].card.id) == null) {
          _index++;
          _revealed = false;
        }
      });
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refreshQueue);
    super.dispose();
  }

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
    final promptText =
        _reverse ? current.card.reviewAnswer : current.card.displayTerm;
    final answerText =
        _reverse ? current.card.displayTerm : current.card.reviewAnswer;
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
                          example: current.card.example,
                          details: [
                            (
                              label: '학습 우선순위',
                              value: current.card.learningPriority.label
                            ),
                            if (current.card.abbreviation.isNotEmpty)
                              (label: '약어', value: current.card.abbreviation),
                          ],
                          relatedTerms: current.card.relatedTerms,
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
    required this.example,
    required this.details,
    required this.relatedTerms,
    required this.promptText,
    required this.answerText,
    required this.promptLabel,
    required this.answerLabel,
    required this.onReveal,
  });

  final bool revealed;
  final String? imageData;
  final String example;
  final List<TermDetailValue> details;
  final List<String> relatedTerms;
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
                      _AnswerPanel(
                        label: answerLabel,
                        text: answerText,
                        example: example,
                        details: details,
                        relatedTerms: relatedTerms,
                      ),
                    ],
                  ]),
            ),
          ]),
        ),
      );
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({
    required this.label,
    required this.text,
    required this.example,
    required this.details,
    required this.relatedTerms,
  });

  final String label;
  final String text;
  final String example;
  final List<TermDetailValue> details;
  final List<String> relatedTerms;

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
              style: const TextStyle(color: _ink, fontSize: 14, height: 1.45)),
          for (final detail in details) ...[
            const SizedBox(height: 10),
            Text(detail.label,
                style: const TextStyle(
                    color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            SelectableText(detail.value,
                style: const TextStyle(color: _ink, fontSize: 13, height: 1.4)),
          ],
          if (relatedTerms.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('관련 용어',
                style: TextStyle(
                    color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(relatedTerms.join(' · '),
                style: const TextStyle(color: _ink, fontSize: 13)),
          ],
          if (example.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('예문',
                style: TextStyle(
                    color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(example,
                style:
                    const TextStyle(color: _ink, fontSize: 13, height: 1.45)),
          ],
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
                    child: const Text('잊어버림'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Text('기억했어요'),
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

enum _DeckCardAction { toggleReview, delete }

Future<bool> _confirmVocabularyDeletion(
    BuildContext context, RecallStore store, Set<String> ids,
    {RecallDeck? deleteCollection}) async {
  final cards = [
    for (final id in ids)
      if (store.cardById(id) != null) store.cardById(id)!
  ];
  if (cards.isEmpty && deleteCollection == null) return false;
  final affected = store.decks
      .where((d) =>
          d.id != deleteCollection?.id &&
          d.cards.any((c) => ids.contains(c.id)))
      .map((d) => d.name)
      .toList();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
          deleteCollection == null ? '용어 ${cards.length}개 삭제' : '용어 모음 삭제'),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deleteCollection == null
              ? '선택한 용어 ${cards.length}개를 사전에서 영구 삭제합니다.'
              : '“${deleteCollection.name}” 모음과 포함된 용어 ${cards.length}개를 영구 삭제합니다.'),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(cards.take(5).map((c) => c.displayTerm).join(', ') +
                (cards.length > 5 ? ' 외 ${cards.length - 5}개' : '')),
            const SizedBox(height: 12),
            const Text('북마크, 최근 조회 및 해당 용어의 학습 기록도 삭제됩니다.'),
          ],
          if (affected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('다른 모음 ${affected.length}개에서도 해당 용어가 삭제됩니다: '
                '${affected.take(3).join(', ')}${affected.length > 3 ? ' 외 ${affected.length - 3}개' : ''}'),
          ],
          const SizedBox(height: 12),
          const Text('이 작업은 앱에서 되돌릴 수 없습니다.'),
        ],
      )),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('영구 삭제')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    if (deleteCollection == null) {
      await store.deleteEntries(ids);
    } else {
      await store.deleteDeck(deleteCollection.id);
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제하지 못했습니다: $error')));
    }
    return false;
  }
}

class _TermSelectionBar extends StatelessWidget {
  const _TermSelectionBar(
      {required this.count,
      required this.allSelected,
      required this.busy,
      required this.onSelectAll,
      required this.onDelete,
      required this.onClose});
  final int count;
  final bool allSelected;
  final bool busy;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: Row(children: [
        IconButton(
            tooltip: '선택 종료',
            onPressed: busy ? null : onClose,
            icon: const Icon(Icons.close)),
        Expanded(
            child: Text('선택 $count개',
                style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(
            tooltip: allSelected ? '전체 선택 해제' : '전체 선택',
            onPressed: busy ? null : onSelectAll,
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all)),
        IconButton(
            tooltip: '선택한 용어 삭제',
            onPressed: busy || count == 0 ? null : onDelete,
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline)),
      ]));
}

class _DeckDetailPage extends StatefulWidget {
  const _DeckDetailPage({
    required this.store,
    required this.deckId,
    required this.onOpenTerm,
    required this.onCategorySelected,
  });

  final RecallStore store;
  final String deckId;
  final void Function(String, RecallCard) onOpenTerm;
  final ValueChanged<String> onCategorySelected;

  @override
  State<_DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends State<_DeckDetailPage> {
  RecallStore get store => widget.store;
  String get deckId => widget.deckId;
  bool _selecting = false;
  bool _deleting = false;
  final Set<String> _selectedIds = {};

  void _toggleSelected(String id) => setState(() {
        if (!_selectedIds.add(id)) _selectedIds.remove(id);
      });

  Future<void> _deleteSelected() async {
    setState(() => _deleting = true);
    final deleted =
        await _confirmVocabularyDeletion(context, store, Set.of(_selectedIds));
    if (mounted) {
      setState(() {
        _deleting = false;
        if (deleted) {
          _selectedIds.clear();
          _selecting = false;
        }
      });
    }
  }

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

  void _renameDeck(BuildContext context, RecallDeck deck) {
    showDialog<void>(
      context: context,
      builder: (_) => _EntryDialog(
        title: 'Rename deck',
        label: 'Deck name',
        action: 'Save',
        initialValue: deck.name,
        successMessage: 'updated',
        onSubmit: (name) => store.updateDeckName(deck.id, name),
      ),
    );
  }

  Future<void> _confirmDeleteCard(
      BuildContext context, RecallDeck deck, RecallCard card) async {
    await _confirmVocabularyDeletion(context, store, {card.id});
  }

  Future<void> _confirmDeleteDeck(BuildContext context, RecallDeck deck) async {
    setState(() => _deleting = true);
    final deleted = await _confirmVocabularyDeletion(
        context, store, deck.cards.map((c) => c.id).toSet(),
        deleteCollection: deck);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted && context.mounted) Navigator.of(context).pop();
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
          final ids = deck.cards.map((c) => c.id).toSet();
          _selectedIds.removeWhere((id) => !ids.contains(id));
          return Scaffold(
            appBar: AppBar(
              backgroundColor: _surface,
              title: Text(deck.name),
              actions: [
                IconButton(
                    tooltip: '용어 선택',
                    onPressed: _deleting || ids.isEmpty
                        ? null
                        : () => setState(() {
                              _selecting = !_selecting;
                              _selectedIds.clear();
                            }),
                    icon: const Icon(Icons.checklist)),
                IconButton(
                  tooltip: '이 모음에서 검색',
                  onPressed: _deleting
                      ? null
                      : () => showSearch<void>(
                            context: context,
                            delegate: _CollectionSearch(
                              store: store,
                              deckId: deck.id,
                              onOpenTerm: widget.onOpenTerm,
                            ),
                          ),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: 'Rename deck',
                  onPressed:
                      _deleting ? null : () => _renameDeck(context, deck),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '용어 모음 삭제',
                  onPressed: _deleting
                      ? null
                      : () => _confirmDeleteDeck(context, deck),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            body: Column(children: [
              if (_selecting)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _TermSelectionBar(
                      count: _selectedIds.length,
                      allSelected:
                          ids.isNotEmpty && _selectedIds.length == ids.length,
                      busy: _deleting,
                      onSelectAll: () => setState(() {
                        if (_selectedIds.length == ids.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(ids);
                        }
                      }),
                      onDelete: _deleteSelected,
                      onClose: () => setState(() {
                        _selecting = false;
                        _selectedIds.clear();
                      }),
                    )),
              Expanded(child: LayoutBuilder(
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
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 96),
                              itemCount: deck.cards.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final card = deck.cards[index];
                                final cardSubtitle = [
                                  card.meaning,
                                  if (card.example.isNotEmpty) card.example,
                                  if (card.isExcludedFromReview)
                                    'Not in review',
                                ].join('\n');
                                return _Panel(
                                  padding: EdgeInsets.zero,
                                  child: ListTile(
                                    leading: _selecting
                                        ? Checkbox(
                                            value:
                                                _selectedIds.contains(card.id),
                                            semanticLabel:
                                                '${card.displayTerm} 선택',
                                            onChanged: _deleting
                                                ? null
                                                : (_) =>
                                                    _toggleSelected(card.id),
                                          )
                                        : _CardImage(
                                            imageData: card.imageData,
                                            width: 52,
                                            height: 52,
                                          ),
                                    title: Text(card.displayTerm),
                                    subtitle: Text(
                                      cardSubtitle,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    isThreeLine: card.example.isNotEmpty ||
                                        card.isExcludedFromReview,
                                    trailing: _selecting
                                        ? null
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: card.isBookmarked
                                                    ? 'Remove bookmark'
                                                    : 'Bookmark card',
                                                onPressed: () => store
                                                    .toggleBookmark(card.id),
                                                icon: Icon(
                                                  card.isBookmarked
                                                      ? Icons.bookmark_rounded
                                                      : Icons
                                                          .bookmark_outline_rounded,
                                                  color: card.isBookmarked
                                                      ? _indigo
                                                      : _muted,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Edit card',
                                                onPressed: () => _editCard(
                                                    context, deck, card),
                                                icon: const Icon(
                                                    Icons.edit_outlined),
                                              ),
                                              PopupMenuButton<_DeckCardAction>(
                                                tooltip: 'More card actions',
                                                onSelected: (action) {
                                                  switch (action) {
                                                    case _DeckCardAction
                                                          .toggleReview:
                                                      store
                                                          .toggleReviewExclusion(
                                                              card.id);
                                                    case _DeckCardAction.delete:
                                                      _confirmDeleteCard(
                                                          context, deck, card);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: _DeckCardAction
                                                        .toggleReview,
                                                    child: Text(
                                                      card.isExcludedFromReview
                                                          ? 'Include in review'
                                                          : 'Remove from review',
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value:
                                                        _DeckCardAction.delete,
                                                    child: Text('용어 영구 삭제'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                    onTap: _deleting
                                        ? null
                                        : _selecting
                                            ? () => _toggleSelected(card.id)
                                            : () => widget.onOpenTerm(
                                                deck.id, card),
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                },
              )),
            ]),
            floatingActionButton: _selecting
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _editCard(context, deck),
                    icon: const Icon(Icons.add),
                    label: const Text('Add card'),
                  ),
          );
        },
      );
}

class _CollectionSearch extends SearchDelegate<void> {
  _CollectionSearch({
    required this.store,
    required this.deckId,
    required this.onOpenTerm,
  });

  final RecallStore store;
  final String deckId;
  final void Function(String, RecallCard) onOpenTerm;

  @override
  String get searchFieldLabel => '모음 안에서 용어 검색';

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: '검색어 지우기',
            onPressed: () => query = '',
            icon: const Icon(Icons.close_rounded),
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: '뒤로',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final matches = store
        .searchCards(query)
        .where((entry) =>
            store.deckById(deckId)?.cards.any((c) => c.id == entry.card.id) ??
            false)
        .toList();
    if (matches.isEmpty) {
      return Center(
        child: Text(query.isEmpty ? '이 모음의 용어를 검색하세요.' : '검색 결과가 없습니다.'),
      );
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final entry = matches[index];
        return ListTile(
          title: Text(entry.card.front),
          subtitle: Text(
            [
              if (entry.card.termEnglish.isNotEmpty) entry.card.termEnglish,
              entry.card.meaning,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            close(context, null);
            onOpenTerm(deckId, entry.card);
          },
        );
      },
    );
  }
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

class _DictionaryPage extends StatefulWidget {
  const _DictionaryPage({
    required this.store,
    required this.initialQuery,
    required this.initialCategoryId,
    required this.onOpenTerm,
    required this.onCategorySelected,
    this.bookmarkedOnly = false,
  });
  final RecallStore store;
  final String initialQuery;
  final String? initialCategoryId;
  final void Function(String, RecallCard) onOpenTerm;
  final ValueChanged<String?> onCategorySelected;
  final bool bookmarkedOnly;

  @override
  State<_DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<_DictionaryPage> {
  late final TextEditingController _queryController;
  String? _categoryId;
  VocabularyType? _type;
  LearningPriority? _priority;
  bool _selecting = false;
  bool _deleting = false;
  final Set<String> _selectedIds = {};

  void _toggleSelected(String id) => setState(() {
        if (!_selectedIds.add(id)) _selectedIds.remove(id);
      });

  Future<void> _deleteSelected() async {
    setState(() => _deleting = true);
    final deleted = await _confirmVocabularyDeletion(
        context, widget.store, Set.of(_selectedIds));
    if (mounted) {
      setState(() {
        _deleting = false;
        if (deleted) {
          _selectedIds.clear();
          _selecting = false;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _categoryId = widget.initialCategoryId;
  }

  @override
  void didUpdateWidget(covariant _DictionaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _queryController.text = widget.initialQuery;
    }
    if (oldWidget.initialCategoryId != widget.initialCategoryId) {
      _categoryId = widget.initialCategoryId;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          if (_categoryId != null &&
              widget.store.categoryById(_categoryId!) == null) {
            _categoryId = null;
          }
          final results = widget.store.searchCards(_queryController.text,
              categoryId: _categoryId,
              vocabularyType: _type,
              learningPriority: _priority,
              bookmarkedOnly: widget.bookmarkedOnly);
          final ids = results.map((e) => e.card.id).toSet();
          _selectedIds.removeWhere((id) => !ids.contains(id));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(children: [
                        Expanded(
                            child: Text(widget.bookmarkedOnly ? '북마크' : '사전',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: _ink))),
                        Text('${results.length}개',
                            style: const TextStyle(color: _muted)),
                        IconButton(
                            tooltip: '용어 선택',
                            onPressed: _deleting || ids.isEmpty
                                ? null
                                : () => setState(() {
                                      _selecting = !_selecting;
                                      _selectedIds.clear();
                                    }),
                            icon: const Icon(Icons.checklist)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _queryController,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              widget.bookmarkedOnly ? '북마크 검색' : '영어·한국어 검색',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _queryController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '검색어 지우기',
                                  onPressed: () {
                                    _queryController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                  showCheckmark: false,
                                  label: const SizedBox(
                                      width: 76,
                                      child: Text('전체 유형',
                                          textAlign: TextAlign.center)),
                                  selected: _type == null,
                                  onSelected: (_) =>
                                      setState(() => _type = null))),
                          for (final type in VocabularyType.values)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                    showCheckmark: false,
                                    label: SizedBox(
                                        width: type ==
                                                VocabularyType.generalTechnical
                                            ? 112
                                            : 76,
                                        child: Text(type.label,
                                            textAlign: TextAlign.center)),
                                    selected: _type == type,
                                    onSelected: (_) =>
                                        setState(() => _type = type))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_categoryId),
                                  initialValue: _categoryId ?? '',
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: '과목',
                                      isDense: true,
                                      border: OutlineInputBorder()),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '', child: Text('전체 과목')),
                                    for (final category
                                        in widget.store.categories)
                                      DropdownMenuItem(
                                          value: category.id,
                                          child: Text(
                                              widget.store
                                                  .categoryPath(category.id)
                                                  .join(' / '),
                                              overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (id) {
                                    setState(() =>
                                        _categoryId = id == '' ? null : id);
                                    widget.onCategorySelected(_categoryId);
                                  },
                                )),
                            const SizedBox(width: 12),
                            Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('priority-${_priority?.value}'),
                                  initialValue: _priority?.value ?? '',
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: '학습 우선순위',
                                      isDense: true,
                                      border: OutlineInputBorder()),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '', child: Text('전체')),
                                    for (final priority
                                        in LearningPriority.values)
                                      DropdownMenuItem(
                                          value: priority.value,
                                          child: Text(priority.label)),
                                  ],
                                  onChanged: (value) => setState(() =>
                                      _priority = value == ''
                                          ? null
                                          : LearningPriority.parse(value!)),
                                )),
                          ]),
                    ),
                    if (_selecting)
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TermSelectionBar(
                            count: _selectedIds.length,
                            allSelected: ids.isNotEmpty &&
                                _selectedIds.length == ids.length,
                            busy: _deleting,
                            onSelectAll: () => setState(() {
                              if (_selectedIds.length == ids.length) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds.addAll(ids);
                              }
                            }),
                            onDelete: _deleteSelected,
                            onClose: () => setState(() {
                              _selecting = false;
                              _selectedIds.clear();
                            }),
                          )),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Text(
                                  widget.bookmarkedOnly &&
                                          widget.store.bookmarkedCards.isEmpty
                                      ? '북마크한 용어가 없습니다.'
                                      : widget.store.totalCards == 0
                                          ? '등록된 용어가 없습니다.'
                                          : '검색 결과가 없습니다.',
                                  style: const TextStyle(color: _muted)))
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 100),
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) => _VocabularyTile(
                                  store: widget.store,
                                  card: results[i].card,
                                  selecting: _selecting,
                                  selected:
                                      _selectedIds.contains(results[i].card.id),
                                  enabled: !_deleting,
                                  onLongPress: () => setState(() {
                                        _selecting = true;
                                        _selectedIds.add(results[i].card.id);
                                      }),
                                  onTap: () => _selecting
                                      ? _toggleSelected(results[i].card.id)
                                      : widget.onOpenTerm(
                                          results[i].deck.id, results[i].card)),
                            ),
                    ),
                  ]),
            ),
          );
        },
      );
}

class _VocabularyTile extends StatelessWidget {
  const _VocabularyTile(
      {required this.store,
      required this.card,
      required this.onTap,
      this.selecting = false,
      this.selected = false,
      this.enabled = true,
      this.onLongPress});
  final RecallStore store;
  final RecallCard card;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final subjects = store.categoryNamesForCard(card);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      enabled: enabled,
      selected: selected,
      leading: selecting
          ? Checkbox(
              value: selected,
              semanticLabel: '${card.displayTerm} 선택',
              onChanged: enabled ? (_) => onTap() : null)
          : null,
      title: Text(card.displayTerm,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(card.primaryMeaning, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _VocabularyTypeLabel(card.vocabularyType),
          _LearningPriorityLabel(card.learningPriority),
        ]),
        if (subjects.isNotEmpty)
          Text(subjects,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _muted)),
      ]),
      trailing: selecting
          ? null
          : IconButton(
              tooltip: card.isBookmarked ? '북마크 해제' : '북마크 추가',
              onPressed: () => store.toggleBookmark(card.id),
              icon: Icon(
                  card.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: card.isBookmarked ? _indigo : _muted)),
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
    );
  }
}

class _VocabularyTypeLabel extends StatelessWidget {
  const _VocabularyTypeLabel(this.type);
  final VocabularyType type;
  @override
  Widget build(BuildContext context) => Text(type.label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: switch (type) {
          VocabularyType.generalTechnical => const Color(0xFF956319),
          VocabularyType.technical => _indigo,
        },
      ));
}

class _LearningPriorityLabel extends StatelessWidget {
  const _LearningPriorityLabel(this.priority);
  final LearningPriority priority;
  @override
  Widget build(BuildContext context) => Text('우선순위 ${priority.label}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: switch (priority) {
          LearningPriority.high => const Color(0xFFB42318),
          LearningPriority.medium => const Color(0xFF147D69),
          LearningPriority.low => _muted,
        },
      ));
}

class _SubjectsPage extends StatefulWidget {
  const _SubjectsPage({required this.store, required this.onOpenSubject});
  final RecallStore store;
  final ValueChanged<String> onOpenSubject;

  @override
  State<_SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<_SubjectsPage> {
  RecallStore get store => widget.store;
  bool _saving = false;

  Future<void> _togglePinned(RecallCategory subject) async {
    setState(() => _saving = true);
    try {
      await store.setCategoryPinned(subject.id, !subject.isPinned);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('과목 고정을 변경하지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSubject(
      BuildContext context, RecallCategory subject) async {
    if (_saving || store.isCategoryDeletionProtected(subject.id)) return;
    setState(() => _saving = true);
    try {
      await _confirmDeleteSubject(context, subject);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteSubject(
      BuildContext context, RecallCategory subject) async {
    final removed = store.categorySubtree(subject.id);
    final count = store.cardsInCategory(subject.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('과목 삭제'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '“${store.categoryPath(subject.id).join(' / ')}” 과목을 삭제합니다.'),
              if (removed.length > 1) ...[
                const SizedBox(height: 12),
                Text('하위 과목 ${removed.length - 1}개도 함께 삭제됩니다: '
                    '${removed.skip(1).take(5).map((c) => c.name).join(', ')}'
                    '${removed.length > 6 ? ' 외 ${removed.length - 6}개' : ''}'),
              ],
              const SizedBox(height: 12),
              Text('용어 $count개의 과목 연결만 해제됩니다. '
                  '단어, 모음, 북마크 및 학습 기록은 유지됩니다.'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await store.deleteCategory(subject.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('과목을 삭제하지 못했습니다: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Row(children: [
                const Expanded(
                    child: Text('과목',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700))),
                IconButton(
                    tooltip: '과목 추가',
                    onPressed: _saving
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => _SubjectDialog(store: store)),
                    icon: const Icon(Icons.add)),
              ]),
              const SizedBox(height: 12),
              if (store.categories.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('등록된 과목이 없습니다.'))),
              for (final subject in store.categories)
                ListTile(
                  leading: Icon(subject.parentId == null
                      ? Icons.school_outlined
                      : Icons.subdirectory_arrow_right),
                  title: Text(store.categoryPath(subject.id).join(' / '),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle:
                      Text('${store.cardsInCategory(subject.id).length}개 용어'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip:
                            '${store.categoryPath(subject.id).join(' / ')} '
                            '과목 ${subject.isPinned ? '고정 해제' : '고정'}',
                        isSelected: subject.isPinned,
                        onPressed:
                            _saving ? null : () => _togglePinned(subject),
                        icon: const Icon(Icons.push_pin_outlined),
                        selectedIcon:
                            const Icon(Icons.push_pin, color: _indigo)),
                    IconButton(
                        tooltip:
                            '${store.categoryPath(subject.id).join(' / ')} 과목 삭제'
                            '${store.isCategoryDeletionProtected(subject.id) ? ' · 고정 해제 필요' : ''}',
                        onPressed: _saving ||
                                store.isCategoryDeletionProtected(subject.id)
                            ? null
                            : () => _deleteSubject(context, subject),
                        icon: const Icon(Icons.delete_outline)),
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: () => widget.onOpenSubject(subject.id),
                ),
            ],
          ),
        ),
      );
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({required this.store});
  final RecallStore store;
  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  final _name = TextEditingController();
  String? _parentId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.createCategory(_name.text, parentId: _parentId);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is FormatException ? error.message : '과목을 저장하지 못했습니다.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('과목 추가'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _name,
                enabled: !_saving,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _saving ? null : (_) => _create(),
                decoration: const InputDecoration(labelText: '과목 이름'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _parentId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '상위 과목'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('없음')),
                  for (final subject in widget.store.categories)
                    DropdownMenuItem(
                        value: subject.id,
                        child: Text(
                            widget.store.categoryPath(subject.id).join(' / '),
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _parentId = id == '' ? null : id),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('취소')),
          FilledButton(
              onPressed: _saving ? null : _create, child: const Text('추가')),
        ],
      );
}

class _DictionaryTermPage extends StatefulWidget {
  const _DictionaryTermPage({
    required this.store,
    required this.deckId,
    required this.cardId,
    required this.onOpenTerm,
    required this.onCategorySelected,
  });
  final RecallStore store;
  final String deckId;
  final String cardId;
  final void Function(String, RecallCard) onOpenTerm;
  final ValueChanged<String> onCategorySelected;
  @override
  State<_DictionaryTermPage> createState() => _DictionaryTermPageState();
}

class _DictionaryTermPageState extends State<_DictionaryTermPage> {
  @override
  void initState() {
    super.initState();
    widget.store.recordCardViewed(widget.cardId);
  }

  void _collections(RecallCard term) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (_, __) => Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Expanded(
                      child: Text('모음에 추가',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: '새 모음',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () => showDialog<void>(
                            context: sheetContext,
                            builder: (_) => _EntryDialog(
                                title: '새 모음',
                                label: '모음 이름',
                                action: '만들기',
                                onSubmit: widget.store.createDeck),
                          )),
                ]),
              ),
              Expanded(
                child: widget.store.decks.isEmpty
                    ? const Center(child: Text('등록된 모음이 없습니다.'))
                    : ListView(
                        children: [
                          for (final deck in widget.store.decks)
                            CheckboxListTile(
                              title: Text(deck.name),
                              value: deck.cards.any((c) => c.id == term.id),
                              onChanged: (selected) async {
                                try {
                                  if (selected == true) {
                                    await widget.store.addEntryToDeck(
                                        deckId: deck.id, cardId: term.id);
                                  } else {
                                    await widget.store.deleteCard(
                                        deckId: deck.id, cardId: term.id);
                                  }
                                } catch (error) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                            SnackBar(content: Text('$error')));
                                  }
                                }
                              },
                            ),
                        ],
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final term = widget.store.cardById(widget.cardId);
          if (term == null) {
            return Scaffold(
                appBar: AppBar(title: const Text('용어 사전')),
                body: const Center(child: Text('용어를 찾을 수 없습니다.')));
          }
          final deck = widget.store.deckById(widget.deckId) ??
              const RecallDeck(id: '', name: '사전', cards: []);
          final sources = [
            ...term.sources,
            if (term.source.isNotEmpty &&
                !term.sources.any((s) => s.title == term.source))
              VocabularySource(title: term.source),
          ];
          return Scaffold(
            backgroundColor: _surface,
            appBar: AppBar(
              backgroundColor: _surface,
              title: const Text('용어 사전'),
              actions: [
                IconButton(
                    tooltip: '용어 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final deleted = await _confirmVocabularyDeletion(
                          context, widget.store, {term.id});
                      if (deleted && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }),
                IconButton(
                    tooltip: '용어 편집',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => _CardEditorPage(
                                store: widget.store,
                                deckId: deck.id,
                                card: term)))),
                IconButton(
                    tooltip: '모음에 추가',
                    icon: const Icon(Icons.playlist_add),
                    onPressed: () => _collections(term)),
                IconButton(
                    tooltip: term.isBookmarked ? '북마크 해제' : '북마크 추가',
                    onPressed: () => widget.store.toggleBookmark(term.id),
                    icon: Icon(
                        term.isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        color: term.isBookmarked ? _indigo : _muted)),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  children: [
                    SelectableText(term.displayTerm,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 28,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 4, children: [
                      _VocabularyTypeLabel(term.vocabularyType),
                      _LearningPriorityLabel(term.learningPriority),
                    ]),
                    if (term.partOfSpeech.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(term.partOfSpeech.join(' · '))),
                    if (term.abbreviation.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('약어  ${term.abbreviation}')),
                    if (term.categoryIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Wrap(spacing: 7, runSpacing: 7, children: [
                          for (final id in term.categoryIds)
                            if (widget.store.categoryById(id) != null)
                              ActionChip(
                                  label: Text(widget.store
                                      .categoryPath(id)
                                      .join(' / ')),
                                  onPressed: () =>
                                      widget.onCategorySelected(id)),
                        ]),
                      ),
                    const SizedBox(height: 20),
                    _TermSection(
                        title: '뜻',
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final meaning in term.effectiveMeanings)
                                _MeaningView(meaning),
                            ])),
                    if (sources.isNotEmpty)
                      _TermSection(
                          title: '출처',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final s in sources.where((s) => !s.isEmpty))
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (s.title.isNotEmpty)
                                          Text(s.title,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                        if (s.author.isNotEmpty ||
                                            s.year.isNotEmpty)
                                          Text([s.author, s.year]
                                              .where((v) => v.isNotEmpty)
                                              .join(' · ')),
                                        if (s.url.isNotEmpty)
                                          SelectableText(s.url),
                                        if (s.license.isNotEmpty)
                                          Text(s.license),
                                      ],
                                    )),
                            ],
                          )),
                    if (term.relatedTerms.isNotEmpty)
                      _TermSection(
                          title: '관련 용어',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final related in term.relatedTerms)
                                TextButton(
                                    onPressed: widget.store.resolveRelatedTerm(
                                                    related) ==
                                                null ||
                                            widget.store
                                                    .resolveRelatedTerm(related)
                                                    ?.id ==
                                                term.id
                                        ? null
                                        : () => widget.onOpenTerm(
                                            '',
                                            widget.store
                                                .resolveRelatedTerm(related)!),
                                    child: Text(related)),
                            ],
                          )),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => ReviewPage(
                                  store: widget.store,
                                  initialCards: [(deck: deck, card: term)]))),
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('플래시카드로 복습'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _MeaningView extends StatelessWidget {
  const _MeaningView(this.meaning);
  final VocabularyMeaning meaning;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meaning.meaningKo,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (meaning.definitionEn.isNotEmpty &&
              meaning.definitionEn != meaning.meaningKo)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('영어 정의',
                          style: TextStyle(color: _muted, fontSize: 12)),
                      SelectableText(meaning.definitionEn)
                    ])),
          if (meaning.explanationKo.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('한국어 설명',
                          style: TextStyle(color: _muted, fontSize: 12)),
                      Text(meaning.explanationKo)
                    ])),
          if (meaning.exampleSentence.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(meaning.exampleSentence,
                    style: const TextStyle(fontStyle: FontStyle.italic))),
          if (meaning.exampleTranslation.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(meaning.exampleTranslation,
                    style: const TextStyle(color: _muted))),
        ]),
      );
}

class _TermSection extends StatelessWidget {
  const _TermSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DefaultTextStyle(
              style: const TextStyle(color: _ink, fontSize: 15, height: 1.55),
              child: child,
            ),
          ],
        ),
      );
}

class _BookmarkedPage extends StatelessWidget {
  const _BookmarkedPage({required this.store, required this.onOpenTerm});
  final RecallStore store;
  final void Function(String, RecallCard) onOpenTerm;
  @override
  Widget build(BuildContext context) => _DictionaryPage(
        store: store,
        initialQuery: '',
        initialCategoryId: null,
        bookmarkedOnly: true,
        onOpenTerm: onOpenTerm,
        onCategorySelected: (_) {},
      );
}

class _CardImage extends StatelessWidget {
  const _CardImage(
      {required this.imageData, required this.width, required this.height});
  final String? imageData;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (imageData != null) {
        bytes = base64Decode(imageData!);
      }
    } on FormatException {
      bytes = null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: bytes == null
            ? const ColoredBox(
                color: _soft,
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: _muted, size: 30))
            : Image.memory(bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                    color: _soft,
                    child: Icon(Icons.broken_image_outlined, color: _muted))),
      ),
    );
  }
}

class _CardEditorPage extends StatefulWidget {
  const _CardEditorPage({required this.store, required this.deckId, this.card});
  final RecallStore store;
  final String deckId;
  final RecallCard? card;
  @override
  State<_CardEditorPage> createState() => _CardEditorPageState();
}

class _CardEditorPageState extends State<_CardEditorPage> {
  late final TextEditingController _term;
  late final TextEditingController _partOfSpeech;
  late final TextEditingController _subjects;
  late final TextEditingController _related;
  late final TextEditingController _abbreviation;
  late final List<_MeaningDraft> _meanings;
  late final List<_SourceDraft> _sources;
  late VocabularyType _type;
  late LearningPriority _priority;
  String? _imageData;
  bool _saving = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _term = TextEditingController(text: card?.displayTerm ?? '');
    _partOfSpeech =
        TextEditingController(text: card?.partOfSpeech.join('; ') ?? '');
    _subjects = TextEditingController(
        text: card == null
            ? ''
            : widget.store.categoryPathsForCard(card).join('\n'));
    _related = TextEditingController(text: card?.relatedTerms.join('; ') ?? '');
    _abbreviation = TextEditingController(text: card?.abbreviation ?? '');
    _type = card?.vocabularyType ?? VocabularyType.generalTechnical;
    _priority = card?.learningPriority ?? LearningPriority.medium;
    _meanings = card == null
        ? [_MeaningDraft()]
        : card.effectiveMeanings.map(_MeaningDraft.new).toList();
    _sources = [
      for (final s in card?.sources ?? <VocabularySource>[]) _SourceDraft(s),
      if (card != null &&
          card.source.isNotEmpty &&
          !card.sources.any((s) => s.title == card.source))
        _SourceDraft(VocabularySource(title: card.source)),
    ];
    _imageData = card?.imageData;
  }

  @override
  void dispose() {
    for (final controller in [
      _term,
      _partOfSpeech,
      _subjects,
      _related,
      _abbreviation
    ]) {
      controller.dispose();
    }
    for (final meaning in _meanings) {
      meaning.dispose();
    }
    for (final source in _sources) {
      source.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
          {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines + 3,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.card == null ? '새 용어' : '용어 편집'),
            actions: [
              IconButton(
                  tooltip: '저장',
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded)),
            ]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _field(_term, '영어 용어'),
                DropdownButtonFormField<VocabularyType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: '단어 유형', border: OutlineInputBorder()),
                  items: [
                    for (final t in VocabularyType.values)
                      DropdownMenuItem(value: t, child: Text(t.label))
                  ],
                  onChanged: (t) => setState(() => _type = t!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<LearningPriority>(
                  initialValue: _priority,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: '학습 우선순위', border: OutlineInputBorder()),
                  items: [
                    for (final p in LearningPriority.values)
                      DropdownMenuItem(value: p, child: Text(p.label))
                  ],
                  onChanged: (p) => setState(() => _priority = p!),
                ),
                const SizedBox(height: 14),
                _field(_partOfSpeech, '품사'),
                _field(_subjects, '과목 경로', lines: 2),
                _field(_abbreviation, '약어'),
                const Divider(),
                for (var i = 0; i < _meanings.length; i++) ...[
                  Row(children: [
                    Expanded(
                        child: Text('의미 ${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 18))),
                    if (_meanings.length > 1)
                      IconButton(
                          tooltip: '의미 삭제',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() {
                                _meanings.removeAt(i).dispose();
                              })),
                  ]),
                  _field(_meanings[i].fields['meaning_ko']!, '한국어 뜻'),
                  _field(_meanings[i].fields['definition_en']!, '영어 정의',
                      lines: 2),
                  _field(_meanings[i].fields['explanation_ko']!, '간단한 한국어 설명',
                      lines: 2),
                  _field(_meanings[i].fields['example_sentence']!, '영어 예문',
                      lines: 2),
                  _field(_meanings[i].fields['example_translation']!, '예문 번역',
                      lines: 2),
                  const Divider(),
                ],
                Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                        onPressed: () => setState(() => _meanings.add(
                            _MeaningDraft(
                                null,
                                _type == VocabularyType.technical
                                    ? MeaningType.technical
                                    : MeaningType.general))),
                        icon: const Icon(Icons.add),
                        label: const Text('의미 추가'))),
                const SizedBox(height: 20),
                _field(_related, '관련 용어'),
                for (var i = 0; i < _sources.length; i++) ...[
                  Row(children: [
                    Expanded(
                        child: Text('출처 ${i + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(
                        tooltip: '출처 삭제',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                              _sources.removeAt(i).dispose();
                            })),
                  ]),
                  for (final field in _SourceDraft.labels.entries)
                    _field(_sources[i].fields[field.key]!, field.value),
                ],
                Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _sources.add(_SourceDraft())),
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('출처 추가'))),
                const SizedBox(height: 20),
                if (_imageData != null)
                  _CardImage(
                      imageData: _imageData,
                      width: double.infinity,
                      height: 220),
                Wrap(spacing: 8, children: [
                  IconButton(
                      tooltip: '사진 촬영',
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: _pickingImage
                          ? null
                          : () => _pickImage(ImageSource.camera)),
                  IconButton(
                      tooltip: '사진 업로드',
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      onPressed: _pickingImage
                          ? null
                          : () => _pickImage(ImageSource.gallery)),
                  if (_imageData != null)
                    IconButton(
                        tooltip: '사진 제거',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _imageData = null)),
                ]),
                if (_pickingImage) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      );

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final file = await ImagePicker().pickImage(
          source: source, imageQuality: 72, maxWidth: 1200, maxHeight: 1200);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _imageData = base64Encode(bytes));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    final term = _term.text.trim();
    final meanings = _meanings.map((m) => m.value).toList();
    if (term.isEmpty || meanings.any((m) => m.meaningKo.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('영어 용어와 각 의미의 한국어 뜻을 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    final sources =
        _sources.map((s) => s.value).where((s) => !s.isEmpty).toList();
    final old = widget.card;
    final front =
        old != null && old.front != old.displayTerm ? old.front : term;
    try {
      if (old == null) {
        await widget.store.addCard(
          deckId: widget.deckId,
          front: front,
          termEnglish: term,
          meaning: meanings.first.meaningKo,
          example: meanings.first.exampleSentence,
          imageData: _imageData,
          vocabularyType: _type,
          learningPriority: _priority,
          meanings: meanings,
          partOfSpeech: splitVocabularyList(_partOfSpeech.text),
          categoryPaths: _subjects.text.split('\n'),
          abbreviation: _abbreviation.text,
          relatedTerms: splitVocabularyList(_related.text),
          sources: sources,
          source: sources.isEmpty ? '' : sources.first.title,
        );
      } else {
        await widget.store.updateCard(
          deckId: widget.deckId,
          cardId: old.id,
          front: front,
          termEnglish: term,
          meaning: meanings.first.meaningKo,
          example: meanings.first.exampleSentence,
          imageData: _imageData ?? '',
          vocabularyType: _type,
          learningPriority: _priority,
          meanings: meanings,
          partOfSpeech: splitVocabularyList(_partOfSpeech.text),
          categoryPaths: _subjects.text.split('\n'),
          abbreviation: _abbreviation.text,
          relatedTerms: splitVocabularyList(_related.text),
          sources: sources,
          source: sources.isEmpty ? '' : sources.first.title,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MeaningDraft {
  _MeaningDraft(
      [VocabularyMeaning? meaning, MeaningType type = MeaningType.general])
      : id = meaning?.id ?? 'meaning-${DateTime.now().microsecondsSinceEpoch}',
        type = meaning?.type ?? type,
        fields = {
          for (final key in keys)
            key: TextEditingController(
                text: meaning?.toJson()[key] as String? ?? ''),
        };
  static const keys = [
    'meaning_ko',
    'definition_en',
    'explanation_ko',
    'example_sentence',
    'example_translation',
    'formula',
    'symbol',
    'unit',
    'application_context',
  ];
  final String id;
  MeaningType type;
  final Map<String, TextEditingController> fields;
  VocabularyMeaning get value => VocabularyMeaning.fromJson({
        'id': id,
        'meaning_type': type.value,
        for (final field in fields.entries) field.key: field.value.text.trim(),
      });
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
  }
}

class _SourceDraft {
  _SourceDraft([VocabularySource? source])
      : fields = {
          for (final key in labels.keys)
            key: TextEditingController(
                text: source?.toJson()[key] as String? ?? ''),
        };
  static const labels = {
    'title': '출처 제목',
    'author': '저자',
    'year': '연도',
    'url': 'URL',
    'license': '라이선스'
  };
  final Map<String, TextEditingController> fields;
  VocabularySource get value => VocabularySource.fromJson({
        for (final field in fields.entries) field.key: field.value.text.trim(),
      });
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
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

class _FlashcardLaunchPage extends StatelessWidget {
  const _FlashcardLaunchPage({
    required this.store,
    required this.onStartReview,
  });

  final RecallStore store;
  final void Function({StudyCards? cards}) onStartReview;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final categoriesWithChildren = store.categories
              .where((category) => category.parentId != null)
              .toList();
          final categoryChoices = categoriesWithChildren.isNotEmpty
              ? categoriesWithChildren
              : store.categories;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  const _HomeSectionHeading('플래시카드 복습'),
                  const SizedBox(height: 4),
                  const Text('용어와 정의를 간단히 확인합니다.',
                      style: TextStyle(color: _muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  _Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.style_outlined, color: _indigo),
                      title: const Text('복습 가능한 전체 용어'),
                      subtitle: Text('${store.dueCards.length}개'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: store.dueCards.isEmpty
                          ? null
                          : () => onStartReview(cards: store.dueCards),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_outline_rounded,
                          color: _indigo),
                      title: const Text('북마크 용어'),
                      subtitle: Text('${store.bookmarkedCards.length}개'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: store.bookmarkedCards.isEmpty
                          ? null
                          : () => onStartReview(
                                cards: store.bookmarkedCards
                                    .where((entry) =>
                                        !entry.card.isExcludedFromReview)
                                    .toList(),
                              ),
                    ),
                  ),
                  if (categoryChoices.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _HomeSectionHeading('분류별 복습'),
                    const SizedBox(height: 8),
                    for (final category in categoryChoices)
                      _Panel(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          title:
                              Text(store.categoryPath(category.id).join(' / ')),
                          subtitle: Text(
                              '${store.cardsInCategory(category.id).length}개'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => onStartReview(
                            cards: store
                                .cardsInCategory(category.id)
                                .where(
                                    (entry) => !entry.card.isExcludedFromReview)
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 22),
                  const _HomeSectionHeading('용어 모음별 복습'),
                  const SizedBox(height: 8),
                  for (final deck in store.decks)
                    _Panel(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(deck.name),
                        subtitle: Text('${deck.cards.length}개'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: deck.cards.isEmpty
                            ? null
                            : () => onStartReview(
                                  cards: [
                                    for (final card in deck.cards)
                                      if (!card.isExcludedFromReview)
                                        (deck: deck, card: card),
                                  ],
                                ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.onSubmit,
    this.initialValue = '',
    this.successMessage = 'added',
  });

  final String title;
  final String label;
  final String action;
  final ValueChanged<String> onSubmit;
  final String initialValue;
  final String successMessage;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“$value” ${widget.successMessage}')));
  }
}
