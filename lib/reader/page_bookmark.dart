import 'reader_progress.dart';

/// A PDF page/viewport bookmark, separate from dictionary-word bookmarks.
class ReaderPageBookmark {
  const ReaderPageBookmark(
      {required this.page,
      required this.x,
      required this.y,
      required this.zoom,
      required this.createdAt});
  final int page;
  final double x, y, zoom;
  final DateTime createdAt;

  factory ReaderPageBookmark.fromProgress(ReaderProgress progress) =>
      ReaderPageBookmark(
          page: progress.page,
          x: progress.x,
          y: progress.y,
          zoom: progress.zoom,
          createdAt: DateTime.now());

  ReaderProgress position({required bool paged}) =>
      ReaderProgress(page: page, x: x, y: y, zoom: zoom, paged: paged);

  Map<String, Object> toJson() => {
        'page': page,
        'x': x,
        'y': y,
        'zoom': zoom,
        'createdAt': createdAt.toUtc().toIso8601String()
      };

  factory ReaderPageBookmark.fromJson(Map<String, dynamic> json) {
    final page = json['page'] as int;
    final x = (json['x'] as num).toDouble();
    final y = (json['y'] as num).toDouble();
    final zoom = (json['zoom'] as num).toDouble();
    if (page < 1 ||
        !x.isFinite ||
        !y.isFinite ||
        !zoom.isFinite ||
        x < 0 ||
        x > 1 ||
        y < 0 ||
        y > 1 ||
        zoom <= 0) {
      throw const FormatException('잘못된 페이지 북마크입니다.');
    }
    return ReaderPageBookmark(
        page: page,
        x: x,
        y: y,
        zoom: zoom,
        createdAt: DateTime.parse(json['createdAt'] as String));
  }
}
