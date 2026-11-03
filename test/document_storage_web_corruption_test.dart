@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:recall/reader/library/document_repository.dart';
import 'package:recall/reader/library/document_storage_web.dart';
import 'package:recall/reader/library/reader_document.dart';

Future<web.IDBDatabase> _open(String name) {
  final done = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(name);
  request.onsuccess =
      ((web.Event _) => done.complete(request.result as web.IDBDatabase)).toJS;
  request.onerror =
      ((web.Event _) => done.completeError(StateError('open failed'))).toJS;
  return done.future;
}

Future<JSAny?> _transaction(web.IDBDatabase db, String mode,
    web.IDBRequest Function(web.IDBObjectStore) action) {
  final done = Completer<JSAny?>();
  final tx = db.transaction('documents'.toJS, mode);
  JSAny? result;
  tx.oncomplete = ((web.Event _) => done.complete(result)).toJS;
  tx.onabort = ((web.Event _) =>
      done.completeError(StateError('transaction failed'))).toJS;
  final request = action(tx.objectStore('documents'));
  request.onsuccess = ((web.Event _) {
    result = request.result;
  }).toJS;
  return done.future;
}

void main() {
  test(
      'IndexedDB isolates bad JSON, non-string values and mismatched IDs without writes',
      () async {
    final name =
        'recall-corruption-test-${DateTime.now().microsecondsSinceEpoch}';
    final storage = IndexedDocumentStorage(databaseName: name);
    final repository = DocumentRepository(storage);
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nhealthy'));
    final healthy = (await repository.importPdf(bytes, 'healthy.pdf')).document;
    final db = await _open(name);
    try {
      final damaged = ['b' * 64, 'c' * 64, 'd' * 64];
      final raw = <JSAny>[
        '{broken'.toJS,
        42.toJS,
        jsonEncode(healthy.toJson()).toJS
      ];
      for (var i = 0; i < damaged.length; i++) {
        await _transaction(
            db, 'readwrite', (store) => store.put(raw[i], damaged[i].toJS));
      }
      expect((await repository.list()).map((d) => d.id), [healthy.id]);
      expect(
          repository.damagedEntries.map((d) => d.id), unorderedEquals(damaged));
      expect((await repository.open(healthy.id)).bytes, orderedEquals(bytes));
      for (var i = 0; i < damaged.length; i++) {
        await expectLater(repository.open(damaged[i]),
            throwsA(isA<DocumentStorageException>()));
        final saved =
            await _transaction(db, 'readonly', (s) => s.get(damaged[i].toJS));
        expect(saved.dartify(), raw[i].dartify());
      }
      await _transaction(
          db, 'readwrite', (s) => s.put('null'.toJS, healthy.id.toJS));
      await expectLater(repository.importPdf(bytes, 'replacement.pdf'),
          throwsA(isA<DocumentStorageException>()));
      final saved =
          await _transaction(db, 'readonly', (s) => s.get(healthy.id.toJS));
      expect((saved as JSString).toDart, 'null');
      expect(await storage.read(healthy.id), orderedEquals(bytes));
    } finally {
      db.close();
      // Storage connection is intentionally retained until this browser closes;
      // database name is unique, so no other tests/users are touched.
    }
  });
}
