import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/reader/library/document_repository.dart';
import 'package:recall/reader/library/document_storage.dart';
import 'package:recall/reader/library/reader_library_view.dart';
import 'package:recall/reader/library/reader_document.dart';

void main() {
  testWidgets(
      'saved document opens without picker and deletion requires explicit confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nA'));
    final doc = ReaderDocument(
        id: 'a' * 64,
        title: 'a.pdf',
        byteSize: bytes.length,
        importedAt: DateTime(2026),
        lastOpenedAt: DateTime(2026));
    final storage = MemoryDocumentStorage();
    storage.documents[doc.id] = doc;
    storage.payloads[doc.id] = bytes;
    final repository = DocumentRepository(storage);
    String? opened;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReaderLibraryView(
                repository: () async => repository,
                onImport: () async {},
                onOpen: (id) async => opened = id,
                onDelete: repository.delete))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('문서 열기: a.pdf'));
    await tester.pumpAndSettle();
    expect(opened, doc.id);
    await tester.tap(find.byTooltip('문서 관리: a.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('원본 PDF'), findsWidgets);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect((await repository.list()).length, 1);
    await tester.tap(find.byTooltip('문서 관리: a.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(await repository.list(), isEmpty);
    expect(find.text('PDF를 가져오면 여기에 표시됩니다.'), findsOneWidget);
  });
}
