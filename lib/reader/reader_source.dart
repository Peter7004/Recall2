import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'reader_learning.dart';
import 'terminology_lookup.dart';
import 'term_hover_region.dart';

/// Preserve character offsets and fragment geometry, never relocate by text alone.
List<ReaderOccurrence> captureReaderOccurrences({
  required List<PdfPageTextRange> ranges,
  required PdfDocument document,
  required TerminologyLookup lookup,
  required String cardId,
  required String documentId,
  required String documentTitle,
}) {
  final occurrences = <ReaderOccurrence>[];
  for (final selected in ranges) {
    final page = document.pages[selected.pageNumber - 1];
    for (final match in lookup
        .lookup(selected.text)
        .where((m) => m.concept.card.id == cardId)) {
      final start = selected.start + match.start,
          end = selected.start + match.end;
      final range =
          PdfPageTextRange(pageText: selected.pageText, start: start, end: end);
      final bounds = range.pageText.fragments.isEmpty
          ? [range.bounds]
          : range
              .enumerateFragmentBoundingRects()
              .map((fragment) => fragment.bounds)
              .toList();
      final rects = bounds
          .where((r) => r.isNotEmpty)
          .map((r) => normalizedPageRect(
              r.toRect(page: page), Size(page.width, page.height)))
          .where((r) => r.isFinite && r.width > 0 && r.height > 0)
          .map((r) => Rect.fromLTRB(r.left.clamp(0, 1), r.top.clamp(0, 1),
              r.right.clamp(0, 1), r.bottom.clamp(0, 1)))
          .where((r) => !r.isEmpty)
          .toList();
      if (rects.isEmpty) continue;
      final fullText = range.pageText.fullText;
      occurrences.add(ReaderOccurrence(
          cardId: cardId,
          documentId: documentId,
          documentTitle: documentTitle,
          page: range.pageNumber,
          start: start,
          end: end,
          text: range.text,
          context: fullText.substring(
              math.max(0, start - 100), math.min(fullText.length, end + 100)),
          rects: rects,
          createdAt: DateTime.now()));
    }
  }
  return occurrences;
}

class ReaderSourcePainter extends CustomPainter {
  const ReaderSourcePainter(this.sources);
  final List<ReaderOccurrence> sources;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0x5533C8AA);
    final border = Paint()
      ..color = const Color(0xFF087B68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final source in sources) {
      for (final r in source.rects) {
        final rect = Rect.fromLTRB(r.left * size.width, r.top * size.height,
            r.right * size.width, r.bottom * size.height);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, border);
      }
    }
  }

  @override
  bool shouldRepaint(ReaderSourcePainter oldDelegate) =>
      !identical(sources, oldDelegate.sources);
}
