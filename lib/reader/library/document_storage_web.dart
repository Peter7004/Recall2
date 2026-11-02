import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'document_storage.dart';
import 'reader_document.dart';

Future<DocumentStorage> createDocumentStorage() async =>
    IndexedDocumentStorage();

/// Metadata and PDF bytes live in separate stores, so listing documents does not
/// deserialize every PDF. Import/deletion use a transaction covering both stores.
class IndexedDocumentStorage implements DocumentStorage {
  IndexedDocumentStorage({this.databaseName = 'recall.reader.library.v1'});
  final String databaseName;
  Future<web.IDBDatabase>? _connection;

  Future<web.IDBDatabase> get _database async {
    try {
      return await (_connection ??= _open());
    } catch (_) {
      _connection = null;
      rethrow;
    }
  }

  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      db.createObjectStore('documents');
      db.createObjectStore('bytes');
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      db.onversionchange = ((web.Event _) => db.close()).toJS;
      if (completer.isCompleted) {
        db.close();
      } else {
        completer.complete(db);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(const DocumentStorageException(
            '브라우저 PDF 저장소를 열지 못했습니다. 사이트 저장 공간과 브라우저 설정을 확인해 주세요.'));
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
            const DocumentStorageException('다른 Recall 탭을 닫은 뒤 다시 시도해 주세요.'));
      }
    }).toJS;
    return completer.future;
  }

  Future<T> _run<T>(
      List<String> stores,
      String mode,
      web.IDBRequest Function(web.IDBTransaction) action,
      T Function(JSAny?) decode) async {
    final db = await _database;
    final transaction =
        db.transaction(stores.map((e) => e.toJS).toList().toJS, mode);
    final completer = Completer<T>();
    JSAny? value;
    transaction.oncomplete = ((web.Event _) {
      if (completer.isCompleted) return;
      try {
        completer.complete(decode(value));
      } catch (error, trace) {
        completer.completeError(error, trace);
      }
    }).toJS;
    void fail() {
      if (!completer.isCompleted) {
        completer.completeError(DocumentStorageException(
            transaction.error?.name == 'QuotaExceededError'
                ? '브라우저 저장 공간이 부족합니다. 다른 문서를 정리한 뒤 다시 시도해 주세요.'
                : 'PDF 저장 작업에 실패했습니다. 브라우저 저장 공간과 접근 설정을 확인해 주세요.'));
      }
    }

    // Request errors abort the transaction; onabort sees the final error code.
    transaction.onabort = ((web.Event _) => fail()).toJS;
    try {
      final request = action(transaction);
      request.onsuccess = ((web.Event _) {
        value = request.result;
      }).toJS;
    } catch (error, trace) {
      transaction.abort();
      if (!completer.isCompleted) completer.completeError(error, trace);
    }
    return completer.future;
  }

  @override
  Future<List<ReaderDocument>> list() => _run(
      ['documents'],
      'readonly',
      (tx) => tx.objectStore('documents').getAll(),
      (value) => (value as JSArray<JSString>)
          .toDart
          .map((raw) => ReaderDocument.fromJson(
              jsonDecode(raw.toDart) as Map<String, dynamic>))
          .toList());
  @override
  Future<bool> available(String id) => _run(
      ['bytes'],
      'readonly',
      (tx) => tx.objectStore('bytes').getKey(id.toJS),
      (value) => value != null && !value.isUndefined);
  @override
  Future<Uint8List> read(String id) =>
      _run(['bytes'], 'readonly', (tx) => tx.objectStore('bytes').get(id.toJS),
          (value) {
        if (value == null || value.isUndefined) {
          throw const DocumentStorageException(
              '관리 복사본을 찾을 수 없습니다. 원본 PDF를 다시 가져와 주세요.');
        }
        return (value as JSUint8Array).toDart;
      });
  @override
  Future<void> create(ReaderDocument document, Uint8List bytes) =>
      _run<void>(['documents', 'bytes'], 'readwrite', (tx) {
        tx.objectStore('bytes').put(bytes.toJS, document.id.toJS);
        return tx
            .objectStore('documents')
            .put(jsonEncode(document.toJson()).toJS, document.id.toJS);
      }, (_) {});
  @override
  Future<void> update(ReaderDocument document) => _run<void>(
      ['documents'],
      'readwrite',
      (tx) => tx
          .objectStore('documents')
          .put(jsonEncode(document.toJson()).toJS, document.id.toJS),
      (_) {});
  @override
  Future<bool> delete(String id) =>
      _run(['documents', 'bytes'], 'readwrite', (tx) {
        tx.objectStore('bytes').delete(id.toJS);
        return tx.objectStore('documents').delete(id.toJS);
      }, (_) => true);
}
