import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';

String _string(Object? value, int max, {bool empty = false}) {
  if (value is! String ||
      value.length > max ||
      (!empty && value.trim().isEmpty)) {
    throw const FormatException('Invalid Reader learning text');
  }
  return value;
}

int _integer(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('Invalid Reader learning index');
  }
  return value;
}

DateTime _date(Object? value) {
  final text = _string(value, 64);
  final result = DateTime.tryParse(text);
  if (result == null || result.toIso8601String() != text) {
    throw const FormatException('Invalid Reader learning timestamp');
  }
  return result;
}

/// A dictionary snapshot, usable even if the original card is later removed.
class ReaderSavedTerm {
  ReaderSavedTerm({
    required this.cardId,
    required this.term,
    required this.meaning,
    required this.definition,
    required this.explanation,
    required this.createdAt,
  }) {
    _string(cardId, 512);
    _string(term, 2048);
    _string(meaning, 32768, empty: true);
    _string(definition, 32768, empty: true);
    _string(explanation, 32768, empty: true);
  }

  final String cardId, term, meaning, definition, explanation;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'term': term,
        'meaning': meaning,
        'definition': definition,
        'explanation': explanation,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReaderSavedTerm.fromJson(Map<String, dynamic> json) =>
      ReaderSavedTerm(
        cardId: _string(json['cardId'], 512),
        term: _string(json['term'], 2048),
        meaning: _string(json['meaning'], 32768, empty: true),
        definition: _string(json['definition'], 32768, empty: true),
        explanation: _string(json['explanation'], 32768, empty: true),
        createdAt: _date(json['createdAt']),
      );
}

/// One exact text range on a page. Rectangles are normalized PDF page geometry.
class ReaderOccurrence {
  ReaderOccurrence({
    required this.cardId,
    required this.documentId,
    required this.documentTitle,
    required this.text,
    required this.context,
    required this.page,
    required this.start,
    required this.end,
    required List<Rect> rects,
    required this.createdAt,
  }) : rects = List.unmodifiable(rects) {
    _string(cardId, 512);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(documentId)) {
      throw const FormatException('Invalid document SHA256');
    }
    _string(documentTitle, 4096);
    _string(text, 32768);
    _string(context, 65536, empty: true);
    _integer(page, 1, 1000000);
    _integer(start, 0, 2147483646);
    _integer(end, start + 1, 2147483647);
    if (rects.isEmpty || rects.length > 4096) {
      throw const FormatException('Source rectangles are required and bounded');
    }
    for (final rect in rects) {
      if (![rect.left, rect.top, rect.right, rect.bottom].every(
            (v) => v.isFinite && v >= 0 && v <= 1,
          ) ||
          rect.width <= 0 ||
          rect.height <= 0) {
        throw const FormatException('Invalid normalized source rectangle');
      }
    }
  }

  final String cardId, documentId, documentTitle, text, context;
  final int page, start, end;
  final List<Rect> rects;
  final DateTime createdAt;

  String get id => sha256
      .convert(utf8.encode(jsonEncode([cardId, documentId, page, start, end])))
      .toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardId': cardId,
        'documentId': documentId,
        'documentTitle': documentTitle,
        'text': text,
        'context': context,
        'page': page,
        'start': start,
        'end': end,
        'rects': rects.map((r) => [r.left, r.top, r.right, r.bottom]).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReaderOccurrence.fromJson(Map<String, dynamic> json) {
    final rawRects = json['rects'];
    if (rawRects is! List || rawRects.length > 4096) {
      throw const FormatException('Invalid source rectangles');
    }
    final result = ReaderOccurrence(
      cardId: _string(json['cardId'], 512),
      documentId: _string(json['documentId'], 64),
      documentTitle: _string(json['documentTitle'], 4096),
      text: _string(json['text'], 32768),
      context: _string(json['context'], 65536, empty: true),
      page: _integer(json['page'], 1, 1000000),
      start: _integer(json['start'], 0, 2147483646),
      end: _integer(json['end'], 1, 2147483647),
      rects: rawRects.map((raw) {
        if (raw is! List || raw.length != 4 || raw.any((v) => v is! num)) {
          throw const FormatException('Invalid source rectangle');
        }
        return Rect.fromLTRB(
          (raw[0] as num).toDouble(),
          (raw[1] as num).toDouble(),
          (raw[2] as num).toDouble(),
          (raw[3] as num).toDouble(),
        );
      }).toList(),
      createdAt: _date(json['createdAt']),
    );
    if (json['id'] != result.id) {
      throw const FormatException('Source identity does not match location');
    }
    return result;
  }
}
