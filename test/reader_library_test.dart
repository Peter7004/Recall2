import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/reader/library/document_repository.dart';
import 'package:recall/reader/library/document_storage.dart';
import 'package:recall/reader/library/document_storage_io.dart';
import 'package:recall/reader/library/reader_document.dart';
import 'package:recall/reader/reader_progress.dart';

class FailingStorage extends MemoryDocumentStorage {
  bool failCreate = false, failDelete = false;
  @override
  Future<void> create(ReaderDocument document, Uint8List bytes) async {
    if (failCreate) {
      throw const DocumentStorageException('injected storage full');
    }
    return super.create(document, bytes);
  }

  @override
  Future<bool> delete(String id) async {
    if (failDelete) {
      throw const DocumentStorageException('injected permission error');
    }
    return super.delete(id);
  }
}

void main() {
  final a = Uint8List.fromList(utf8.encode('%PDF-1.7\nfixture A'));
  final b = Uint8List.fromList(utf8.encode('%PDF-1.7\nfixture B'));
  setUp(() => SharedPreferences.setMockInitialValues(
      {'recall.data.v3': 'untouched vocabulary'}));

  test(
      'duplicate content preserves renamed title, different same-name PDFs stay separate',
      () async {
    final storage = MemoryDocumentStorage();
    final repository = DocumentRepository(storage);
    final first = await repository.importPdf(a, 'same.pdf');
    await repository.rename(first.document.id, 'My textbook');
    final duplicate = await repository.importPdf(a, 'renamed.pdf');
    expect(duplicate.duplicate, isTrue);
    expect(duplicate.document.title, 'My textbook');
    final other = await repository.importPdf(b, 'same.pdf');
    expect(other.document.id, isNot(first.document.id));
    expect((await repository.list()).length, 2);
    await repository.setPageCount(first.document.id, 30);
    expect((await repository.open(first.document.id)).document.pageCount, 30);
  });

  test(
      'failed import leaves no record; failed deletion restores reading position',
      () async {
    final storage = FailingStorage()..failCreate = true;
    final repository = DocumentRepository(storage);
    await expectLater(repository.importPdf(a, 'a.pdf'),
        throwsA(isA<DocumentStorageException>()));
    expect(await repository.list(), isEmpty);
    storage.failCreate = false;
    final doc = (await repository.importPdf(a, 'a.pdf')).document;
    await const ReaderProgress(page: 7, paged: true).save(doc.id);
    storage.failDelete = true;
    await expectLater(
        repository.delete(doc.id), throwsA(isA<DocumentStorageException>()));
    expect((await ReaderProgress.load(doc.id))!.page, 7);
    expect(await storage.available(doc.id), isTrue);
    storage.failDelete = false;
    await repository.delete(doc.id);
    expect(await ReaderProgress.load(doc.id), isNull);
    expect(await repository.list(), isEmpty);
    expect((await SharedPreferences.getInstance()).getString('recall.data.v3'),
        'untouched vocabulary');
  });

  test(
      'missing copy repaired by reimport and invalid input rejected without writes',
      () async {
    final storage = MemoryDocumentStorage();
    final repository = DocumentRepository(storage);
    await expectLater(repository.importPdf(Uint8List(0), 'bad.pdf'),
        throwsA(isA<DocumentStorageException>()));
    final doc = (await repository.importPdf(a, 'a.pdf')).document;
    storage.payloads.remove(doc.id);
    await expectLater(
        repository.open(doc.id), throwsA(isA<DocumentStorageException>()));
    await repository.importPdf(a, 'new-name.pdf');
    expect((await repository.open(doc.id)).bytes, orderedEquals(a));
    await expectLater(repository.rename(doc.id, ' '),
        throwsA(isA<DocumentStorageException>()));
  });

  test(
      'native managed copy survives repository recreation and never modifies original',
      () async {
    final temp = await Directory.systemTemp.createTemp('recall-library-test-');
    try {
      final original = await File('${temp.path}/original.pdf').writeAsBytes(a);
      final root = Directory('${temp.path}/managed');
      final repository = DocumentRepository(FileDocumentStorage(root));
      final doc = (await repository.importPdf(
              await original.readAsBytes(), 'original.pdf'))
          .document;
      await repository.rename(doc.id, 'Textbook');
      final restarted = DocumentRepository(FileDocumentStorage(root));
      expect((await restarted.list()).single.title, 'Textbook');
      expect((await restarted.open(doc.id)).bytes, orderedEquals(a));
      await restarted.delete(doc.id);
      expect(await restarted.list(), isEmpty);
      expect(await original.readAsBytes(), orderedEquals(a));
      await expectLater(restarted.storage.read('../original.pdf'),
          throwsA(isA<DocumentStorageException>()));
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
