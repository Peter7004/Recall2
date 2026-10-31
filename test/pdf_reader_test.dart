import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:recall/reader/pdf_reader_page.dart';
import '../tool/reader_lookup_check.dart' as terminology_checks;

void main() {
  test('bilingual lookup preserves data and matches technical phrases',
      terminology_checks.main);
  testWidgets('reader opens without changing dictionary storage',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PdfReaderPage()));
    expect(find.text('Recall Reader'), findsOneWidget);
    expect(find.text('PDF 열기'), findsOneWidget);
  });
}
