import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Separate namespace: never reads or overwrites the terminology database.
class ReaderProgress {
  const ReaderProgress(
      {this.page = 1,
      this.x = .5,
      this.y = .5,
      this.zoom = 1,
      this.paged = false});

  final int page;
  final double x, y, zoom;
  final bool paged;

  static String documentId(Uint8List bytes) => sha256.convert(bytes).toString();

  static Future<ReaderProgress?> load(String id) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('recall.reader.progress.v1.$id');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final page = (data['page'] as num).toInt();
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();
      final zoom = (data['zoom'] as num).toDouble();
      if (page < 1 ||
          !x.isFinite ||
          !y.isFinite ||
          !zoom.isFinite ||
          zoom <= 0) {
        return null;
      }
      return ReaderProgress(
          page: page,
          x: x.clamp(0, 1),
          y: y.clamp(0, 1),
          zoom: zoom,
          paged: data['paged'] == true);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String id) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
        'recall.reader.progress.v1.$id',
        jsonEncode({
          'page': page,
          'x': x,
          'y': y,
          'zoom': zoom,
          'paged': paged,
        }));
    if (!ok) throw StateError('Reading position could not be saved');
  }
}
