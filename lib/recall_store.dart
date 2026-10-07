import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecallCard {
  const RecallCard({
    required this.id,
    required this.front,
    required this.meaning,
    required this.example,
    required this.dueAt,
    required this.intervalMinutes,
    required this.stabilityDays,
    required this.ease,
    required this.lastReviewed,
    this.isBookmarked = false,
    this.isExcludedFromReview = false,
    this.imageData,
  });

  final String id;
  final String front;
  final String meaning;
  final String example;
  final DateTime dueAt;
  final int intervalMinutes;
  final double stabilityDays;
  final double ease;
  final DateTime? lastReviewed;
  final bool isBookmarked;
  final bool isExcludedFromReview;
  final String? imageData;

  Map<String, Object?> toJson() => {
        'id': id,
        'front': front,
        'meaning': meaning,
        'example': example,
        'dueAt': dueAt.toIso8601String(),
        'intervalMinutes': intervalMinutes,
        'stabilityDays': stabilityDays,
        'ease': ease,
        'lastReviewed': lastReviewed?.toIso8601String(),
        'isBookmarked': isBookmarked,
        'isExcludedFromReview': isExcludedFromReview,
        'imageData': imageData,
      };

  factory RecallCard.fromJson(Map<String, Object?> json) => RecallCard(
        id: json['id']! as String,
        front: json['front']! as String,
        meaning: json['meaning']! as String,
        example: json['example'] as String? ?? '',
        dueAt:
            DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
        intervalMinutes: json['intervalMinutes'] as int? ?? 0,
        stabilityDays: (json['stabilityDays'] as num?)?.toDouble() ?? 2.1,
        ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
        lastReviewed: DateTime.tryParse(json['lastReviewed'] as String? ?? ''),
        isBookmarked: json['isBookmarked'] as bool? ?? false,
        isExcludedFromReview:
          json['isExcludedFromReview'] as bool? ?? false,
        imageData: json['imageData'] as String?,
      );

  RecallCard copyWith({
    String? id,
    String? front,
    String? meaning,
    String? example,
    DateTime? dueAt,
    int? intervalMinutes,
    double? stabilityDays,
    double? ease,
    DateTime? lastReviewed,
    bool? isBookmarked,
    bool? isExcludedFromReview,
    String? imageData,
  }) =>
      RecallCard(
        id: id ?? this.id,
        front: front ?? this.front,
        meaning: meaning ?? this.meaning,
        example: example ?? this.example,
        dueAt: dueAt ?? this.dueAt,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        stabilityDays: stabilityDays ?? this.stabilityDays,
        ease: ease ?? this.ease,
        lastReviewed: lastReviewed ?? this.lastReviewed,
        isBookmarked: isBookmarked ?? this.isBookmarked,
        isExcludedFromReview:
          isExcludedFromReview ?? this.isExcludedFromReview,
        imageData: imageData == null
            ? this.imageData
            : imageData.isEmpty
                ? null
                : imageData,
      );
}

class RecallDeck {
  const RecallDeck({required this.id, required this.name, required this.cards});

  final String id;
  final String name;
  final List<RecallCard> cards;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'cards': cards.map((card) => card.toJson()).toList(),
      };

  factory RecallDeck.fromJson(Map<String, Object?> json) => RecallDeck(
        id: json['id']! as String,
        name: json['name']! as String,
        cards: (json['cards'] as List<Object?>? ?? const [])
            .map((card) => RecallCard.fromJson(card! as Map<String, Object?>))
            .toList(),
      );
}

class RecallStore extends ChangeNotifier {
  RecallStore._(this._preferences);

  static const _dataKey = 'recall.data.v1';
  static int _idSequence = 0;
  final SharedPreferences _preferences;
  List<RecallDeck> _decks = [];
  int _dailyGoal = 24;
  int _reviewsToday = 0;
  bool _tutorialCompleted = false;
  String _reviewDay = _dayKey(DateTime.now());

  static Future<RecallStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    final store = RecallStore._(preferences);
    final encoded = preferences.getString(_dataKey);
    if (encoded != null) {
      try {
        final json = jsonDecode(encoded) as Map<String, Object?>;
        store._decks = (json['decks'] as List<Object?>? ?? const [])
            .map((deck) => RecallDeck.fromJson(deck! as Map<String, Object?>))
            .toList();
        store._dailyGoal = json['dailyGoal'] as int? ?? 24;
        store._reviewsToday = json['reviewsToday'] as int? ?? 0;
        store._tutorialCompleted = json['tutorialCompleted'] as bool? ?? false;
        store._reviewDay =
            json['reviewDay'] as String? ?? _dayKey(DateTime.now());
      } on Object {
        store._decks = [];
      }
    }
    store._repairDuplicateIds();
    store._rollReviewDay();
    return store;
  }

  List<RecallDeck> get decks => List.unmodifiable(_decks);
  int get dailyGoal => _dailyGoal;
  int get reviewsToday => _reviewsToday;
  bool get tutorialCompleted => _tutorialCompleted;
  int get totalCards => _decks.expand((deck) => deck.cards).length;
  int get dueCount => dueCards.length;
  int get remainingToday =>
      math.min(dueCount, math.max(0, _dailyGoal - _reviewsToday)).toInt();

  RecallDeck? deckById(String id) {
    for (final deck in _decks) {
      if (deck.id == id) return deck;
    }
    return null;
  }

  List<({RecallDeck deck, RecallCard card})> get dueCards => [
        for (final deck in _decks)
          for (final card in deck.cards)
            if (!card.isExcludedFromReview) (deck: deck, card: card),
      ]..sort((a, b) =>
          a.card.front.toLowerCase().compareTo(b.card.front.toLowerCase()));

  List<({RecallDeck deck, RecallCard card})> get bookmarkedCards => [
        for (final deck in _decks)
          for (final card in deck.cards)
            if (card.isBookmarked) (deck: deck, card: card),
      ];

  Future<int> importCsvDeck({
    required String csvText,
    String? deckName,
  }) async {
    final rows = _parseCsvRows(csvText);
    if (rows.isEmpty) return 0;

    final cards = <RecallCard>[];
    final generatedIds = <String>{};
    for (final row in rows) {
      final front = row.elementAtOrNull(0)?.trim() ?? '';
      final meaning = row.elementAtOrNull(1)?.trim() ?? '';
      if (front.isEmpty || meaning.isEmpty) continue;
      final example = row.length > 2 ? row[2].trim() : '';
      cards.add(
        RecallCard(
          id: _newId(reservedIds: generatedIds),
          front: front,
          meaning: meaning,
          example: example,
          dueAt: DateTime.now(),
          intervalMinutes: 0,
          stabilityDays: 2.1,
          ease: 2.5,
          lastReviewed: null,
        ),
      );
    }

    if (cards.isEmpty) return 0;

    final name = (deckName ?? 'Imported deck').trim();
    _decks = [
      ..._decks,
      RecallDeck(
          id: _newId(reservedIds: generatedIds),
          name: name.isEmpty ? 'Imported deck' : name,
          cards: cards),
    ];
    await _save();
    return cards.length;
  }

  Future<void> createDeck(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _decks = [
      ..._decks,
      RecallDeck(id: _newId(), name: trimmed, cards: const [])
    ];
    await _save();
  }

  Future<void> updateDeckName(String deckId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _decks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return;
    final deck = _decks[index];
    _replaceDeck(
      index, RecallDeck(id: deck.id, name: trimmed, cards: deck.cards));
    await _save();
  }

  Future<void> deleteCard({
    required String deckId,
    required String cardId,
  }) async {
    final index = _decks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return;
    final deck = _decks[index];
    final cards = deck.cards.where((card) => card.id != cardId).toList();
    if (cards.length == deck.cards.length) return;
    _replaceDeck(index, RecallDeck(id: deck.id, name: deck.name, cards: cards));
    await _save();
  }

  Future<void> addCard({
    required String deckId,
    required String front,
    required String meaning,
    required String example,
    String? imageData,
  }) async {
    final index = _decks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return;
    final deck = _decks[index];
    final card = RecallCard(
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
    );
    _replaceDeck(index,
        RecallDeck(id: deck.id, name: deck.name, cards: [...deck.cards, card]));
    await _save();
  }

  Future<void> updateCard({
    required String deckId,
    required String cardId,
    required String front,
    required String meaning,
    required String example,
    String? imageData,
  }) async {
    final index = _decks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return;
    final deck = _decks[index];
    final cards = deck.cards
        .map((card) => card.id == cardId
            ? card.copyWith(
                front: front.trim(),
                meaning: meaning.trim(),
                example: example.trim(),
                imageData: imageData,
              )
            : card)
        .toList();
    _replaceDeck(index, RecallDeck(id: deck.id, name: deck.name, cards: cards));
    await _save();
  }

  Future<void> markReviewed(String cardId) async {
    _rollReviewDay();
    final cardExists = _decks.any(
      (deck) => deck.cards.any((card) => card.id == cardId),
    );
    if (!cardExists) return;
    _reviewsToday++;
    await _save();
  }

  Future<void> toggleBookmark(String cardId) async {
    for (var deckIndex = 0; deckIndex < _decks.length; deckIndex++) {
      final deck = _decks[deckIndex];
      final cardIndex = deck.cards.indexWhere((card) => card.id == cardId);
      if (cardIndex == -1) continue;
      final cards = [...deck.cards];
      cards[cardIndex] = cards[cardIndex].copyWith(
        isBookmarked: !cards[cardIndex].isBookmarked,
      );
      _replaceDeck(
          deckIndex, RecallDeck(id: deck.id, name: deck.name, cards: cards));
      await _save();
      return;
    }
  }

  Future<void> toggleReviewExclusion(String cardId) async {
    for (var deckIndex = 0; deckIndex < _decks.length; deckIndex++) {
      final deck = _decks[deckIndex];
      final cardIndex = deck.cards.indexWhere((card) => card.id == cardId);
      if (cardIndex == -1) continue;
      final cards = [...deck.cards];
      cards[cardIndex] = cards[cardIndex].copyWith(
        isExcludedFromReview: !cards[cardIndex].isExcludedFromReview,
      );
      _replaceDeck(
          deckIndex, RecallDeck(id: deck.id, name: deck.name, cards: cards));
      await _save();
      return;
    }
  }

  Future<void> completeTutorial() async {
    if (_tutorialCompleted) return;
    _tutorialCompleted = true;
    await _save();
  }

  Future<void> setDailyGoal(int value) async {
    _dailyGoal = value.clamp(1, 200).toInt();
    await _save();
  }

  Future<void> _save() async {
    await _preferences.setString(
        _dataKey,
        jsonEncode({
          'decks': _decks.map((deck) => deck.toJson()).toList(),
          'dailyGoal': _dailyGoal,
          'reviewsToday': _reviewsToday,
          'tutorialCompleted': _tutorialCompleted,
          'reviewDay': _reviewDay,
        }));
    notifyListeners();
  }

  List<List<String>> _parseCsvRows(String csvText) {
    final normalized = csvText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = const LineSplitter().convert(normalized);
    final rows = <List<String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      rows.add(_parseCsvLine(trimmed));
    }

    if (rows.isEmpty) return const [];

    final header = rows.first
        .map((value) => value
            .replaceFirst('\uFEFF', '')
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[\s_()\-]'), ''))
        .toList(growable: false);
    const frontHeaders = {
      'front',
      'word',
      'term',
      'vocabulary',
      '단어',
      '영어단어',
      '영단어',
      '앞면',
      '질문',
      '표제어',
    };
    const meaningHeaders = {
      'meaning',
      'definition',
      'back',
      'translation',
      '뜻',
      '의미',
      '해석',
      '번역',
      '뒷면',
      '정의',
      '답',
    };
    final hasHeader =
      header.any(frontHeaders.contains) &&
          header.any(meaningHeaders.contains);

    return hasHeader ? rows.sublist(1) : rows;
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < line.length; index++) {
      final ch = line[index];
      if (ch == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }

    cells.add(buffer.toString());
    return cells;
  }

  void _replaceDeck(int index, RecallDeck deck) {
    final decks = [..._decks];
    decks[index] = deck;
    _decks = decks;
  }

  void _repairDuplicateIds() {
    final usedIds = <String>{};
    _decks = _decks.map((deck) {
      final deckId =
          usedIds.add(deck.id) ? deck.id : _newId(reservedIds: usedIds);
      final cards = deck.cards.map((card) {
        final cardId =
            usedIds.add(card.id) ? card.id : _newId(reservedIds: usedIds);
        return cardId == card.id ? card : card.copyWith(id: cardId);
      }).toList();
      return RecallDeck(id: deckId, name: deck.name, cards: cards);
    }).toList();
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
  String _newId({Set<String>? reservedIds}) {
    final usedIds = <String>{
      ...?reservedIds,
      for (final deck in _decks) deck.id,
      for (final deck in _decks)
        for (final card in deck.cards) card.id,
    };
    String id;
    do {
      id = '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
    } while (usedIds.contains(id));
    reservedIds?.add(id);
    return id;
  }
}
