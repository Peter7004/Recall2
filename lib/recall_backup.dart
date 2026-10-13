import 'dart:convert';

import 'vocabulary.dart';

/// A versioned, fully validated snapshot; parsing never changes live data.
class RecallBackup {
  RecallBackup._(this._encoded, this.entryCount, this.deckCount);

  static const maxBytes = 64 * 1024 * 1024;
  final String _encoded;
  final int entryCount;
  final int deckCount;
  Map<String, dynamic> get snapshot =>
      jsonDecode(_encoded) as Map<String, dynamic>;

  static String encode(Map<String, Object?> snapshot) => jsonEncode({
        'format': 'recall.backup',
        'backupVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'data': snapshot,
      });

  static RecallBackup parse(String text) {
    try {
      if (utf8.encode(text).length > maxBytes) _invalid();
      final envelope = _map(jsonDecode(text));
      if (envelope['format'] != 'recall.backup' ||
          envelope['backupVersion'] != 1) {
        throw const FormatException('지원하지 않는 Recall 백업 버전입니다.');
      }
      _date(envelope['createdAt']);
      final data = _map(envelope['data']);
      if (data['schemaVersion'] != 3 || data['subjectSettingsVersion'] != 1) {
        throw const FormatException('이 백업은 현재 앱 버전과 호환되지 않습니다.');
      }
      final entries = _objects(data['entries']);
      final decks = _objects(data['decks']);
      final categories = _objects(data['categories']);
      final visits = _objects(data['recentViews']);
      final cardShape = RecallCard(
        id: '',
        front: '',
        meaning: '',
        example: '',
        dueAt: DateTime(2000),
        intervalMinutes: 0,
        stabilityDays: 0,
        ease: 0,
        lastReviewed: null,
      ).toJson();
      cardShape['meanings'] = [
        const VocabularyMeaning(id: '', meaningKo: '').toJson()
      ];
      cardShape['sources'] = [const VocabularySource().toJson()];
      final ids = <String>{};
      final categoryIds = <String>{};
      for (final category in categories) {
        _shape(category, const RecallCategory(id: '', name: '').toJson());
        _id(category['id'], categoryIds);
        _nonempty(category['name']);
      }
      final parents = {
        for (final c in categories) c['id'] as String: c['parentId'] as String?
      };
      for (final id in categoryIds) {
        final seen = <String>{};
        String? current = id;
        while (current != null) {
          if (!categoryIds.contains(current) || !seen.add(current)) _invalid();
          current = parents[current];
        }
      }
      for (final entry in entries) {
        _shape(entry, cardShape);
        _id(entry['id'], ids);
        _nonempty(entry['front']);
        _nonempty(entry['meaning']);
        _date(entry['dueAt']);
        if (entry['lastReviewed'] != null) _date(entry['lastReviewed']);
        _enum(entry['vocabulary_type'],
            VocabularyType.values.map((v) => v.value));
        _enum(entry['learning_priority'],
            LearningPriority.values.map((v) => v.value));
        _enum(entry['inclusion_recommendation'],
            InclusionRecommendation.values.map((v) => v.value));
        _enum(entry['verification_status'],
            VerificationStatus.values.map((v) => v.value));
        if (!(entry['categoryIds'] as List).every(categoryIds.contains)) {
          _invalid();
        }
        final meaningIds = <String>{};
        for (final meaning in _objects(entry['meanings'])) {
          _id(meaning['id'], meaningIds);
          _enum(
              meaning['meaning_type'], MeaningType.values.map((v) => v.value));
        }
        RecallCard.fromJson(entry);
      }
      final deckIds = <String>{};
      for (final deck in decks) {
        _shape(deck, {'id': '', 'name': '', 'entryIds': <String>[]});
        _id(deck['id'], deckIds);
        _nonempty(deck['name']);
        final members = deck['entryIds'] as List;
        if (!members.every(ids.contains) ||
            members.toSet().length != members.length) {
          _invalid();
        }
      }
      if (visits.length > 20) _invalid();
      final visitedIds = <String>{};
      for (final visit in visits) {
        _shape(visit, {'cardId': '', 'viewedAt': ''});
        _id(visit['cardId'], visitedIds);
        if (!ids.contains(visit['cardId'])) _invalid();
        _date(visit['viewedAt']);
      }
      if (data['dailyGoal'] is! int ||
          (data['dailyGoal'] as int) < 1 ||
          (data['dailyGoal'] as int) > 200 ||
          data['reviewsToday'] is! int ||
          (data['reviewsToday'] as int) < 0 ||
          data['tutorialCompleted'] is! bool ||
          data['reviewDay'] is! String ||
          !RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$')
              .hasMatch(data['reviewDay'] as String)) {
        _invalid();
      }
      const keys = {
        'schemaVersion',
        'subjectSettingsVersion',
        'entries',
        'decks',
        'categories',
        'recentViews',
        'dailyGoal',
        'reviewsToday',
        'tutorialCompleted',
        'reviewDay'
      };
      final allowedKeys = {...keys, 'bundledVocabularyVersion'};
      if (data.keys.toSet().difference(allowedKeys).isNotEmpty ||
          keys.difference(data.keys.toSet()).isNotEmpty) {
        _invalid();
      }
      final catalogVersion = data.containsKey('bundledVocabularyVersion')
          ? data['bundledVocabularyVersion']
          : 0;
      if (catalogVersion is! int || catalogVersion < 0) _invalid();
      data['bundledVocabularyVersion'] = catalogVersion;
      return RecallBackup._(jsonEncode(data), entries.length, decks.length);
    } on FormatException {
      rethrow;
    } catch (_) {
      _invalid();
    }
  }

  static Never _invalid() => throw const FormatException(
      '손상되었거나 올바르지 않은 백업 파일입니다. 기존 데이터는 변경되지 않았습니다.');
  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) _invalid();
    return value;
  }

  static List<Map<String, dynamic>> _objects(Object? value) {
    if (value is! List) _invalid();
    return value.map(_map).toList();
  }

  static void _nonempty(Object? value) {
    if (value is! String || value.trim().isEmpty) _invalid();
  }

  static void _id(Object? value, Set<String> ids) {
    _nonempty(value);
    if (!ids.add(value as String)) _invalid();
  }

  static void _date(Object? value) {
    if (value is! String || DateTime.tryParse(value) == null) _invalid();
  }

  static void _enum(Object? value, Iterable<String> values) {
    if (!values.contains(value)) _invalid();
  }

  static void _shape(Map<String, dynamic> value, Map<String, Object?> shape) {
    if (value.length != shape.length ||
        value.keys.any((k) => !shape.containsKey(k))) {
      _invalid();
    }
    for (final field in shape.entries) {
      final item = value[field.key];
      final sample = field.value;
      if (sample == null) {
        if (item != null && item is! String) _invalid();
      } else if (sample is String) {
        if (item is! String) _invalid();
      } else if (sample is bool) {
        if (item is! bool) _invalid();
      } else if (sample is int) {
        if (item is! int) _invalid();
      } else if (sample is num) {
        if (item is! num || !item.isFinite) _invalid();
      } else if (sample is List) {
        if (item is! List) _invalid();
        if (sample.isEmpty) {
          if (item.any((v) => v is! String)) _invalid();
        } else {
          for (final v in item) {
            _shape(_map(v), sample.first as Map<String, Object?>);
          }
        }
      } else if (sample is Map) {
        if (_map(item).values.any((v) => v is! String)) _invalid();
      }
    }
  }
}
