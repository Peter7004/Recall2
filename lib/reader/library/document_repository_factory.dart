import 'document_repository.dart';
import 'document_storage_stub.dart'
    if (dart.library.io) 'document_storage_io.dart'
    if (dart.library.js_interop) 'document_storage_web.dart' as platform;

Future<DocumentRepository> createDocumentRepository() async =>
    DocumentRepository(await platform.createDocumentStorage());
