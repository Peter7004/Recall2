import 'package:flutter/services.dart';

import 'csv_import.dart';

class BundledVocabulary {
  factory BundledVocabulary({required int version, required String csvText}) {
    final preview = parseVocabularyCsv(csvText);
    if (version < 1 || preview.rows.isEmpty || preview.errors.isNotEmpty) {
      throw FormatException(
          '기본 단어 데이터를 읽을 수 없습니다: ${preview.errors.join('; ')}');
    }
    return BundledVocabulary._(version, List.unmodifiable(preview.rows));
  }
  const BundledVocabulary._(this.version, this.rows);

  static const currentVersion = 1;
  static const assetPath = 'assets/vocabulary/recall_core_v1.csv';
  static const deckId = 'recall-builtin-deck';
  static const deckName = '기본 전공 용어';
  final int version;
  final List<CsvVocabularyRow> rows;

  static Future<BundledVocabulary> load() async => BundledVocabulary(
      version: currentVersion, csvText: await rootBundle.loadString(assetPath));
}
