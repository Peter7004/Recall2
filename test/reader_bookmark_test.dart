import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/reader/library/document_repository.dart';
import 'package:recall/reader/library/document_storage.dart';
import 'package:recall/reader/library/reader_document.dart';
import 'package:recall/reader/page_bookmark.dart';
import 'package:recall/reader/reader_progress.dart';

class DeleteFailureStorage extends MemoryDocumentStorage {
  bool fail = true;
  @override
  Future<bool> delete(String id) async {
    if (fail) throw const DocumentStorageException('injected deletion failure');
    return super.delete(id);
  }
}

void main() {
  Uint8List pdf(String label) =>
      Uint8List.fromList(utf8.encode('%PDF-1.7\n$label'));
  ReaderPageBookmark bookmark(int page) => ReaderPageBookmark.fromProgress(
      ReaderProgress(page: page, x: .2, y: .7, zoom: 2, paged: true));
  setUp(() => SharedPreferences.setMockInitialValues(
      {'recall.data.v3': 'word bookmarks unchanged'}));

  test('bookmarks persist independently, sort and toggle once per page',
      () async {
    final storage = MemoryDocumentStorage();
    final repository = DocumentRepository(storage);
    final a = (await repository.importPdf(pdf('A'), 'same.pdf')).document;
    final b = (await repository.importPdf(pdf('B'), 'same.pdf')).document;
    await repository.setPageCount(a.id, 10);
    await repository.togglePageBookmark(a.id, bookmark(8));
    await repository.togglePageBookmark(a.id, bookmark(2));
    await repository.togglePageBookmark(b.id, bookmark(3));
    final restarted = DocumentRepository(storage);
    expect((await restarted.pageBookmarks(a.id)).map((b) => b.page), [2, 8]);
    final restored = (await restarted.pageBookmarks(a.id)).first;
    expect(restored.position(paged: false).y, .7);
    expect(restored.position(paged: false).paged, isFalse);
    await restarted.togglePageBookmark(a.id, bookmark(2));
    expect((await restarted.pageBookmarks(a.id)).map((b) => b.page), [8]);
    expect((await restarted.pageBookmarks(b.id)).single.page, 3);
    await expectLater(restarted.togglePageBookmark(a.id, bookmark(11)),
        throwsA(isA<DocumentStorageException>()));
  });

  test(
      'document deletion rolls bookmarks/progress back on failure and cleans only target on success',
      () async {
    final storage = DeleteFailureStorage();
    final repository = DocumentRepository(storage);
    final a = (await repository.importPdf(pdf('A'), 'A.pdf')).document;
    final b = (await repository.importPdf(pdf('B'), 'B.pdf')).document;
    await const ReaderProgress(page: 2).save(a.id);
    await repository.togglePageBookmark(a.id, bookmark(2));
    await repository.togglePageBookmark(b.id, bookmark(3));
    await expectLater(
        repository.delete(a.id), throwsA(isA<DocumentStorageException>()));
    expect((await repository.pageBookmarks(a.id)).single.page, 2);
    expect((await ReaderProgress.load(a.id))!.page, 2);
    storage.fail = false;
    await repository.delete(a.id);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DocumentRepository.pageBookmarkKey(a.id)), isNull);
    expect(await ReaderProgress.load(a.id), isNull);
    expect((await repository.pageBookmarks(b.id)).single.page, 3);
    expect(prefs.getString('recall.data.v3'), 'word bookmarks unchanged');
  });

  test('corrupt bookmark records are reported and never overwritten by toggle',
      () async {
    final repository = DocumentRepository(MemoryDocumentStorage());
    final doc = (await repository.importPdf(pdf('A'), 'A.pdf')).document;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        DocumentRepository.pageBookmarkKey(doc.id), '{broken');
    await expectLater(repository.pageBookmarks(doc.id),
        throwsA(isA<DocumentStorageException>()));
    await expectLater(repository.togglePageBookmark(doc.id, bookmark(2)),
        throwsA(isA<DocumentStorageException>()));
    expect(
        prefs.getString(DocumentRepository.pageBookmarkKey(doc.id)), '{broken');
    expect(await repository.storage.available(doc.id), isTrue);
  });
}
