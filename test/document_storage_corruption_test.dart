import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/reader/library/document_repository.dart';
import 'package:recall/reader/library/document_storage.dart';
import 'package:recall/reader/library/document_storage_io.dart';
import 'package:recall/reader/library/reader_document.dart';
import 'package:recall/reader/library/reader_library_view.dart';

class _DamagedMemory extends MemoryDocumentStorage
    implements DocumentStorageDiagnostics {
  @override
  List<DamagedDocumentEntry> get damagedEntries =>
      [DamagedDocumentEntry('f' * 64)];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'native isolates malformed, missing and mismatched metadata without writes',
      () async {
    final root = await Directory.systemTemp.createTemp('recall-corruption-');
    addTearDown(() => root.delete(recursive: true));
    final repository = DocumentRepository(FileDocumentStorage(root));
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nhealthy'));
    final healthy = (await repository.importPdf(bytes, 'healthy.pdf')).document;
    final originals = <String, String>{};
    for (final id in ['b' * 64, 'c' * 64, 'd' * 64]) {
      final directory = await Directory('${root.path}/$id').create();
      await File('${directory.path}/document.pdf').writeAsBytes([1, 2, 3]);
      if (id.startsWith('c')) continue;
      final raw = id.startsWith('b') ? '{broken' : jsonEncode(healthy.toJson());
      originals[id] = raw;
      await File('${directory.path}/metadata.json').writeAsString(raw);
    }
    expect((await repository.list()).map((d) => d.id), [healthy.id]);
    expect(repository.damagedEntries.map((d) => d.id),
        unorderedEquals(['b' * 64, 'c' * 64, 'd' * 64]));
    expect((await repository.open(healthy.id)).bytes, orderedEquals(bytes));
    for (final id in ['b' * 64, 'c' * 64, 'd' * 64]) {
      await expectLater(
          repository.open(id), throwsA(isA<DocumentStorageException>()));
      await expectLater(repository.rename(id, 'replacement'),
          throwsA(isA<DocumentStorageException>()));
      expect(
          await File('${root.path}/$id/document.pdf').readAsBytes(), [1, 2, 3]);
      final metadata = File('${root.path}/$id/metadata.json');
      if (originals.containsKey(id)) {
        expect(await metadata.readAsString(), originals[id]);
      } else {
        expect(await metadata.exists(), isFalse);
      }
    }
    await File('${root.path}/${healthy.id}/metadata.json')
        .writeAsString('null');
    await expectLater(repository.importPdf(bytes, 'replacement.pdf'),
        throwsA(isA<DocumentStorageException>()));
    expect(
        await File('${root.path}/${healthy.id}/metadata.json').readAsString(),
        'null');
    expect(await File('${root.path}/${healthy.id}/document.pdf').readAsBytes(),
        bytes);
  });

  testWidgets('damaged entry warning leaves healthy library entries usable',
      (tester) async {
    final storage = _DamagedMemory();
    final repository = DocumentRepository(storage);
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nhealthy'));
    final healthy = ReaderDocument(
        id: 'a' * 64,
        title: 'healthy.pdf',
        byteSize: bytes.length,
        importedAt: DateTime(2026),
        lastOpenedAt: DateTime(2026));
    storage.documents[healthy.id] = healthy;
    storage.payloads[healthy.id] = bytes;
    String? opened;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReaderLibraryView(
      repository: () async => repository,
      onImport: () async {},
      onOpen: (id) async => opened = (await repository.open(id)).document.id,
      onDelete: repository.delete,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('문서 기록 1개를 읽지 못했습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('문서 열기: healthy.pdf'));
    await tester.pumpAndSettle();
    expect(opened, healthy.id);
  });
}
