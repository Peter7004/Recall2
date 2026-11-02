import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';
import '../reader_progress.dart';
import 'reader_document.dart';
import 'document_storage.dart';

class DocumentRepository {
  DocumentRepository(this.storage,
      {Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;
  final DocumentStorage storage;
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
    if (doc == null) throw const DocumentStorageException('문서를 찾을 수 없습니다.');
    return doc;
  }

  Future<bool> delete(String id) => _serial(() async {
        await _find(id);
        final preferences = await _preferences();
        final key = 'recall.reader.progress.v1.$id';
        final previous = preferences.getString(key);
        if (!await preferences.remove(key)) {
          await preferences.reload();
          throw const DocumentStorageException('읽기 기록을 지우지 못해 PDF 삭제를 취소했습니다.');
        }
        try {
          return await storage.delete(id);
        } catch (_) {
          if (previous != null && !await preferences.setString(key, previous)) {
            throw const DocumentStorageException(
                'PDF는 유지되었지만 읽기 기록을 복원하지 못했습니다.');
          }
          rethrow;
        }
      });
}
