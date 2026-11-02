class ReaderDocument {
  const ReaderDocument(
      {required this.id,
      required this.title,
      required this.byteSize,
      required this.importedAt,
      required this.lastOpenedAt,
      this.pageCount});
  final String id, title;
  final int byteSize;
  final DateTime importedAt, lastOpenedAt;
  final int? pageCount;

  static bool validId(String id) => RegExp(r'^[a-f0-9]{64}$').hasMatch(id);

  ReaderDocument copyWith(
          {String? title, DateTime? lastOpenedAt, int? pageCount}) =>
      ReaderDocument(
          id: id,
          title: title ?? this.title,
          byteSize: byteSize,
          importedAt: importedAt,
          lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
          pageCount: pageCount ?? this.pageCount);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'byteSize': byteSize,
        'importedAt': importedAt.toUtc().toIso8601String(),
        'lastOpenedAt': lastOpenedAt.toUtc().toIso8601String(),
        'pageCount': pageCount
      };

  factory ReaderDocument.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final title = json['title'] as String;
    final size = json['byteSize'] as int;
    final pages = json['pageCount'] as int?;
    if (!validId(id) ||
        title.trim().isEmpty ||
        size <= 0 ||
        (pages != null && pages < 1)) {
      throw const FormatException('문서 기록이 손상되었습니다.');
    }
    return ReaderDocument(
        id: id,
        title: title,
        byteSize: size,
        pageCount: pages,
        importedAt: DateTime.parse(json['importedAt'] as String),
        lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String));
  }
}

class DocumentStorageException implements Exception {
  const DocumentStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}
