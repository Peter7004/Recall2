import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'document_storage.dart';
import 'reader_document.dart';

Future<DocumentStorage> createDocumentStorage() async {
  final String path;
  if (Platform.isAndroid) {
    final result = await const MethodChannel('recall.reader/storage')
        .invokeMethod<String>('getLibraryDirectory');
    if (result == null) {
      throw const DocumentStorageException('PDF 저장 공간을 열지 못했습니다.');
    }
    path = result;
  } else {
    path =
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}recall_reader';
  }
  final directory = await Directory(path).create(recursive: true);
  return FileDocumentStorage(directory);
}

/// Each managed directory has immutable PDF bytes and a small atomic metadata
/// file. Imports are published only after both files are written successfully.
class FileDocumentStorage implements DocumentStorage {
  FileDocumentStorage(Directory root) : root = root.absolute;
  final Directory root;
  String get _sep => Platform.pathSeparator;
  int _sequence = 0;
  String _unique(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Directory _directory(String id) {
    if (!ReaderDocument.validId(id)) {
      throw const DocumentStorageException('잘못된 문서 식별자입니다.');
    }
    return Directory('${root.path}$_sep$id');
  }

  Future<void> _purge(Directory directory) async {
    // Resolve before recursive deletion. Never follow a managed-folder symlink
    // outside this repository or touch the file selected by the user.
    final parent = await root.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!target.startsWith('$parent$_sep') || target == parent) {
      throw const DocumentStorageException('안전하지 않은 저장 경로입니다.');
    }
    await directory.delete(recursive: true);
  }

  Future<void> _checkDirectory(String id) async {
    final directory = _directory(id);
    if (!await directory.exists()) return;
    final expected = '${await root.resolveSymbolicLinks()}$_sep$id';
    final actual = await directory.resolveSymbolicLinks();
    if (Platform.isWindows
        ? actual.toLowerCase() != expected.toLowerCase()
        : actual != expected) {
      throw const DocumentStorageException('안전하지 않은 문서 저장 경로입니다.');
    }
  }

  @override
  Future<List<ReaderDocument>> list() async {
    await root.create(recursive: true);
    final documents = <ReaderDocument>[];
    await for (final entry in root.list(followLinks: false)) {
      final id = entry.path.split(_sep).last;
      if (entry is Directory && RegExp(r'^\.deleted-\d+-\d+$').hasMatch(id)) {
        try {
          await _purge(entry);
        } on FileSystemException {/* Retry next time. */}
        continue;
      }
      if (entry is! Directory || !ReaderDocument.validId(id)) continue;
      final doc = ReaderDocument.fromJson(jsonDecode(
              await File('${entry.path}${_sep}metadata.json').readAsString())
          as Map<String, dynamic>);
      if (doc.id != id) {
        throw const DocumentStorageException('문서 기록의 식별자가 일치하지 않습니다.');
      }
      documents.add(doc);
    }
    return documents;
  }

  @override
  Future<bool> available(String id) =>
      File('${_directory(id).path}${_sep}document.pdf').exists();

  @override
  Future<Uint8List> read(String id) async {
    await _checkDirectory(id);
    final file = File('${_directory(id).path}${_sep}document.pdf');
    if (!await file.exists()) {
      throw const DocumentStorageException(
          '관리 복사본을 찾을 수 없습니다. 원본 PDF를 다시 가져와 주세요.');
    }
    return file.readAsBytes();
  }

  Future<void> _atomicText(File target, String content) async {
    final pending = File('${target.path}.${_unique('pending-')}');
    try {
      await pending.writeAsString(content, flush: true);
      await pending.rename(target.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  @override
  Future<void> create(ReaderDocument document, Uint8List bytes) async {
    final destination = _directory(document.id);
    await root.create(recursive: true);
    if (await destination.exists()) {
      await _checkDirectory(document.id);
      // Repair a missing managed PDF while preserving the original metadata.
      final pending = File('${destination.path}$_sep${_unique('repair-')}');
      try {
        await pending.writeAsBytes(bytes, flush: true);
        await pending.rename('${destination.path}${_sep}document.pdf');
      } finally {
        if (await pending.exists()) await pending.delete();
      }
      return;
    }
    final pending =
        await Directory('${root.path}$_sep${_unique('.import-')}').create();
    try {
      await File('${pending.path}${_sep}document.pdf')
          .writeAsBytes(bytes, flush: true);
      await File('${pending.path}${_sep}metadata.json')
          .writeAsString(jsonEncode(document.toJson()), flush: true);
      await pending.rename(destination.path);
    } finally {
      if (await pending.exists()) await _purge(pending);
    }
  }

  @override
  Future<void> update(ReaderDocument document) async {
    await _checkDirectory(document.id);
    final directory = _directory(document.id);
    if (!await directory.exists()) {
      throw const DocumentStorageException('문서가 삭제되었습니다.');
    }
    await _atomicText(File('${directory.path}${_sep}metadata.json'),
        jsonEncode(document.toJson()));
  }

  @override
  Future<bool> delete(String id) async {
    await _checkDirectory(id);
    final directory = _directory(id);
    final trash = '${root.path}$_sep${_unique('.deleted-')}';
    // Rename is the atomic logical deletion. If it fails, repository restores
    // progress and the document remains available under its original ID.
    final removed = await directory.rename(trash);
    try {
      await _purge(removed);
      return true;
    } on FileSystemException {
      // Do not pretend all bytes were purged. UI explicitly reports this state.
      return false;
    }
  }
}
