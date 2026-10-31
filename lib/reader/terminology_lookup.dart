import '../vocabulary.dart';

class ReaderConcept {
  ReaderConcept(this.card,
      {Iterable<String> englishAliases = const [],
      Iterable<String> koreanAliases = const []})
      : english = {
          card.displayTerm,
          if (card.abbreviation.isNotEmpty) card.abbreviation,
          ...englishAliases
        }.where((s) => s.trim().isNotEmpty).toList(),
        korean = {
          for (final meaning in card.effectiveMeanings) meaning.meaningKo,
          ...koreanAliases
        }.where((s) => s.trim().isNotEmpty).toList();
  final RecallCard card;
  final List<String> english;
  final List<String> korean;
}

class ReaderTermMatch {
  const ReaderTermMatch(this.concept, this.expression, this.start, this.end,
      {required this.isKorean});
  final ReaderConcept concept;
  final String expression;
  final int start;
  final int end;
  final bool isKorean;
}

abstract interface class TerminologyLookup {
  List<ReaderTermMatch> lookup(String selectedText);
}

class DictionaryTerminologyLookup implements TerminologyLookup {
  DictionaryTerminologyLookup(Iterable<ReaderConcept> concepts) {
    for (final concept in concepts) {
      for (final korean in [false, true]) {
        for (final expression in korean ? concept.korean : concept.english) {
          final compact = expression.trim();
          final pattern = korean
              ? compact
                  .replaceAll(RegExp(r'\s+'), '')
                  .split('')
                  .map(RegExp.escape)
                  .join(r'\s*')
              : compact.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
          _aliases.add((
            concept: concept,
            expression: compact,
            korean: korean,
            pattern: RegExp(pattern, caseSensitive: false, unicode: true)
          ));
        }
      }
    }
  }

  final _aliases = <({
    ReaderConcept concept,
    String expression,
    bool korean,
    RegExp pattern
  })>[];
  static final _wordCharacter = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  static final _particle = RegExp(
      r'^(에서는|에게서는|으로부터|으로는|이라고|에서|에게|으로|에는|까지|부터|처럼|보다|이라|은|는|이|가|을|를|의|에|와|과|도|만|로)');
  bool _boundary(String text, int index) =>
      index < 0 ||
      index >= text.length ||
      !_wordCharacter.hasMatch(text[index]);

  @override
  List<ReaderTermMatch> lookup(String selectedText) {
    final candidates = <ReaderTermMatch>[];
    for (final alias in _aliases) {
      for (final match in alias.pattern.allMatches(selectedText)) {
        if (!_boundary(selectedText, match.start - 1)) continue;
        var boundary = _boundary(selectedText, match.end);
        if (!boundary) {
          final particle =
              _particle.firstMatch(selectedText.substring(match.end));
          boundary = particle != null &&
              _boundary(selectedText, match.end + particle.end);
        }
        if (boundary) {
          candidates.add(ReaderTermMatch(
              alias.concept, alias.expression, match.start, match.end,
              isKorean: alias.korean));
        }
      }
    }
    candidates.sort((a, b) {
      final length = (b.end - b.start).compareTo(a.end - a.start);
      return length != 0 ? length : a.start.compareTo(b.start);
    });
    final chosen = <ReaderTermMatch>[];
    for (final candidate in candidates) {
      if (chosen.any((m) =>
          candidate.start < m.end &&
          candidate.end > m.start &&
          !(candidate.start == m.start && candidate.end == m.end))) {
        continue;
      }
      if (!chosen.any((m) =>
          m.start == candidate.start &&
          m.end == candidate.end &&
          m.concept.card.id == candidate.concept.card.id)) {
        chosen.add(candidate);
      }
    }
    chosen.sort((a, b) => a.start.compareTo(b.start));
    return chosen;
  }
}
