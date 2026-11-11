import 'package:csv/csv.dart';

String normalizeCorpusTerm(String term) =>
    term.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

const corpusColumns = [
  'term_en',
  'textbook_tf',
  'textbook_df',
  'abstract_tf',
  'abstract_df'
];

enum CorpusSource {
  textbook('교재·강의자료'),
  abstracts('논문 초록');

  const CorpusSource(this.label);
  final String label;
}

enum CorpusScope {
  all('전체'),
  both('두 자료 공통 관측'),
  textbook('교재·강의자료에서 관측'),
  abstracts('논문 초록에서 관측'),
  unobserved('미관측'),
  textbookOnly('교재·강의자료에서만 관측'),
  abstractOnly('논문 초록에서만 관측');

  const CorpusScope(this.label);
  final String label;
}

class CorpusStats {
  const CorpusStats(this.term, this.textbookTf, this.textbookDf,
      this.abstractTf, this.abstractDf);
  final String term;
  final int textbookTf, textbookDf, abstractTf, abstractDf;
  CorpusScope get observation => textbookDf > 0
      ? (abstractDf > 0 ? CorpusScope.both : CorpusScope.textbookOnly)
      : (abstractDf > 0 ? CorpusScope.abstractOnly : CorpusScope.unobserved);
  bool matches(CorpusScope scope) => switch (scope) {
        CorpusScope.all => true,
        CorpusScope.textbook => textbookDf > 0,
        CorpusScope.abstracts => abstractDf > 0,
        _ => observation == scope,
      };
  int df(CorpusSource source) =>
      source == CorpusSource.textbook ? textbookDf : abstractDf;
  int tf(CorpusSource source) =>
      source == CorpusSource.textbook ? textbookTf : abstractTf;
}

/// Immutable sidecar data. Never serialized into the vocabulary or Reader stores.
class CorpusCatalog {
  const CorpusCatalog.empty()
      : records = const {},
        errors = const [];
  CorpusCatalog._(Map<String, CorpusStats> records, List<String> errors)
      : records = Map.unmodifiable(records),
        errors = List.unmodifiable(errors);
  factory CorpusCatalog.unavailable(String reason) =>
      CorpusCatalog._({}, [reason]);
  final Map<String, CorpusStats> records;
  final List<String> errors;
  bool get available => errors.isEmpty && records.isNotEmpty;
  CorpusStats? forTerm(String term) =>
      available ? records[normalizeCorpusTerm(term)] : null;

  factory CorpusCatalog.parse(String input) {
    final errors = <String>[];
    final records = <String, CorpusStats>{};
    List<List<dynamic>> rows;
    try {
      rows = const CsvToListConverter(
              shouldParseNumbers: false, allowInvalid: false, eol: '\n')
          .convert(input
              .replaceFirst(RegExp(r'^\uFEFF'), '')
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n'));
    } catch (_) {
      return CorpusCatalog.unavailable('CSV 형식 오류: 따옴표와 쉼표 구분을 확인하세요.');
    }
    if (rows.isEmpty ||
        rows.first.length != corpusColumns.length ||
        List.generate(corpusColumns.length,
                (i) => rows.first[i].toString().trim()).join(',') !=
            corpusColumns.join(',')) {
      return CorpusCatalog.unavailable(
          '헤더는 ${corpusColumns.join(",")} 순서여야 합니다.');
    }
    final seen = <String>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length == 1 && row.single.toString().trim().isEmpty) continue;
      if (row.length != 5) {
        errors.add('${i + 1}행: 열 수는 5개여야 합니다.');
        continue;
      }
      final term = row[0].toString().trim();
      final key = normalizeCorpusTerm(term);
      if (key.isEmpty) {
        errors.add('${i + 1}행: term_en 누락');
        continue;
      }
      if (!seen.add(key)) {
        errors.add('${i + 1}행: 중복 용어 "$term"');
        continue;
      }
      final values = row.skip(1).map((v) {
        final s = v.toString().trim();
        final n = RegExp(r'^\d+$').hasMatch(s) ? int.tryParse(s) : null;
        return n != null && n <= 9007199254740991 ? n : null;
      }).toList();
      if (values.any((n) => n == null)) {
        errors.add('${i + 1}행: TF/DF는 누락 없는 0 이상의 안전한 정수여야 합니다.');
        continue;
      }
      final v = values.cast<int>();
      if (v[1] > v[0] ||
          v[3] > v[2] ||
          (v[0] == 0) != (v[1] == 0) ||
          (v[2] == 0) != (v[3] == 0)) {
        errors.add('${i + 1}행: DF ≤ TF이며 TF와 DF의 관측 여부가 같아야 합니다.');
        continue;
      }
      records[key] = CorpusStats(term, v[0], v[1], v[2], v[3]);
    }
    // Invalid files are disabled as a whole, never treated as partial research data.
    return CorpusCatalog._(errors.isEmpty ? records : {}, errors);
  }

  List<T> select<T>(Iterable<T> entries, String Function(T) term,
      {CorpusScope scope = CorpusScope.all, CorpusSource? source}) {
    if (!available) return List.of(entries);
    final result = entries
        .where((e) =>
            scope == CorpusScope.all ||
            (forTerm(term(e))?.matches(scope) ?? false))
        .toList();
    if (source != null) {
      result.sort((a, b) {
        final x = forTerm(term(a)), y = forTerm(term(b));
        if (x == null && y != null) return 1;
        if (y == null && x != null) return -1;
        if (x != null && y != null) {
          final df = y.df(source).compareTo(x.df(source));
          if (df != 0) return df;
          final tf = y.tf(source).compareTo(x.tf(source));
          if (tf != 0) return tf;
        }
        return normalizeCorpusTerm(term(a))
            .compareTo(normalizeCorpusTerm(term(b)));
      });
    }
    return result;
  }

  Map<String, Object> diagnose(Iterable<String> dictionaryTerms) {
    final counts = <String, int>{};
    for (final term in dictionaryTerms) {
      final key = normalizeCorpusTerm(term);
      if (key.isNotEmpty) counts.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    return {
      'available': available,
      'errors': errors,
      'statisticsTerms': records.length,
      'dictionaryUniqueTerms': counts.length,
      'matched': records.keys.where(counts.containsKey).length,
      'unmatchedStatistics':
          records.keys.where((k) => !counts.containsKey(k)).toList(),
      'missingStatistics':
          counts.keys.where((k) => !records.containsKey(k)).toList(),
      'duplicateDictionaryTerms':
          counts.keys.where((k) => counts[k]! > 1).toList(),
      'categories': {
        for (final scope in [
          CorpusScope.both,
          CorpusScope.textbookOnly,
          CorpusScope.abstractOnly,
          CorpusScope.unobserved
        ])
          scope.name: records.values.where((s) => s.observation == scope).length
      },
    };
  }

  List<String> verifyResearch(Iterable<String> dictionaryTerms) {
    final report = diagnose(dictionaryTerms);
    final result = <String>[...errors];
    if (records.length != 834 ||
        report['dictionaryUniqueTerms'] != 834 ||
        report['matched'] != 834 ||
        (report['duplicateDictionaryTerms'] as List).isNotEmpty) {
      result.add('연구 검증에는 중복 없는 사전 834개와 통계 834개의 완전 일치가 필요합니다.');
    }
    const expected = {
      'both': 210,
      'textbookOnly': 276,
      'abstractOnly': 45,
      'unobserved': 303
    };
    final categories = report['categories'] as Map;
    for (final entry in expected.entries) {
      if (categories[entry.key] != entry.value) {
        result.add(
            '${entry.key}: 기대 ${entry.value}, 실제 ${categories[entry.key]}');
      }
    }
    return result;
  }
}
