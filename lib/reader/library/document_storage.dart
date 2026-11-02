import 'dart:typed_data';
import 'reader_document.dart';

abstract interface class DocumentStorage {
  Future<List<ReaderDocument>> list();
  Future<bool> available(String id);
  Future<Uint8List> read(String id);
  Future<void> create(ReaderDocument document, Uint8List bytes);
  Future<void> update(ReaderDocument document);

  /// False: logically removed, but physical trash cleanup needs a retry.
  Future<bool> delete(String id);
}

class MemoryDocumentStorage implements DocumentStorage {
  final documents = <String, ReaderDocument>{};
  final payloads = <String, Uint8List>{};
  @override
  Future<List<ReaderDocument>> list() async => documents.values.toList();
  @override
  Future<bool> available(String id) async => payloads.containsKey(id);
  @override
  Future<Uint8List> read(String id) async {
    final bytes = payloads[id];
    if (bytes == null) {
      throw const DocumentStorageException(
          '관리 복사본을 찾을 수 없습니다. 원본 PDF를 다시 가져와 주세요.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> create(ReaderDocument document, Uint8List bytes) async {
    documents[document.id] = document;
    payloads[document.id] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> update(ReaderDocument document) async {
    if (!documents.containsKey(document.id)) {
      throw const DocumentStorageException('문서가 삭제되었습니다.');
    }
    documents[document.id] = document;
  }

  @override
  Future<bool> delete(String id) async {
    payloads.remove(id);
    documents.remove(id);
    return true;
  }
}
