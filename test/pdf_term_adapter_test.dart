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

class _Document implements PdfDocument {
  @override
  List<PdfPage> pages = [];
  @override
  PdfPermissions? get permissions => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GeometryPage extends _Page {
  _GeometryPage(this.document,
      {required this.width,
      required this.height,
      this.isLoaded = true,
      this.rotation = PdfPageRotation.none});
  @override
  final PdfDocument document;
  @override
  final double width;
  @override
  final double height;
  @override
  final bool isLoaded;
  @override
  final PdfPageRotation rotation;
  @override
  int get pageNumber => 1;
  @override
  Future<PdfPageRawText?> loadText() async => PdfPageRawText('values', [
        for (var i = 0; i < 6; i++)
          PdfRect(100 + i * 10, 600, 110 + i * 10, 590),
      ]);
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
  test('progressive page uses loaded dimensions for text and highlight',
      () async {
    final document = _Document();
    final placeholder =
        _GeometryPage(document, width: 600, height: 800, isLoaded: false);
    document.pages = [_GeometryPage(document, width: 576, height: 736)];
    final areas = await loadPdfHoverAreas(placeholder, _Lookup(true));
    final rect = areas.single.rects.single;
    expect(rect.left, closeTo(100 / 576, 0.00001));
    expect(rect.top, closeTo(136 / 736, 0.00001));
    expect(rect.width, closeTo(60 / 576, 0.00001));
    expect(rect.height, closeTo(10 / 736, 0.00001));
  });

  test('replaced loaded page uses current rotation, not stale cached geometry',
      () async {
    final document = _Document();
    final previous = _GeometryPage(document, width: 576, height: 736);
    document.pages = [
      _GeometryPage(document,
          width: 736, height: 576, rotation: PdfPageRotation.clockwise90)
    ];
    final areas = await loadPdfHoverAreas(previous, _Lookup(true));
    final rect = areas.single.rects.single;
    expect(rect.left, closeTo(590 / 736, 0.00001));
    expect(rect.top, closeTo(100 / 576, 0.00001));
    expect(rect.width, closeTo(10 / 736, 0.00001));
    expect(rect.height, closeTo(60 / 576, 0.00001));
  });

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
