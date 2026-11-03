import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'terminology_lookup.dart';
import 'term_hover_region.dart';

Future<List<TermHoverArea>> loadPdfHoverAreas(
    PdfPage page, TerminologyLookup lookup) async {
  if (page.document.permissions?.allowsCopying == false) {
    throw const TermTextUnavailable('복사가 제한된 PDF입니다. 단어 강조를 분석할 수 없습니다.');
  }
  final text = await page.loadStructuredText(ensureLoaded: true);
  return pdfHoverAreasFromText(page, text, lookup);
}

/// Geometry mapping is separate from extraction so malformed maps can be tested.
List<TermHoverArea> pdfHoverAreasFromText(
    PdfPage page, PdfPageText text, TerminologyLookup lookup) {
  if (text.fullText.trim().isEmpty) {
    throw const TermTextUnavailable(
        '이 페이지에서 텍스트를 읽을 수 없습니다. 스캔 PDF는 단어 강조를 지원하지 않습니다.');
  }
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
  if (matches.isNotEmpty && areas.isEmpty) {
    throw const TermTextUnavailable(
        '사전 표현은 찾았지만 PDF의 문자 위치를 확인할 수 없어 강조할 수 없습니다.');
  }
  return areas;
}
