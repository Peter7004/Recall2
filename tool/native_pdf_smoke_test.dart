// Explicit host-toolchain diagnostic; does not change the app or user PDFs.
// Run: powershell -File tool/recall-windows.ps1 -Action NativeSmoke
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

Uint8List _fixture() {
  const stream = 'BT /F1 18 Tf 20 60 Td (Recall native PDF) Tj ET\n'
      '0 0 0 rg 20 20 80 10 re f\n';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n${stream}endstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write('trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native PDFium gate loads, extracts text and renders a real PDF',
      () async {
    final cache = Directory('build/windows-toolchain-audit/pdf-smoke-cache');
    await cache.create(recursive: true);
    Pdfrx.cacheDirectoryPath = cache.absolute.path;
    // Exercise the compiled gate as well as the downloaded PDFium DLL.
    await pdfrxFlutterInitialize(processWidePdfiumGate: true);
    addTearDown(() => PdfrxEntryFunctions.instance.stopBackgroundWorker());
    final document = await PdfDocument.openData(_fixture());
    try {
      expect(document.pages, hasLength(1));
      final page = document.pages.single;
      final text = await page.loadText();
      expect(text?.fullText, contains('Recall native PDF'));
      final image = await page.render(
          width: 200, height: 100, backgroundColor: 0xffffffff);
      expect(image, isNotNull);
      try {
        expect(image!.pixels, hasLength(200 * 100 * 4));
        var darkPixels = 0;
        for (var i = 0; i < image.pixels.length; i += 4) {
          if (image.pixels[i] < 64 &&
              image.pixels[i + 1] < 64 &&
              image.pixels[i + 2] < 64) {
            darkPixels++;
          }
        }
        expect(darkPixels, greaterThan(500));
      } finally {
        image?.dispose();
      }
    } finally {
      await document.dispose();
    }
  });
}
