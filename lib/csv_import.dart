import 'package:csv/csv.dart';

import 'vocabulary.dart';

class CsvVocabularyRow {
  const CsvVocabularyRow(this.number, this.card, this.subjectPaths,
      {this.suppliedFields = const {}});
  final int number;
  final RecallCard card;
  final List<String> subjectPaths;
  final Set<String> suppliedFields;
}

const recallV3Columns = [
  'term_en',
  'vocabulary_type',
  'primary_meaning_ko',
  'part_of_speech',
  'subject',
  'definition_en',
  'explanation_ko',
  'learning_priority',
  'priority_reason',
  'inclusion_recommendation',
  'collector',
  'source_title',
  'notes',
];

class CsvImportPreview {
  const CsvImportPreview({
    this.rows = const [],
    this.errors = const [],
    this.unknownHeaders = const [],
    this.newEntryCount = 0,
    this.existingEntryCount = 0,
    this.duplicateCount = 0,
  });
  final List<CsvVocabularyRow> rows;
  final List<String> errors;
  final List<String> unknownHeaders;
  final int newEntryCount;
  final int existingEntryCount;
  final int duplicateCount;
  int get entryCount => newEntryCount + existingEntryCount;
}

class CsvImportReport {
  const CsvImportReport({
    required this.importedCount,
    required this.duplicateCount,
    required this.invalidRowCount,
    this.linkedCount = 0,
    this.errors = const [],
    this.unknownHeaders = const [],
  });
  final int importedCount;
  final int duplicateCount;
  final int invalidRowCount;
  final int linkedCount;
  final List<String> errors;
  final List<String> unknownHeaders;
}

List<String> splitVocabularyList(String value) => value
    .split(RegExp(r'[;|\n]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toSet()
    .toList();

String vocabularyKey(RecallCard card) => card.displayTerm.trim().toLowerCase();

String _headerKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_()\-]'), '');

const _aliases = <String, List<String>>{
  'id': ['id'],
  'termKo': ['termko', 'korean', 'koreanterm', '단어', '용어', '한글용어'],
  'termEn': [
    'termen',
    'english',
    'englishterm',
    'front',
    'word',
    'term',
    'vocabulary',
    '영어단어',
    '영단어',
    '앞면',
    '질문',
    '표제어'
  ],
  'meaning': [
    'primarymeaningko',
    'meaningko',
    'meaning',
    'back',
    'translation',
    '뜻',
    '의미',
    '해석',
    '번역',
    '뒷면'
  ],
  'definition': ['definitionen', 'definition', '정의'],
  'explanation': ['explanationko', 'explanation', '설명'],
  'priority': ['learningpriority'],
  'priorityReason': ['priorityreason'],
  'inclusion': ['inclusionrecommendation'],
  'collector': ['collector'],
  'notes': ['notes'],
  'example': ['examplesentence', 'example', 'sentence', '예문', '예시'],
  'exampleTranslation': ['exampletranslation', '예문번역'],
  'type': ['vocabularytype', '단어유형'],
  'meaningType': ['meaningtype', '의미유형'],
  'partOfSpeech': ['partofspeech', '품사'],
  'category': ['category', 'subject', 'subjects', '분류', '과목', '분야'],
  'subcategory': ['subcategory', 'subsubject', '하위분류', '세부분야'],
  'abbreviation': ['abbreviation', 'abbr', '약어'],
  'symbol': ['symbol', '기호'],
  'formula': ['formula', '수식'],
  'unit': ['unit', '단위'],
  'applicationContext': ['applicationcontext', '적용맥락'],
  'relatedTerms': ['relatedterms', 'related', 'synonyms', '관련용어', '유의어'],
  'source': ['source', 'reference', '출처', '참고문헌'],
  'sourceTitle': ['sourcetitle'],
  'sourceAuthor': ['sourceauthor'],
  'sourceYear': ['sourceyear'],
  'sourceUrl': ['sourceurl'],
  'sourceLicense': ['sourcelicense'],
  'verification': ['verificationstatus', '검증상태'],
};

CsvImportPreview parseVocabularyCsv(String csvText) {
  final normalized = csvText
      .replaceFirst(RegExp(r'^\uFEFF'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rawRows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: false,
  ).convert(normalized);
  final rows = rawRows
      .map((row) => row.map((c) => c.toString()).toList())
      .where((row) => row.any((c) => c.trim().isNotEmpty))
      .toList();
  if (rows.isEmpty) return const CsvImportPreview();
  final columns = <String, int>{};
  final unknown = <String, int>{};
  final normalizedHeaders = rows.first.map(_headerKey).toList();
  final isV3 = normalizedHeaders.any((h) => const [
        'definitionen',
        'explanationko',
        'learningpriority',
        'priorityreason',
        'inclusionrecommendation',
      ].contains(h));
  if (isV3 &&
      (rows.first.length != recallV3Columns.length ||
          List.generate(recallV3Columns.length, (i) => i)
              .any((i) => rows.first[i].trim() != recallV3Columns[i]))) {
    throw FormatException(
        'Recall v3.0 CSV는 지정된 순서의 13개 열이 필요합니다: ${recallV3Columns.join(', ')}');
  }
  final isHeader = normalizedHeaders.any((h) =>
          _aliases['termEn']!.contains(h) || _aliases['termKo']!.contains(h)) ||
      normalizedHeaders
              .where((h) => _aliases.values.any((a) => a.contains(h)))
              .length >=
          2;
  if (isHeader) {
    for (var i = 0; i < rows.first.length; i++) {
      final matches =
          _aliases.entries.where((a) => a.value.contains(normalizedHeaders[i]));
      final key = matches.isEmpty ? null : matches.first.key;
      if (key != null) {
        if (columns.containsKey(key)) {
          throw FormatException('같은 항목을 가리키는 CSV 열이 중복됩니다: ${rows.first[i]}');
        }
        columns[key] = i;
      } else {
        final name = rows.first[i].trim();
        if (name.isEmpty || unknown.containsKey(name)) {
          throw const FormatException('CSV 열 이름은 비어 있거나 중복될 수 없습니다.');
        }
        unknown[name] = i;
      }
    }
    if (!columns.containsKey('termEn') && !columns.containsKey('termKo')) {
      throw const FormatException('word 또는 term_en 열이 필요합니다.');
    }
    if (!columns.containsKey('meaning') && !columns.containsKey('definition')) {
      throw const FormatException(
          'meaning, primary_meaning_ko 또는 definition 열이 필요합니다.');
    }
  }

  final accepted = <CsvVocabularyRow>[];
  final errors = <String>[];
  for (var i = isHeader ? 1 : 0; i < rows.length; i++) {
    final row = rows[i];
    String value(String key, [int? legacyIndex]) {
      final index = isHeader ? columns[key] : legacyIndex;
      return index != null && index < row.length ? row[index].trim() : '';
    }

    final english = value('termEn', 0);
    final korean = value('termKo');
    final translation = value('meaning', 1);
    final definition = value('definition');
    final front = korean.isEmpty ? english : korean;
    final legacyMeaning = translation.isEmpty ? definition : translation;
    final typeValue = value('type');
    final verificationValue = value('verification');
    final meaningTypeValue = value('meaningType');
    final priorityValue = value('priority');
    final inclusionValue = value('inclusion');
    String? error;
    if (isV3 && (english.isEmpty || translation.isEmpty)) {
      error = 'term_en과 primary_meaning_ko는 필수입니다.';
    } else if (isV3 && row.length != recallV3Columns.length) {
      error = 'Recall v3.0 데이터 행은 빈 셀을 포함해 13개 열이어야 합니다.';
    } else if (front.isEmpty || legacyMeaning.isEmpty) {
      error = '용어와 한국어 뜻 또는 정의가 필요합니다.';
    } else if (isHeader && row.length > rows.first.length) {
      error = '열 개수가 헤더보다 많습니다. 쉼표가 있는 내용은 따옴표로 감싸 주세요.';
    } else if (!isHeader && row.length > 3) {
      error = '헤더 없는 CSV는 단어, 뜻, 예문 3개 열까지 지원합니다.';
    } else if (typeValue.isNotEmpty &&
        !(typeValue == 'general' && !isV3) &&
        !VocabularyType.values.any((t) => t.value == typeValue)) {
      error = '지원하지 않는 vocabulary_type: $typeValue';
    } else if (verificationValue.isNotEmpty &&
        !VerificationStatus.values.any((s) => s.value == verificationValue)) {
      error = '지원하지 않는 verification_status: $verificationValue';
    } else if (meaningTypeValue.isNotEmpty &&
        !MeaningType.values.any((t) => t.value == meaningTypeValue)) {
      error = '지원하지 않는 meaning_type: $meaningTypeValue';
    } else if (priorityValue.isNotEmpty &&
        !LearningPriority.values.any((p) => p.value == priorityValue)) {
      error = '지원하지 않는 learning_priority: $priorityValue';
    } else if (inclusionValue.isNotEmpty &&
        !InclusionRecommendation.values.any((r) => r.value == inclusionValue)) {
      error = '지원하지 않는 inclusion_recommendation: $inclusionValue';
    }
    if (error != null) {
      errors.add('${i + 1}번째 레코드: $error');
      continue;
    }
    final technical = [value('formula'), value('symbol'), value('unit')]
        .any((s) => s.isNotEmpty);
    final type = VocabularyType.parse(
        typeValue.isEmpty ? (technical ? 'technical' : 'general') : typeValue);
    final meaningType = meaningTypeValue.isEmpty
        ? (type == VocabularyType.technical
            ? MeaningType.technical
            : MeaningType.general)
        : MeaningType.values.firstWhere((t) => t.value == meaningTypeValue);
    if ((typeValue == 'general' && meaningType == MeaningType.technical) ||
        (type == VocabularyType.technical &&
            meaningType == MeaningType.general)) {
      errors.add('${i + 1}번째 레코드: vocabulary_type과 meaning_type이 일치하지 않습니다.');
      continue;
    }
    final paths = <String>{};
    final parents = splitVocabularyList(value('category'));
    final children = splitVocabularyList(value('subcategory'));
    for (final parent in parents) {
      paths.add(parent);
      for (final child in children) {
        paths.add('$parent / $child');
      }
    }
    if (parents.isEmpty) paths.addAll(children);
    final source = VocabularySource(
      title:
          value('sourceTitle').isEmpty ? value('source') : value('sourceTitle'),
      author: value('sourceAuthor'),
      year: value('sourceYear'),
      url: value('sourceUrl'),
      license: value('sourceLicense'),
    );
    final meaning = VocabularyMeaning(
      id: 'csv-$i-meaning',
      meaningKo: translation.isNotEmpty
          ? translation
          : (korean.isEmpty ? legacyMeaning : korean),
      type: meaningType,
      definitionEn: definition,
      explanationKo: value('explanation'),
      exampleSentence: value('example', 2),
      exampleTranslation: value('exampleTranslation'),
      formula: value('formula'),
      symbol: value('symbol'),
      unit: value('unit'),
      applicationContext: value('applicationContext'),
    );
    accepted.add(CsvVocabularyRow(
        i + 1,
        RecallCard(
          id: value('id'),
          front: front,
          meaning: legacyMeaning,
          example: value('example', 2),
          termEnglish: english,
          dueAt: DateTime.now(),
          intervalMinutes: 0,
          stabilityDays: 2.1,
          ease: 2.5,
          lastReviewed: null,
          vocabularyType: type,
          learningPriority: LearningPriority.parse(priorityValue),
          priorityReason: value('priorityReason'),
          inclusionRecommendation:
              InclusionRecommendation.parse(inclusionValue),
          collector: value('collector'),
          notes: value('notes'),
          meanings: [meaning],
          partOfSpeech: splitVocabularyList(value('partOfSpeech')),
          abbreviation: value('abbreviation'),
          formula: value('formula'),
          symbol: value('symbol'),
          unit: value('unit'),
          source: value('source'),
          relatedTerms: splitVocabularyList(value('relatedTerms')),
          sources: source.isEmpty ? const [] : [source],
          verificationStatus: VerificationStatus.parse(verificationValue),
          extraFields: {
            if (typeValue == 'general') 'legacy_vocabulary_type': 'general',
            for (final column in unknown.entries)
              if (column.value < row.length && row[column.value].isNotEmpty)
                column.key: row[column.value],
          },
        ),
        paths.toList(),
        suppliedFields: {
          for (final key in columns.keys)
            if (value(key).isNotEmpty) key,
        }));
  }
  return CsvImportPreview(
      rows: accepted, errors: errors, unknownHeaders: unknown.keys.toList());
}
