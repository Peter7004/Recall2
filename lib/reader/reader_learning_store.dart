import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_learning.dart';

/// Separate, single-snapshot storage. PDF deletion does not affect this store.
class ReaderLearningStore extends ChangeNotifier {
  ReaderLearningStore._(this._preferences, this._terms, this._occurrences);

  static const storageKey = 'recall.reader.learning.v1';
  static const _maxRecords = 100000;
  static const _maxSnapshotLength = 32 * 1024 * 1024;
  final SharedPreferences _preferences;
  Map<String, ReaderSavedTerm> _terms;
  Map<String, ReaderOccurrence> _occurrences;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<ReaderLearningStore> load(
      {SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.get(storageKey);
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
    return ReaderLearningStore._(prefs, terms, sources);
  }

  List<ReaderSavedTerm> get terms => List.unmodifiable(_terms.values);

  List<ReaderOccurrence> occurrencesFor(String cardId, {String? documentId}) =>
      List.unmodifiable(_occurrences.values.where((o) =>
          o.cardId == cardId &&
          (documentId == null || o.documentId == documentId)));

  List<ReaderOccurrence> occurrencesForDocument(String documentId) =>
      List.unmodifiable(
          _occurrences.values.where((o) => o.documentId == documentId));

  Future<void> _serial(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> save(ReaderSavedTerm term, List<ReaderOccurrence> sources) {
    // Snapshot caller-owned collections before entering the asynchronous queue.
    final input = List<ReaderOccurrence>.of(sources);
    return _serial(() async {
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

  Future<void> removeTerm(String cardId) => _serial(() async {
        if (!_terms.containsKey(cardId)) return;
        final terms = Map<String, ReaderSavedTerm>.of(_terms)..remove(cardId);
        final sources = Map<String, ReaderOccurrence>.of(_occurrences)
          ..removeWhere((_, source) => source.cardId == cardId);
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
      'occurrences': sources.values.map((s) => s.toJson()).toList(),
    });
    if (snapshot.length > _maxSnapshotLength) {
      throw StateError('Reader learning snapshot limit reached');
    }
    try {
      if (!await _preferences.setString(storageKey, snapshot)) {
        throw StateError('Reader learning snapshot could not be saved');
      }
    } catch (_) {
      // Legacy SharedPreferences updates its cache before platform success.
      // Refresh from durable storage without writing a rollback snapshot.
      try {
        await _preferences.reload();
      } catch (_) {/* Preserve save error. */}
      rethrow;
    }
    _terms = terms;
    _occurrences = sources;
    if (!_disposed) notifyListeners();
  }
}
