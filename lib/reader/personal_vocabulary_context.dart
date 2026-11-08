String normalizePersonalTerm(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Use the selected character offsets, never the first matching word on a page.
/// Ambiguous abbreviations, paragraphs, tables and incomplete sentences stay empty.
String personalSentence(String text, int start, int end) {
  if (start < 0 || end <= start || end > text.length) return '';
  final boundaries = RegExp(r'[.!?](?=\s|$)').allMatches(text).toList();
  var left = 0;
  for (final boundary in boundaries) {
    if (boundary.end <= start) left = boundary.end;
  }
  int? right;
  for (final boundary in boundaries) {
    if (boundary.start >= end - 1) {
      right = boundary.end;
      break;
    }
    if (boundary.start >= start) return '';
  }
  if (right == null) return '';
  final raw = text.substring(left, right);
  if (raw.length > 1000 ||
      raw.contains('\t') ||
      RegExp(r'\n\s*\n').hasMatch(raw)) {
    return '';
  }
  // A preceding abbreviation could have been mistaken for a sentence boundary.
  final prefix = text.substring(0, left);
  if (RegExp(r'\b(?:Mr|Mrs|Dr|Fig|Eq|Prof|vs|etc|e\.g|i\.e)\.$',
          caseSensitive: false)
      .hasMatch(prefix.trim())) {
    return '';
  }
  final result = normalizePersonalTerm(raw);
  if (!RegExp(r'^[A-Z]').hasMatch(result)) return '';
  return result;
}
