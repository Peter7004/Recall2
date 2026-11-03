import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_learning.dart';
import 'reader_learning_guard.dart';
import 'reader_learning_guard_factory.dart';
export 'reader_learning_guard.dart' show ReaderLearningStorageException;

class _LearningSnapshot {
  const _LearningSnapshot(this.terms, this.sources, this.raw);
  final Map<String, ReaderSavedTerm> terms;
  final Map<String, ReaderOccurrence> sources;
  final String? raw;
}

/// Existing key/schema retained. Every mutation reloads inside a shared guard.
class ReaderLearningStore extends ChangeNotifier {
  ReaderLearningStore._(
      this._preferences, this._guard, _LearningSnapshot snapshot)
      : _terms = snapshot.terms,
        _occurrences = snapshot.sources,
        _lastRaw = snapshot.raw {
    _subscription = _guard.changes.listen((_) => _changedElsewhere());
  }
  static const storageKey = 'recall.reader.learning.v1';
  static const _maxRecords = 100000;
  static const _maxSnapshotLength = 32 * 1024 * 1024;
  final SharedPreferences _preferences;
  final LearningWriteGuard _guard;
  late final StreamSubscription<void> _subscription;
  Map<String, ReaderSavedTerm> _terms;
  Map<String, ReaderOccurrence> _occurrences;
  String? _lastRaw;
  String? _synchronizationError;
  bool _disposed = false, _refreshing = false, _refreshPending = false;
  String? get synchronizationError => _synchronizationError;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }

  static Future<ReaderLearningStore> load(
      {SharedPreferences? preferences, LearningWriteGuard? guard}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final coordinator = guard ?? learningWriteGuard;
    return coordinator.read(() async {
      await prefs.reload();
      return ReaderLearningStore._(
          prefs, coordinator, _decode(prefs.get(storageKey)));
    });
  }

  static _LearningSnapshot _decode(Object? raw) {
    final terms = <String, ReaderSavedTerm>{};
    final sources = <String, ReaderOccurrence>{};
    if (raw != null) {
      if (raw is! String || raw.length > _maxSnapshotLength) {
        throw const FormatException('Invalid Reader learning snapshot');
      }
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['version'] is! int ||
          json['version'] != 1) {
        throw const FormatException('Unsupported Reader learning snapshot');
      }
      final termList = json['terms'];
      final sourceList = json['occurrences'];
      if (termList is! List ||
          sourceList is! List ||
          termList.length > _maxRecords ||
          sourceList.length > _maxRecords) {
        throw const FormatException('Invalid Reader learning records');
      }
      for (final item in termList) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid saved term');
        }
        final term = ReaderSavedTerm.fromJson(item);
        if (terms.containsKey(term.cardId)) {
          throw const FormatException('Duplicate saved term');
        }
        terms[term.cardId] = term;
      }
      for (final item in sourceList) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid source');
        }
        final source = ReaderOccurrence.fromJson(item);
        if (!terms.containsKey(source.cardId) ||
            sources.containsKey(source.id)) {
          throw const FormatException('Orphaned or duplicate source');
        }
        sources[source.id] = source;
      }
    }
    return _LearningSnapshot(terms, sources, raw as String?);
  }

  List<ReaderSavedTerm> get terms => List.unmodifiable(_terms.values);
  List<ReaderOccurrence> occurrencesFor(String cardId, {String? documentId}) =>
      List.unmodifiable(_occurrences.values.where((o) =>
          o.cardId == cardId &&
          (documentId == null || o.documentId == documentId)));
  List<ReaderOccurrence> occurrencesForDocument(String documentId) =>
      List.unmodifiable(
          _occurrences.values.where((o) => o.documentId == documentId));

  void _publish(_LearningSnapshot snapshot) {
    final changed = _lastRaw != snapshot.raw || _synchronizationError != null;
    _terms = snapshot.terms;
    _occurrences = snapshot.sources;
    _lastRaw = snapshot.raw;
    _synchronizationError = null;
    if (changed && !_disposed) notifyListeners();
  }

  Future<void> _readLatest() async {
    await _preferences.reload();
    _publish(_decode(_preferences.get(storageKey)));
  }

  Future<void> refresh() => _guard.read(() async {
        if (!_disposed) await _readLatest();
      });

  void _changedElsewhere() {
    if (_disposed) return;
    _refreshPending = true;
    if (!_refreshing) {
      _refreshing = true;
      unawaited(_drainChanges());
    }
  }

  Future<void> _drainChanges() async {
    try {
      while (_refreshPending && !_disposed) {
        _refreshPending = false;
        try {
          await refresh();
        } catch (_) {
          if (!_disposed && _synchronizationError == null) {
            _synchronizationError =
                '다른 화면에서 변경된 학습 기록을 읽지 못했습니다. 기존 기록은 변경하지 않았습니다.';
            notifyListeners();
          }
        }
      }
    } finally {
      _refreshing = false;
      if (_refreshPending && !_disposed) _changedElsewhere();
    }
  }

  Future<void> save(ReaderSavedTerm term, List<ReaderOccurrence> sources) {
    final input = List<ReaderOccurrence>.of(sources);
    return _guard.exclusive(() async {
      await _readLatest();
      if (input.isEmpty) {
        throw const FormatException('At least one source is required');
      }
      final nextTerms = Map<String, ReaderSavedTerm>.of(_terms);
      final nextSources = Map<String, ReaderOccurrence>.of(_occurrences);
      final old = nextTerms[term.cardId];
      nextTerms[term.cardId] = ReaderSavedTerm.fromJson({
        ...term.toJson(),
        if (old != null) 'createdAt': old.createdAt.toIso8601String(),
      });
      for (final source in input) {
        if (source.cardId != term.cardId) {
          throw const FormatException('Source belongs to a different term');
        }
        nextSources[source.id] = ReaderOccurrence.fromJson({
          ...source.toJson(),
          if (nextSources[source.id] case final old?)
            'createdAt': old.createdAt.toIso8601String(),
        });
      }
      await _persist(nextTerms, nextSources);
    });
  }

  Future<void> removeTerm(String cardId) => _guard.exclusive(() async {
        await _readLatest();
        if (!_terms.containsKey(cardId)) return;
        final terms = Map<String, ReaderSavedTerm>.of(_terms)..remove(cardId);
        final sources = Map<String, ReaderOccurrence>.of(_occurrences)
          ..removeWhere((_, o) => o.cardId == cardId);
        await _persist(terms, sources);
      });

  Future<void> _persist(Map<String, ReaderSavedTerm> terms,
      Map<String, ReaderOccurrence> sources) async {
    if (terms.length > _maxRecords || sources.length > _maxRecords) {
      throw StateError('Reader learning record limit reached');
    }
    final snapshot = jsonEncode({
      'version': 1,
      'terms': terms.values.map((t) => t.toJson()).toList(),
      'occurrences': sources.values.map((o) => o.toJson()).toList()
    });
    if (snapshot.length > _maxSnapshotLength) {
      throw StateError('Reader learning snapshot limit reached');
    }
    try {
      if (!await _preferences.setString(storageKey, snapshot)) {
        throw StateError('Reader learning snapshot could not be saved');
      }
    } catch (_) {
      try {
        await _readLatest();
      } catch (_) {/* Preserve original save failure. */}
      rethrow;
    }
    _publish(_LearningSnapshot(terms, sources, snapshot));
    _guard.didChange();
  }
}
