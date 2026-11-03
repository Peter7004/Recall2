import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:recall/reader/pdf_term_hover.dart';
import 'package:recall/reader/term_hover_region.dart';
import 'package:recall/reader/terminology_lookup.dart';
import 'package:recall/vocabulary.dart';

class _Page implements PdfPage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PdfPageText _text(String text) =>
    PdfPageText(pageNumber: 1, fullText: text, charRects: [], fragments: []);

class _Lookup implements TerminologyLookup {
  _Lookup(this.matches);
  final bool matches;
  @override
  List<ReaderTermMatch> lookup(String text) => !matches
      ? []
      : [
          ReaderTermMatch(
              ReaderConcept(RecallCard(
                  id: 'term',
                  front: 'Skin effect',
                  meaning: '표피 효과',
                  example: '',
                  dueAt: DateTime(2026),
                  intervalMinutes: 0,
                  stabilityDays: 2.1,
                  ease: 2.5,
                  lastReviewed: null)),
              text,
              0,
              text.length,
              isKorean: false)
        ];
}

void main() {
  test('matched text without usable geometry is unavailable, not zero matches',
      () {
    expect(
        () =>
            pdfHoverAreasFromText(_Page(), _text('Skin effect'), _Lookup(true)),
        throwsA(isA<TermTextUnavailable>()));
  });
  test('readable unmatched text is a successful zero-match result', () {
    expect(pdfHoverAreasFromText(_Page(), _text('unmatched'), _Lookup(false)),
        isEmpty);
  });
  test('image-only page reports text unavailable', () {
    expect(() => pdfHoverAreasFromText(_Page(), _text(''), _Lookup(false)),
        throwsA(isA<TermTextUnavailable>()));
  });
}
