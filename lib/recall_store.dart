import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'csv_import.dart';
import 'vocabulary.dart';

export 'csv_import.dart'
    show
        CsvImportPreview,
        CsvImportReport,
        splitVocabularyList,
        recallV3Columns;
export 'vocabulary.dart';

typedef DictionaryCards = List<({RecallDeck deck, RecallCard card})>;

class RecallStore extends ChangeNotifier {
  RecallStore._(this._preferences);
  static const _legacyKey = 'recall.data.v1';
  static const _previousKey = 'recall.data.v2';
  static const _dataKey = 'recall.data.v3';
  static int _idSequence = 0;
  static const _fixedSubjectNames = ['전기공학', '반도체공학'];
  static const _subjectNames = {
    'Electrical Engineering': '전기공학',
    'Semiconductor Engineering': '반도체공학',
    'Mathematics': '수학',
    'Electromagnetics': '전자기학',
    'Circuit Theory': '회로이론',
    'Electrical Machines': '전기기기',
    'Power Engineering': '전력공학',
    'Electrical Installations': '전기설비',
    'Electronics': '전자공학',
    'Control Engineering': '제어공학',
    'Electrical and Electronic Engineering': '전기전자공학',
  };
  final SharedPreferences _preferences;
  final Map<String, RecallCard> _entries = {};
  List<RecallDeck> _decks = [];
  List<RecallCategory> _categories = [];
  List<({String cardId, DateTime viewedAt})> _recentViews = [];
  DictionaryCards? _allCardsCache;
  final Map<String, String> _searchText = {};
  Future<void> _pendingSave = Future.value();
  int _dailyGoal = 24;
  int _reviewsToday = 0;
  bool _tutorialCompleted = false;
  String _reviewDay = _dayKey(DateTime.now());

  static Future<RecallStore> load({SharedPreferences? storage}) async {
    final preferences = storage ?? await SharedPreferences.getInstance();
    final store = RecallStore._(preferences);
    final current = preferences.getString(_dataKey);
    final previous = preferences.getString(_previousKey);
    final encoded = current ?? previous ?? preferences.getString(_legacyKey);
    if (encoded != null) {
      // Never overwrite a corrupt save with a silently empty dictionary.
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      store._categories = (json['categories'] as List? ?? [])
          .map((c) =>
              RecallCategory.fromJson(Map<String, Object?>.from(c as Map)))
          .toList();
      if (current != null || previous != null) {
        if (json['schemaVersion'] != (current != null ? 3 : 2)) {
          throw const FormatException('지원하지 않는 저장 데이터 버전입니다.');
        }
        for (final value in json['entries'] as List) {
          final card =
              RecallCard.fromJson(Map<String, Object?>.from(value as Map));
          if (store._entries.containsKey(card.id)) {
            throw const FormatException('사전 항목 ID가 중복됩니다.');
          }
          store._entries[card.id] = card;
        }
        store._decks = (json['decks'] as List).map((value) {
          final deck = value as Map;
          final ids = (deck['entryIds'] as List).cast<String>();
          if (ids.any((id) => !store._entries.containsKey(id))) {
            throw const FormatException('모음에 존재하지 않는 단어 ID가 있습니다.');
          }
          return RecallDeck(
              id: deck['id'] as String,
              name: deck['name'] as String,
              cards: ids.toSet().map((id) => store._entries[id]!).toList());
        }).toList();
      } else {
        final reserved = <String>{};
        for (final value in json['decks'] as List? ?? []) {
          final legacy =
              RecallDeck.fromJson(Map<String, Object?>.from(value as Map));
          final deckId = reserved.add(legacy.id)
              ? legacy.id
              : store._newId(reservedIds: reserved);
          final cards = <RecallCard>[];
          for (final old in legacy.cards) {
            final id = reserved.add(old.id)
                ? old.id
                : store._newId(reservedIds: reserved);
            final card = old.copyWith(id: id, meanings: old.effectiveMeanings);
            store._entries[id] = card;
            cards.add(card);
          }
          store._decks
              .add(RecallDeck(id: deckId, name: legacy.name, cards: cards));
        }
      }
      store._dailyGoal = (json['dailyGoal'] as int? ?? 24).clamp(1, 200);
      store._reviewsToday = json['reviewsToday'] as int? ?? 0;
      store._tutorialCompleted = json['tutorialCompleted'] as bool? ?? false;
      store._reviewDay =
          json['reviewDay'] as String? ?? _dayKey(DateTime.now());
      store._recentViews = (json['recentViews'] as List? ?? [])
          .map((visit) {
            final entry = visit as Map;
            return (
              cardId: entry['cardId'] as String,
              viewedAt: DateTime.tryParse(entry['viewedAt'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0)
            );
          })
          .where((v) => store._entries.containsKey(v.cardId))
          .take(20)
          .toList();
    }
    var fixedSubjectsChanged = false;
    for (final name in _fixedSubjectNames) {
      final index = store._categories.indexWhere((c) =>
          c.parentId == null && store._categoryDisplayName(c.name) == name);
      if (index == -1) {
        store._findOrCreateCategory(name);
        fixedSubjectsChanged = true;
      } else if (store._categories[index].name != name) {
        store._categories[index] =
            RecallCategory(id: store._categories[index].id, name: name);
        fixedSubjectsChanged = true;
      }
    }
    store._rollReviewDay();
    if (fixedSubjectsChanged || (encoded != null && current == null)) {
      await store._save();
    }
    return store;
  }

  List<RecallDeck> get decks => List.unmodifiable(_decks.map(_hydrateDeck));
  List<RecallCategory> get categories => List.unmodifiable([
        for (final name in _fixedSubjectNames)
          ..._categories.where((c) => c.parentId == null && c.name == name),
        ..._categories.where((c) => !isFixedCategory(c.id)),
      ]);
  int get dailyGoal => _dailyGoal;
  int get reviewsToday => _reviewsToday;
  bool get tutorialCompleted => _tutorialCompleted;
  int get totalCards => _entries.length;
  int get dueCount => dueCards.length;
  int get remainingToday =>
      math.min(dueCount, math.max(0, dailyGoal - reviewsToday));
  RecallCard? cardById(String id) => _entries[id];
  RecallDeck _hydrateDeck(RecallDeck deck) => RecallDeck(
      id: deck.id,
      name: deck.name,
      cards: List.unmodifiable(
          deck.cards.map((c) => _entries[c.id]).whereType<RecallCard>()));

  DictionaryCards get allCards => _allCardsCache ??= () {
        final owners = <String, RecallDeck>{};
        for (final deck in decks) {
          for (final card in deck.cards) {
            owners.putIfAbsent(card.id, () => deck);
          }
        }
        const dictionary = RecallDeck(id: '', name: '사전', cards: []);
        return List<({RecallDeck deck, RecallCard card})>.unmodifiable([
          for (final card in _entries.values)
            (deck: owners[card.id] ?? dictionary, card: card),
        ]);
      }();
  DictionaryCards get recentCards {
    final indexed = {for (final entry in allCards) entry.card.id: entry};
    return [
      for (final v in _recentViews)
        if (indexed.containsKey(v.cardId)) indexed[v.cardId]!
    ];
  }

  DictionaryCards get dueCards =>
      allCards.where((e) => !e.card.isExcludedFromReview).toList()
        ..sort((a, b) => a.card.displayTerm
            .toLowerCase()
            .compareTo(b.card.displayTerm.toLowerCase()));
  DictionaryCards get bookmarkedCards =>
      allCards.where((e) => e.card.isBookmarked).toList();
  RecallDeck? deckById(String id) {
    for (final deck in _decks) {
      if (deck.id == id) return _hydrateDeck(deck);
    }
    return null;
  }

  RecallCategory? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool isFixedCategory(String id) {
    final category = categoryById(id);
    return category != null &&
        category.parentId == null &&
        _fixedSubjectNames.contains(_categoryDisplayName(category.name));
  }

  List<RecallCategory> categorySubtree(String id) {
    final root = categoryById(id);
    if (root == null) return [];
    final ids = {id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final category in _categories) {
        if (ids.contains(category.parentId) && ids.add(category.id)) {
          changed = true;
        }
      }
    }
    return [
      root,
      ..._categories.where((c) => c.id != id && ids.contains(c.id))
    ];
  }

  Future<RecallCategory> createCategory(String name, {String? parentId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('과목 이름을 입력해 주세요.');
    if (trimmed.contains('/')) {
      throw const FormatException('과목 이름에는 /를 사용할 수 없습니다.');
    }
    if (parentId != null && categoryById(parentId) == null) {
      throw const FormatException('상위 과목을 찾을 수 없습니다.');
    }
    final display = _categoryDisplayName(trimmed, parentId: parentId);
    if (_categories.any((c) =>
        c.parentId == parentId &&
        _categoryDisplayName(c.name, parentId: c.parentId).toLowerCase() ==
            display.toLowerCase())) {
      throw const FormatException('같은 위치에 동일한 과목이 이미 있습니다.');
    }
    final oldCategories = List<RecallCategory>.of(_categories);
    final category = _findOrCreateCategory(display, parentId: parentId);
    await _saveCategoryChanges(oldCategories);
    return category;
  }

  Future<void> deleteCategory(String id) async {
    final removed = categorySubtree(id);
    if (removed.isEmpty) return;
    if (removed.any((c) => isFixedCategory(c.id))) {
      throw StateError('기본 과목은 삭제할 수 없습니다.');
    }
    final ids = removed.map((c) => c.id).toSet();
    final oldCategories = List<RecallCategory>.of(_categories);
    final oldEntries = Map<String, RecallCard>.of(_entries);
    _categories.removeWhere((c) => ids.contains(c.id));
    for (final card in _entries.values.toList()) {
      if (card.categoryIds.any(ids.contains)) {
        _entries[card.id] = card.copyWith(
            categoryIds:
                card.categoryIds.where((id) => !ids.contains(id)).toList());
      }
    }
    await _saveCategoryChanges(oldCategories, oldEntries: oldEntries);
  }

  Future<void> _saveCategoryChanges(List<RecallCategory> oldCategories,
      {Map<String, RecallCard>? oldEntries}) async {
    try {
      await _save();
    } catch (_) {
      _categories = oldCategories;
      if (oldEntries != null) {
        _entries.clear();
        _entries.addAll(oldEntries);
      }
      _allCardsCache = null;
      _searchText.clear();
      try {
        await _preferences.reload();
      } catch (_) {
        // Report the original save error after restoring the in-memory data.
      }
      if (hasListeners) notifyListeners();
      rethrow;
    }
  }

  List<String> categoryPath(String id) {
    final names = <String>[];
    final visited = <String>{};
    var category = categoryById(id);
    while (category != null && visited.add(category.id)) {
      names.insert(0, category.name);
      category =
          category.parentId == null ? null : categoryById(category.parentId!);
    }
    return names;
  }

  List<String> categoryPathsForCard(RecallCard card) => {
        for (final id in card.categoryIds)
          if (categoryPath(id).isNotEmpty) categoryPath(id).join(' / '),
      }.toList();
  String categoryNamesForCard(RecallCard card) =>
      categoryPathsForCard(card).join(', ');
  DictionaryCards cardsInCategory(String categoryId) =>
      searchCards('', categoryId: categoryId);
  bool _inCategory(RecallCard card, String id) =>
      card.categoryIds.any((cardId) {
        final visited = <String>{};
        var category = categoryById(cardId);
        while (category != null && visited.add(category.id)) {
          if (category.id == id) return true;
          category = category.parentId == null
              ? null
              : categoryById(category.parentId!);
        }
        return false;
      });
  DictionaryCards searchCards(
    String query, {
    String? categoryId,
    VocabularyType? vocabularyType,
    LearningPriority? learningPriority,
    bool bookmarkedOnly = false,
  }) {
    final normalized = query.trim().toLowerCase();
    final matches = <({int score, RecallDeck deck, RecallCard card})>[];
    for (final entry in allCards) {
      final card = entry.card;
      if (categoryId != null && !_inCategory(card, categoryId)) continue;
      if (vocabularyType != null && card.vocabularyType != vocabularyType) {
        continue;
      }
      if (learningPriority != null &&
          card.learningPriority != learningPriority) {
        continue;
      }
      if (bookmarkedOnly && !card.isBookmarked) continue;
      final names = [card.front, card.displayTerm, card.abbreviation]
          .map((s) => s.toLowerCase());
      final text = _searchText.putIfAbsent(
          card.id,
          () => [
                for (final m in card.effectiveMeanings)
                  '${m.meaningKo}\n${m.definition}\n${m.explanation}\n${m.exampleSentence}\n${m.exampleTranslation}',
                card.meaning,
                ...card.relatedTerms,
              ].join('\n').toLowerCase());
      final score = normalized.isEmpty
          ? 5
          : names.contains(normalized)
              ? 0
              : names.any((s) => s.startsWith(normalized))
                  ? 1
                  : names.any((s) => s.contains(normalized))
                      ? 2
                      : text.contains(normalized)
                          ? 3
                          : null;
      if (score != null) {
        matches.add((score: score, deck: entry.deck, card: card));
      }
    }
    matches.sort((a, b) {
      final score = a.score.compareTo(b.score);
      return score == 0
          ? a.card.displayTerm
              .toLowerCase()
              .compareTo(b.card.displayTerm.toLowerCase())
          : score;
    });
    return [for (final m in matches) (deck: m.deck, card: m.card)];
  }

  RecallCard? resolveRelatedTerm(String query) {
    final normalized = query.trim().toLowerCase();
    if (_entries.containsKey(query)) return _entries[query];
    for (final card in _entries.values) {
      if ([card.front, card.displayTerm, card.primaryMeaning]
          .any((s) => s.toLowerCase() == normalized)) {
        return card;
      }
    }
    return null;
  }

  Future<void> recordCardViewed(String id) async {
    if (!_entries.containsKey(id)) return;
    _recentViews.removeWhere((v) => v.cardId == id);
    _recentViews.insert(0, (cardId: id, viewedAt: DateTime.now()));
    _recentViews = _recentViews.take(20).toList();
    await _save();
  }

  CsvImportPreview previewCsvImportDetailed(String text) {
    final parsed = parseVocabularyCsv(text);
    final existingKeys = _entries.values.map(vocabularyKey).toSet();
    final seen = <String>{};
    var newCount = 0;
    var existingCount = 0;
    var duplicates = 0;
    for (final row in parsed.rows) {
      final key = vocabularyKey(row.card);
      if (!seen.add(key)) {
        duplicates++;
        continue;
      }
      if (existingKeys.contains(key)) {
        existingCount++;
      } else {
        newCount++;
      }
    }
    return CsvImportPreview(
        rows: parsed.rows,
        errors: parsed.errors,
        unknownHeaders: parsed.unknownHeaders,
        newEntryCount: newCount,
        existingEntryCount: existingCount,
        duplicateCount: duplicates);
  }

  int previewCsvImport(String text) =>
      previewCsvImportDetailed(text).entryCount;
  Future<int> importCsvDeck(
          {required String csvText, String? deckName}) async =>
      (await importCsvDeckDetailed(csvText: csvText, deckName: deckName))
          .importedCount;
  Future<CsvImportReport> importCsvDeckDetailed(
      {required String csvText, String? deckName}) async {
    final preview = previewCsvImportDetailed(csvText);
    final byKey = <String, RecallCard>{};
    for (final card in _entries.values) {
      byKey.putIfAbsent(vocabularyKey(card), () => card);
    }
    final ids = <String>{};
    var imported = 0;
    var duplicates = 0;
    for (final row in preview.rows) {
      var incoming = row.card
          .copyWith(categoryIds: _categoryIdsForPaths(row.subjectPaths));
      final key = vocabularyKey(incoming);
      final existing = byKey[key];
      if (existing != null) {
        incoming =
            _mergeEntry(existing, incoming, suppliedFields: row.suppliedFields);
        duplicates++;
      } else {
        final id = incoming.id.isNotEmpty && !_idExists(incoming.id)
            ? incoming.id
            : _newId();
        incoming = incoming.copyWith(id: id, meanings: [
          for (var i = 0; i < incoming.meanings.length; i++)
            VocabularyMeaning.fromJson(
                {...incoming.meanings[i].toJson(), 'id': '$id-meaning-$i'}),
        ]);
        imported++;
      }
      _entries[incoming.id] = incoming;
      byKey[key] = incoming;
      ids.add(incoming.id);
    }
    if (ids.isNotEmpty) {
      final name = (deckName ?? 'Imported deck').trim();
      _decks.add(RecallDeck(
          id: _newId(),
          name: name.isEmpty ? 'Imported deck' : name,
          cards: ids.map((id) => _entries[id]!).toList()));
      await _save();
    }
    return CsvImportReport(
        importedCount: imported,
        duplicateCount: duplicates,
        invalidRowCount: preview.errors.length,
        linkedCount: ids.length,
        errors: preview.errors,
        unknownHeaders: preview.unknownHeaders);
  }

  RecallCard _mergeEntry(RecallCard existing, RecallCard incoming,
      {Set<String> suppliedFields = const {}}) {
    String meaningKey(VocabularyMeaning m) =>
        jsonEncode(m.toJson()..remove('id'));
    final meanings = [...existing.effectiveMeanings];
    final seen = meanings.map(meaningKey).toSet();
    for (final m in incoming.effectiveMeanings) {
      if (seen.add(meaningKey(m))) {
        meanings.add(VocabularyMeaning.fromJson({
          ...m.toJson(),
          'id': '${existing.id}-meaning-${_newId()}',
        }));
      }
    }
    final hasGeneral = meanings.any((m) => m.type == MeaningType.general);
    final hasTechnical = meanings.any((m) => m.type == MeaningType.technical);
    final type = hasGeneral && hasTechnical
        ? VocabularyType.generalTechnical
        : (existing.vocabularyType == VocabularyType.generalTechnical ||
                incoming.vocabularyType == VocabularyType.generalTechnical)
            ? VocabularyType.generalTechnical
            : hasTechnical
                ? VocabularyType.technical
                : VocabularyType.generalTechnical;
    final sources = {
      for (final s in [...existing.sources, ...incoming.sources])
        jsonEncode(s.toJson()): s
    }.values.toList();
    final extra = {...existing.extraFields};
    for (final field in incoming.extraFields.entries) {
      extra[field.key] =
          extra[field.key] == null || extra[field.key] == field.value
              ? field.value
              : '${extra[field.key]}\n${field.value}';
    }
    final contentAdded = meanings.length != existing.effectiveMeanings.length;
    String combine(String old, String added) => {
          ...old.split('\n'),
          ...added.split('\n')
        }.where((s) => s.isNotEmpty).join('\n');
    return existing.copyWith(
        vocabularyType:
            suppliedFields.contains('type') ? incoming.vocabularyType : type,
        learningPriority: suppliedFields.contains('priority')
            ? incoming.learningPriority
            : existing.learningPriority,
        priorityReason: suppliedFields.contains('priorityReason')
            ? incoming.priorityReason
            : existing.priorityReason,
        inclusionRecommendation: suppliedFields.contains('inclusion')
            ? incoming.inclusionRecommendation
            : existing.inclusionRecommendation,
        collector: combine(existing.collector, incoming.collector),
        notes: combine(existing.notes, incoming.notes),
        meanings: meanings,
        categoryIds:
            {...existing.categoryIds, ...incoming.categoryIds}.toList(),
        relatedTerms:
            {...existing.relatedTerms, ...incoming.relatedTerms}.toList(),
        partOfSpeech:
            {...existing.partOfSpeech, ...incoming.partOfSpeech}.toList(),
        sources: sources,
        extraFields: extra,
        abbreviation: existing.abbreviation.isEmpty
            ? incoming.abbreviation
            : existing.abbreviation,
        verificationStatus: !contentAdded
            ? existing.verificationStatus
            : (existing.verificationStatus == VerificationStatus.aiDraft ||
                    incoming.verificationStatus == VerificationStatus.aiDraft)
                ? VerificationStatus.aiDraft
                : VerificationStatus.needsReview);
  }

  Future<void> createDeck(String name) async {
    if (name.trim().isEmpty) return;
    _decks.add(RecallDeck(id: _newId(), name: name.trim(), cards: []));
    await _save();
  }

  Future<void> updateDeckName(String id, String name) async {
    final i = _decks.indexWhere((d) => d.id == id);
    if (i < 0 || name.trim().isEmpty) return;
    _decks[i] = RecallDeck(id: id, name: name.trim(), cards: _decks[i].cards);
    await _save();
  }

  Future<void> deleteDeck(String id) async {
    final deck = deckById(id);
    if (deck == null) return;
    await _deleteVocabulary(deck.cards.map((c) => c.id).toSet(), deckId: id);
  }

  Future<void> deleteEntries(Iterable<String> entryIds) =>
      _deleteVocabulary(entryIds.where(_entries.containsKey).toSet());

  Future<void> _deleteVocabulary(Set<String> ids, {String? deckId}) async {
    if (ids.isEmpty && deckId == null) return;
    final oldEntries = Map<String, RecallCard>.of(_entries);
    final oldDecks = _decks;
    final oldVisits = _recentViews;
    _entries.removeWhere((id, _) => ids.contains(id));
    _decks = [
      for (final deck in _decks)
        if (deck.id != deckId)
          RecallDeck(
              id: deck.id,
              name: deck.name,
              cards: deck.cards.where((c) => !ids.contains(c.id)).toList()),
    ];
    _recentViews = _recentViews.where((v) => !ids.contains(v.cardId)).toList();
    try {
      await _save();
    } catch (_) {
      _entries.clear();
      _entries.addAll(oldEntries);
      _decks = oldDecks;
      _recentViews = oldVisits;
      _allCardsCache = null;
      _searchText.clear();
      // Failed preferences writes can still update their in-memory cache.
      try {
        await _preferences.reload();
      } catch (_) {
        // Keep the restored vocabulary and report the original save error.
      }
      if (hasListeners) notifyListeners();
      rethrow;
    }
  }

  Future<void> addEntryToDeck(
      {required String deckId, required String cardId}) async {
    final i = _decks.indexWhere((d) => d.id == deckId);
    final card = _entries[cardId];
    if (i < 0 || card == null || _decks[i].cards.any((c) => c.id == cardId)) {
      return;
    }
    final deck = _decks[i];
    _decks[i] =
        RecallDeck(id: deck.id, name: deck.name, cards: [...deck.cards, card]);
    await _save();
  }

  // Unchecking collection membership is different from deleting vocabulary.
  Future<void> deleteCard(
      {required String deckId, required String cardId}) async {
    final i = _decks.indexWhere((d) => d.id == deckId);
    if (i < 0) return;
    final deck = _decks[i];
    _decks[i] = RecallDeck(
        id: deck.id,
        name: deck.name,
        cards: deck.cards.where((c) => c.id != cardId).toList());
    await _save();
  }

  Future<void> addCard({
    required String deckId,
    required String front,
    required String meaning,
    required String example,
    String? imageData,
    String termEnglish = '',
    String abbreviation = '',
    String symbol = '',
    String formula = '',
    String unit = '',
    String source = '',
    List<String> relatedTerms = const [],
    List<String> categoryNames = const [],
    List<String> categoryPaths = const [],
    VocabularyType? vocabularyType,
    LearningPriority learningPriority = LearningPriority.medium,
    String priorityReason = '',
    InclusionRecommendation inclusionRecommendation =
        InclusionRecommendation.review,
    String collector = '',
    String notes = '',
    List<String> partOfSpeech = const [],
    List<VocabularyMeaning> meanings = const [],
    List<VocabularySource> sources = const [],
    VerificationStatus verificationStatus = VerificationStatus.needsReview,
  }) async {
    if (front.trim().isEmpty || meaning.trim().isEmpty) {
      throw ArgumentError('용어와 뜻이 필요합니다.');
    }
    if (deckId.isNotEmpty && deckById(deckId) == null) {
      throw ArgumentError('모음을 찾을 수 없습니다.');
    }
    var card = RecallCard(
        id: _newId(),
        front: front.trim(),
        meaning: meaning.trim(),
        example: example.trim(),
        dueAt: DateTime.now(),
        intervalMinutes: 0,
        stabilityDays: 2.1,
        ease: 2.5,
        lastReviewed: null,
        imageData: imageData,
        termEnglish: termEnglish.trim(),
        abbreviation: abbreviation.trim(),
        symbol: symbol.trim(),
        formula: formula.trim(),
        unit: unit.trim(),
        source: source.trim(),
        relatedTerms: relatedTerms,
        categoryIds: _categoryIdsForPaths([...categoryNames, ...categoryPaths]),
        vocabularyType: vocabularyType ??
            ([symbol, formula, unit].any((s) => s.trim().isNotEmpty)
                ? VocabularyType.technical
                : VocabularyType.generalTechnical),
        learningPriority: learningPriority,
        priorityReason: priorityReason,
        inclusionRecommendation: inclusionRecommendation,
        collector: collector,
        notes: notes,
        partOfSpeech: partOfSpeech,
        meanings: meanings,
        sources: sources,
        verificationStatus: verificationStatus);
    if (card.meanings.isEmpty) {
      card = card.copyWith(meanings: card.effectiveMeanings);
    }
    final existing =
        _entries.values.where((c) => vocabularyKey(c) == vocabularyKey(card));
    if (existing.isNotEmpty) card = _mergeEntry(existing.first, card);
    _entries[card.id] = card;
    final i = _decks.indexWhere((d) => d.id == deckId);
    if (i >= 0 && !_decks[i].cards.any((c) => c.id == card.id)) {
      final deck = _decks[i];
      _decks[i] = RecallDeck(
          id: deck.id, name: deck.name, cards: [...deck.cards, card]);
    }
    await _save();
  }

  Future<void> updateCard({
    required String deckId,
    required String cardId,
    required String front,
    required String meaning,
    required String example,
    String? imageData,
    String? termEnglish,
    String? abbreviation,
    String? symbol,
    String? formula,
    String? unit,
    String? source,
    List<String>? relatedTerms,
    List<String>? categoryNames,
    List<String>? categoryPaths,
    VocabularyType? vocabularyType,
    LearningPriority? learningPriority,
    String? priorityReason,
    InclusionRecommendation? inclusionRecommendation,
    String? collector,
    String? notes,
    List<String>? partOfSpeech,
    List<VocabularyMeaning>? meanings,
    List<VocabularySource>? sources,
    VerificationStatus? verificationStatus,
  }) async {
    final old = _entries[cardId];
    if (old == null) return;
    if (front.trim().isEmpty || meaning.trim().isEmpty) {
      throw ArgumentError('용어와 뜻이 필요합니다.');
    }
    var updated = old.copyWith(
        front: front.trim(),
        meaning: meaning.trim(),
        example: example.trim(),
        imageData: imageData,
        termEnglish: termEnglish?.trim(),
        abbreviation: abbreviation?.trim(),
        symbol: symbol?.trim(),
        formula: formula?.trim(),
        unit: unit?.trim(),
        source: source?.trim(),
        relatedTerms: relatedTerms,
        categoryIds: categoryNames == null && categoryPaths == null
            ? null
            : _categoryIdsForPaths([...?categoryNames, ...?categoryPaths]),
        vocabularyType: vocabularyType,
        learningPriority: learningPriority,
        priorityReason: priorityReason,
        inclusionRecommendation: inclusionRecommendation,
        collector: collector,
        notes: notes,
        partOfSpeech: partOfSpeech,
        meanings: meanings,
        sources: sources,
        verificationStatus: verificationStatus);
    if (meanings == null &&
        (meaning != old.meaning || example != old.example)) {
      updated = updated.copyWith(meanings: [
        VocabularyMeaning.fromJson({
          ...old.effectiveMeanings.first.toJson(),
          'meaning_ko': meaning,
          'example_sentence': example,
        }),
        ...old.effectiveMeanings.skip(1)
      ]);
    }
    if (vocabularyKey(updated) != vocabularyKey(old) &&
        _entries.values.any((c) =>
            c.id != cardId && vocabularyKey(c) == vocabularyKey(updated))) {
      throw ArgumentError('같은 영어 용어가 이미 있습니다. 기존 항목에 의미를 추가해 주세요.');
    }
    _entries[cardId] = updated;
    await _save();
  }

  Future<void> markReviewed(String id) async {
    _rollReviewDay();
    if (!_entries.containsKey(id)) return;
    _entries[id] = _entries[id]!.copyWith(lastReviewed: DateTime.now());
    _reviewsToday++;
    await _save();
  }

  Future<void> toggleBookmark(String id) async {
    final card = _entries[id];
    if (card == null) return;
    _entries[id] = card.copyWith(isBookmarked: !card.isBookmarked);
    await _save();
  }

  Future<void> toggleReviewExclusion(String id) async {
    final card = _entries[id];
    if (card == null) return;
    _entries[id] =
        card.copyWith(isExcludedFromReview: !card.isExcludedFromReview);
    await _save();
  }

  Future<void> completeTutorial() async {
    _tutorialCompleted = true;
    await _save();
  }

  Future<void> setDailyGoal(int value) async {
    _dailyGoal = value.clamp(1, 200);
    await _save();
  }

  Future<void> _save() {
    _allCardsCache = null;
    _searchText.clear();
    final encoded = jsonEncode({
      'schemaVersion': 3,
      'entries': _entries.values.map((c) => c.toJson()).toList(),
      'decks': _decks.map((d) => d.toJson()).toList(),
      'categories': _categories.map((c) => c.toJson()).toList(),
      'recentViews': [
        for (final v in _recentViews)
          {'cardId': v.cardId, 'viewedAt': v.viewedAt.toIso8601String()}
      ],
      'dailyGoal': _dailyGoal,
      'reviewsToday': _reviewsToday,
      'tutorialCompleted': _tutorialCompleted,
      'reviewDay': _reviewDay,
    });
    final save = _pendingSave.then((_) async {
      if (!await _preferences.setString(_dataKey, encoded)) {
        throw StateError('저장하지 못했습니다.');
      }
      if (hasListeners) notifyListeners();
    });
    _pendingSave = save.catchError((Object _) {});
    return save;
  }

  String _categoryDisplayName(String name, {String? parentId}) {
    final aliases = _subjectNames.entries
        .where((e) => e.key.toLowerCase() == name.trim().toLowerCase());
    return parentId == null && aliases.isNotEmpty
        ? aliases.first.value
        : name.trim();
  }

  RecallCategory _findOrCreateCategory(String name, {String? parentId}) {
    final display = _categoryDisplayName(name, parentId: parentId);
    for (final c in _categories) {
      if (c.name.toLowerCase() == display.toLowerCase() &&
          c.parentId == parentId) {
        return c;
      }
    }
    final category =
        RecallCategory(id: _newId(), name: display, parentId: parentId);
    _categories.add(category);
    return category;
  }

  List<String> _categoryIdsForPaths(List<String> paths) {
    final ids = <String>{};
    for (final path in paths) {
      String? parentId;
      for (final name
          in path.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        final category = _findOrCreateCategory(name, parentId: parentId);
        parentId = category.id;
        ids.add(category.id);
      }
    }
    return ids.toList();
  }

  bool _idExists(String id) =>
      _entries.containsKey(id) ||
      _decks.any((d) => d.id == id) ||
      _categories.any((c) => c.id == id);
  String _newId({Set<String>? reservedIds}) {
    String id;
    do {
      id = '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
    } while (_idExists(id) || (reservedIds?.contains(id) ?? false));
    reservedIds?.add(id);
    return id;
  }

  void _rollReviewDay() {
    final today = _dayKey(DateTime.now());
    if (_reviewDay != today) {
      _reviewDay = today;
      _reviewsToday = 0;
    }
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}
