import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';
import '../reader_progress.dart';
import '../page_bookmark.dart';
import 'reader_document.dart';
import 'document_storage.dart';

class DocumentRepository {
  DocumentRepository(this.storage,
      {Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;
  final DocumentStorage storage;
  List<DamagedDocumentEntry> get damagedEntries =>
      storage is DocumentStorageDiagnostics
          ? (storage as DocumentStorageDiagnostics).damagedEntries
          : const [];
  final Future<SharedPreferences> Function() _preferences;
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<ReaderDocument>> list() => _serial(() async {
        final docs = await storage.list();
        docs.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
        return docs;
      });

  Future<({ReaderDocument document, bool duplicate})> importPdf(
          Uint8List bytes, String filename) =>
      _serial(() async {
        if (bytes.isEmpty ||
            !latin1.decode(bytes.take(1024).toList()).contains('%PDF-')) {
          throw const DocumentStorageException('PDF 파일 형식을 확인해 주세요.');
        }
        final id = await compute(ReaderProgress.documentId, bytes);
        final existing =
            (await storage.list()).where((doc) => doc.id == id).firstOrNull;
        if (damagedEntries.any((entry) => entry.id == id)) {
          throw const DocumentStorageException(
              '이 PDF의 문서 기록이 손상되었습니다. 기존 파일과 기록은 변경하지 않았습니다.');
        }
        if (existing != null) {
          if (!await storage.available(id)) {
            await storage.create(existing, bytes);
          }
          return (document: existing, duplicate: true);
        }
        final title = filename.trim();
        final now = DateTime.now();
        final doc = ReaderDocument(
            id: id,
            title: title.isEmpty
                ? '제목 없는 PDF'
                : title.substring(0, title.length.clamp(0, 200)),
            byteSize: bytes.length,
            importedAt: now,
            lastOpenedAt: now);
        await storage.create(doc, bytes);
        return (document: doc, duplicate: false);
      });

  Future<({ReaderDocument document, Uint8List bytes})> open(String id) =>
      _serial(() async {
        final doc = await _find(id);
        final bytes = await storage.read(id);
        final updated = doc.copyWith(lastOpenedAt: DateTime.now());
        await storage.update(updated);
        return (document: updated, bytes: bytes);
      });

  Future<void> rename(String id, String title) => _serial(() async {
        if (title.trim().isEmpty || title.trim().length > 200) {
          throw const DocumentStorageException('문서 제목을 1~200자로 입력해 주세요.');
        }
        await storage.update((await _find(id)).copyWith(title: title.trim()));
      });

  Future<void> setPageCount(String id, int count) => _serial(() async {
        final doc = await _find(id);
        if (count > 0 && doc.pageCount != count) {
          await storage.update(doc.copyWith(pageCount: count));
        }
      });

  Future<ReaderDocument> _find(String id) async {
    if (!ReaderDocument.validId(id)) {
      throw const DocumentStorageException('잘못된 문서 식별자입니다.');
    }
    final doc = (await storage.list()).where((doc) => doc.id == id).firstOrNull;
    if (damagedEntries.any((entry) => entry.id == id)) {
      throw const DocumentStorageException(
          '문서 기록을 읽지 못했습니다. 기존 파일과 기록은 변경하지 않았습니다.');
    }
    if (doc == null) throw const DocumentStorageException('문서를 찾을 수 없습니다.');
    return doc;
  }

  static String pageBookmarkKey(String id) =>
      'recall.reader.pageBookmarks.v1.$id';

  List<ReaderPageBookmark> _decodeBookmarks(String? raw) {
    if (raw == null) return [];
    try {
      final items = (jsonDecode(raw) as List)
          .map((value) =>
              ReaderPageBookmark.fromJson(value as Map<String, dynamic>))
          .toList();
      if (items.map((b) => b.page).toSet().length != items.length) {
        throw const FormatException('Duplicate page bookmarks');
      }
      items.sort((a, b) => a.page.compareTo(b.page));
      return items;
    } catch (_) {
      throw const DocumentStorageException(
          '페이지 북마크 기록을 읽지 못했습니다. 기존 기록은 변경하지 않았습니다.');
    }
  }

  Future<List<ReaderPageBookmark>> pageBookmarks(String id) =>
      _serial(() async {
        await _find(id);
        return _decodeBookmarks(
            (await _preferences()).getString(pageBookmarkKey(id)));
      });

  Future<void> _writeBookmarks(SharedPreferences preferences, String id,
      List<ReaderPageBookmark> bookmarks) async {
    if (!await preferences.setString(pageBookmarkKey(id),
        jsonEncode(bookmarks.map((b) => b.toJson()).toList()))) {
      await preferences.reload();
      throw const DocumentStorageException('페이지 북마크를 저장하지 못했습니다.');
    }
  }

  Future<List<ReaderPageBookmark>> togglePageBookmark(
          String id, ReaderPageBookmark bookmark) =>
      _serial(() async {
        final doc = await _find(id);
        // Validate even caller-created objects before persisting them.
        ReaderPageBookmark.fromJson(bookmark.toJson());
        if (doc.pageCount != null && bookmark.page > doc.pageCount!) {
          throw const DocumentStorageException('문서 범위를 벗어난 페이지입니다.');
        }
        final preferences = await _preferences();
        final bookmarks =
            _decodeBookmarks(preferences.getString(pageBookmarkKey(id)));
        if (bookmarks.any((item) => item.page == bookmark.page)) {
          bookmarks.removeWhere((item) => item.page == bookmark.page);
        } else {
          bookmarks.add(bookmark);
        }
        bookmarks.sort((a, b) => a.page.compareTo(b.page));
        await _writeBookmarks(preferences, id, bookmarks);
        return bookmarks;
      });

  Future<List<ReaderPageBookmark>> removePageBookmark(String id, int page) =>
      _serial(() async {
        await _find(id);
        final preferences = await _preferences();
        final bookmarks =
            _decodeBookmarks(preferences.getString(pageBookmarkKey(id)));
        bookmarks.removeWhere((item) => item.page == page);
        await _writeBookmarks(preferences, id, bookmarks);
        return bookmarks;
      });

  Future<bool> delete(String id) => _serial(() async {
        await _find(id);
        final preferences = await _preferences();
        final previous = {
          for (final key in [
            'recall.reader.progress.v1.$id',
            pageBookmarkKey(id)
          ])
            key: preferences.getString(key),
        };
        try {
          for (final key in previous.keys) {
            if (!await preferences.remove(key)) {
              throw const DocumentStorageException(
                  '독서 기록을 지우지 못해 PDF 삭제를 취소했습니다.');
            }
          }
          return await storage.delete(id);
        } catch (_) {
          await preferences.reload();
          for (final entry in previous.entries) {
            if (entry.value != null &&
                !await preferences.setString(entry.key, entry.value!)) {
              throw const DocumentStorageException(
                  'PDF는 유지되었지만 독서 기록 일부를 복원하지 못했습니다.');
            }
          }
          rethrow;
        }
      });
}
