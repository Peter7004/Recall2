import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderSettings {
  const ReaderSettings({this.highlightAll = false, this.paged = false});
  final bool highlightAll, paged;
  static const storageKey = 'recall.reader.settings.v1';
  static Future<ReaderSettings> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null) return const ReaderSettings();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['highlightAll'] is! bool || json['paged'] is! bool) {
      throw const FormatException('Reader display settings are invalid');
    }
    return ReaderSettings(
        highlightAll: json['highlightAll'] as bool,
        paged: json['paged'] as bool);
  }

  Future<void> save() async {
    if (!await (await SharedPreferences.getInstance()).setString(storageKey,
        jsonEncode({'highlightAll': highlightAll, 'paged': paged}))) {
      throw StateError('Reader settings could not be saved');
    }
  }
}
