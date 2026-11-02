import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'terminology_lookup.dart';
import 'term_hover_region.dart';

Future<List<TermHoverArea>> loadPdfHoverAreas(
    PdfPage page, TerminologyLookup lookup) async {
  if (page.document.permissions?.allowsCopying == false) return const [];
  final text = await page.loadStructuredText(ensureLoaded: true);
  if (text.fullText.isEmpty) return const [];
  final matches = lookup.lookup(text.fullText);
  final areas = <TermHoverArea>[];
  for (final match in matches) {
    if (match.end > text.charRects.length) continue;
    final range =
        PdfPageTextRange(pageText: text, start: match.start, end: match.end);
    final bounds = text.fragments.isEmpty
        ? [range.bounds]
        : range
            .enumerateFragmentBoundingRects()
            .map((fragment) => fragment.bounds)
            .toList();
    final rects = bounds
        .where((rect) => rect.isNotEmpty)
        .map((rect) => normalizedPageRect(
            rect.toRect(page: page), Size(page.width, page.height)))
        .toList();
    if (rects.isNotEmpty) areas.add(TermHoverArea(match.expression, rects));
  }
  return areas;
}
