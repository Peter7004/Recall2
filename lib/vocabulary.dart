enum VocabularyType {
  generalTechnical('general_technical', '일반·전공 영어'),
  technical('technical', '전공 용어');

  const VocabularyType(this.value, this.label);
  final String value;
  final String label;

  static VocabularyType parse(String value) => values.firstWhere(
        (type) => type.value == value,
        orElse: () => VocabularyType.generalTechnical,
      );
}

enum LearningPriority {
  high('high', '높음'),
  medium('medium', '보통'),
  low('low', '낮음');

  const LearningPriority(this.value, this.label);
  final String value;
  final String label;
  static LearningPriority parse(String value) => values.firstWhere(
        (priority) => priority.value == value,
        orElse: () => LearningPriority.medium,
      );
}

// Collection recommendations are management metadata, not review exclusions.
enum InclusionRecommendation {
  include('include'),
  review('review'),
  exclude('exclude');

  const InclusionRecommendation(this.value);
  final String value;
  static InclusionRecommendation parse(String value) => values.firstWhere(
        (recommendation) => recommendation.value == value,
        orElse: () => InclusionRecommendation.review,
      );
}

enum MeaningType {
  general('general', '일반 의미'),
  technical('technical', '전공 의미');

  const MeaningType(this.value, this.label);
  final String value;
  final String label;
}

enum VerificationStatus {
  aiDraft('ai_draft', 'AI 초안'),
  needsReview('needs_review', '검토 필요'),
  verified('verified', '검증됨');

  const VerificationStatus(this.value, this.label);
  final String value;
  final String label;

  static VerificationStatus parse(String value) => values.firstWhere(
        (status) => status.value == value,
        orElse: () => VerificationStatus.needsReview,
      );
}

class VocabularyMeaning {
  const VocabularyMeaning({
    required this.id,
    required this.meaningKo,
    this.type = MeaningType.general,
    String definition = '',
    String explanation = '',
    String? definitionEn,
    String? explanationKo,
    this.exampleSentence = '',
    this.exampleTranslation = '',
    this.formula = '',
    this.symbol = '',
    this.unit = '',
    this.applicationContext = '',
  })  : definition = definitionEn ?? definition,
        explanation = explanationKo ?? explanation;

  final String id;
  final String meaningKo;
  final MeaningType type;
  final String definition;
  final String explanation;
  final String exampleSentence;
  final String exampleTranslation;
  final String formula;
  final String symbol;
  final String unit;
  final String applicationContext;
  String get definitionEn => definition;
  String get explanationKo => explanation;

  Map<String, Object?> toJson() => {
        'id': id,
        'meaning_ko': meaningKo,
        'meaning_type': type.value,
        'definition_en': definitionEn,
        'explanation_ko': explanationKo,
        'example_sentence': exampleSentence,
        'example_translation': exampleTranslation,
        'formula': formula,
        'symbol': symbol,
        'unit': unit,
        'application_context': applicationContext,
      };

  factory VocabularyMeaning.fromJson(Map<String, Object?> json) =>
      VocabularyMeaning(
        id: json['id']! as String,
        meaningKo: json['meaning_ko'] as String? ?? '',
        type: json['meaning_type'] == 'technical'
            ? MeaningType.technical
            : MeaningType.general,
        definitionEn: json['definition_en'] as String? ??
            json['definition'] as String? ??
            '',
        explanationKo: json['explanation_ko'] as String? ??
            json['explanation'] as String? ??
            '',
        exampleSentence: json['example_sentence'] as String? ?? '',
        exampleTranslation: json['example_translation'] as String? ?? '',
        formula: json['formula'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        applicationContext: json['application_context'] as String? ?? '',
      );
}

class VocabularySource {
  const VocabularySource({
    this.title = '',
    this.author = '',
    this.year = '',
    this.url = '',
    this.license = '',
  });

  final String title;
  final String author;
  final String year;
  final String url;
  final String license;

  bool get isEmpty =>
      [title, author, year, url, license].every((s) => s.isEmpty);
  Map<String, Object?> toJson() => {
        'title': title,
        'author': author,
        'year': year,
        'url': url,
        'license': license,
      };
  factory VocabularySource.fromJson(Map<String, Object?> json) =>
      VocabularySource(
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        year: json['year']?.toString() ?? '',
        url: json['url'] as String? ?? '',
        license: json['license'] as String? ?? '',
      );
}

class RecallCategory {
  const RecallCategory(
      {required this.id,
      required this.name,
      this.parentId,
      this.isPinned = false});
  final String id;
  final String name;
  final String? parentId;
  final bool isPinned;
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'isPinned': isPinned,
      };
  factory RecallCategory.fromJson(Map<String, Object?> json) => RecallCategory(
        id: json['id']! as String,
        name: json['name']! as String,
        parentId: json['parentId'] as String?,
        isPinned: json['isPinned'] as bool? ?? false,
      );
}

// Legacy card fields remain available to the existing photo and review screens.
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
    this.termEnglish = '',
    this.abbreviation = '',
    this.symbol = '',
    this.formula = '',
    this.unit = '',
    this.source = '',
    this.relatedTerms = const [],
    this.categoryIds = const [],
    this.vocabularyType = VocabularyType.generalTechnical,
    this.learningPriority = LearningPriority.medium,
    this.priorityReason = '',
    this.inclusionRecommendation = InclusionRecommendation.review,
    this.collector = '',
    this.notes = '',
    this.partOfSpeech = const [],
    this.meanings = const [],
    this.sources = const [],
    this.verificationStatus = VerificationStatus.needsReview,
    this.extraFields = const {},
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
  final String termEnglish;
  final String abbreviation;
  final String symbol;
  final String formula;
  final String unit;
  final String source;
  final List<String> relatedTerms;
  final List<String> categoryIds;
  final VocabularyType vocabularyType;
  final LearningPriority learningPriority;
  final String priorityReason;
  final InclusionRecommendation inclusionRecommendation;
  final String collector;
  final String notes;
  final List<String> partOfSpeech;
  final List<VocabularyMeaning> meanings;
  final List<VocabularySource> sources;
  final VerificationStatus verificationStatus;
  final Map<String, String> extraFields;

  String get displayTerm => termEnglish.isEmpty ? front : termEnglish;
  String get primaryMeaning => effectiveMeanings.first.meaningKo;
  String get definitionEn => effectiveMeanings.first.definitionEn;
  String get explanationKo => effectiveMeanings.first.explanationKo;
  List<VocabularyMeaning> get effectiveMeanings => meanings.isNotEmpty
      ? meanings
      : [
          VocabularyMeaning(
            id: '$id-meaning',
            meaningKo: termEnglish.isNotEmpty && front != termEnglish
                ? front
                : meaning,
            type: vocabularyType == VocabularyType.technical
                ? MeaningType.technical
                : MeaningType.general,
            definition: meaning,
            exampleSentence: example,
            symbol: symbol,
            formula: formula,
            unit: unit,
          ),
        ];

  String get reviewAnswer => effectiveMeanings
      .map((m) => [
            m.meaningKo,
            m.definitionEn,
            m.explanationKo,
          ].where((s) => s.isNotEmpty).toSet().join('\n'))
      .join('\n\n');

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
        'termEnglish': termEnglish,
        'abbreviation': abbreviation,
        'symbol': symbol,
        'formula': formula,
        'unit': unit,
        'source': source,
        'relatedTerms': relatedTerms,
        'categoryIds': categoryIds,
        'vocabulary_type': vocabularyType.value,
        'learning_priority': learningPriority.value,
        'priority_reason': priorityReason,
        'inclusion_recommendation': inclusionRecommendation.value,
        'collector': collector,
        'notes': notes,
        'part_of_speech': partOfSpeech,
        'meanings': effectiveMeanings.map((m) => m.toJson()).toList(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'verification_status': verificationStatus.value,
        'extra_fields': extraFields,
      };

  factory RecallCard.fromJson(Map<String, Object?> json) {
    final hasTechnicalFields = ['symbol', 'formula', 'unit']
        .any((key) => (json[key] as String? ?? '').isNotEmpty);
    return RecallCard(
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
      isExcludedFromReview: json['isExcludedFromReview'] as bool? ?? false,
      imageData: json['imageData'] as String?,
      termEnglish: json['termEnglish'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      formula: json['formula'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      source: json['source'] as String? ?? '',
      relatedTerms: (json['relatedTerms'] as List? ?? []).cast<String>(),
      categoryIds: (json['categoryIds'] as List? ?? []).cast<String>(),
      vocabularyType: VocabularyType.parse(json['vocabulary_type'] as String? ??
          (hasTechnicalFields ? 'technical' : 'general')),
      learningPriority:
          LearningPriority.parse(json['learning_priority'] as String? ?? ''),
      priorityReason: json['priority_reason'] as String? ?? '',
      inclusionRecommendation: InclusionRecommendation.parse(
          json['inclusion_recommendation'] as String? ?? ''),
      collector: json['collector'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      partOfSpeech: (json['part_of_speech'] as List? ?? []).cast<String>(),
      meanings: (json['meanings'] as List? ?? [])
          .map((m) =>
              VocabularyMeaning.fromJson(Map<String, Object?>.from(m as Map)))
          .toList(),
      sources: (json['sources'] as List? ?? [])
          .map((s) =>
              VocabularySource.fromJson(Map<String, Object?>.from(s as Map)))
          .toList(),
      verificationStatus: VerificationStatus.parse(
          json['verification_status'] as String? ?? 'needs_review'),
      extraFields: {
        ...(json['extra_fields'] as Map? ?? {}).cast<String, String>(),
        if (json['vocabulary_type'] == 'general')
          'legacy_vocabulary_type': 'general',
      },
    );
  }

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
    String? termEnglish,
    String? abbreviation,
    String? symbol,
    String? formula,
    String? unit,
    String? source,
    List<String>? relatedTerms,
    List<String>? categoryIds,
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
    Map<String, String>? extraFields,
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
        isExcludedFromReview: isExcludedFromReview ?? this.isExcludedFromReview,
        imageData: imageData == null
            ? this.imageData
            : (imageData.isEmpty ? null : imageData),
        termEnglish: termEnglish ?? this.termEnglish,
        abbreviation: abbreviation ?? this.abbreviation,
        symbol: symbol ?? this.symbol,
        formula: formula ?? this.formula,
        unit: unit ?? this.unit,
        source: source ?? this.source,
        relatedTerms: relatedTerms ?? this.relatedTerms,
        categoryIds: categoryIds ?? this.categoryIds,
        vocabularyType: vocabularyType ?? this.vocabularyType,
        learningPriority: learningPriority ?? this.learningPriority,
        priorityReason: priorityReason ?? this.priorityReason,
        inclusionRecommendation:
            inclusionRecommendation ?? this.inclusionRecommendation,
        collector: collector ?? this.collector,
        notes: notes ?? this.notes,
        partOfSpeech: partOfSpeech ?? this.partOfSpeech,
        meanings: meanings ?? this.meanings,
        sources: sources ?? this.sources,
        verificationStatus: verificationStatus ?? this.verificationStatus,
        extraFields: extraFields ?? this.extraFields,
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
        'entryIds': cards.map((card) => card.id).toList(),
      };
  factory RecallDeck.fromJson(Map<String, Object?> json) => RecallDeck(
        id: json['id']! as String,
        name: json['name']! as String,
        cards: (json['cards'] as List? ?? [])
            .map(
                (c) => RecallCard.fromJson(Map<String, Object?>.from(c as Map)))
            .toList(),
      );
}
