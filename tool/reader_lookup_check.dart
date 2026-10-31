import 'dart:convert';
import 'package:recall/reader/terminology_lookup.dart';
import 'package:recall/vocabulary.dart';

void main() {
  ReaderConcept concept(String id, String en, String ko) =>
      ReaderConcept(RecallCard.fromJson({
        'id': id,
        'front': en,
        'meaning': ko,
        'termEnglish': en,
        'meanings': [
          {
            'id': '$id-m',
            'meaning_ko': ko,
            'definition_en': 'Existing definition',
            'explanation_ko': '기존 설명'
          }
        ]
      }));
  final concepts = [
    concept('p', 'Power', '전력'),
    concept('pf', 'Power factor', '역률'),
    concept('m', 'Magnetic flux density', '자속밀도'),
    concept('i', 'Induction motor', '유도 전동기'),
    concept('t', 'Transient response', '과도응답'),
    concept('x', 'Transformer', '변압기')
  ];
  final before = jsonEncode(concepts.map((c) => c.card.toJson()).toList());
  final lookup = DictionaryTerminologyLookup(concepts);
  final cases = <String, List<String>>{
    'POWER FACTOR': ['pf'],
    'powerful': [],
    'power factor': ['pf'],
    '역률': ['pf'],
    '자속밀도': ['m'],
    '유도전동기의': ['i'],
    '유도 전동기': ['i'],
    '과도응답을': ['t'],
    '변압기에서는': ['x'],
    '역률계산': [],
    '새로운 미등록 용어': [],
    'Power factor와 자속밀도': ['pf', 'm'],
    'Power factor / 과도응답을': ['pf', 't'],
    'Magnetic\nflux density': ['m'],
  };
  for (final test in cases.entries) {
    final actual =
        lookup.lookup(test.key).map((m) => m.concept.card.id).toList();
    if (jsonEncode(actual) != jsonEncode(test.value)) {
      throw StateError('${test.key}: expected ${test.value}, got $actual');
    }
  }
  final ambiguous = DictionaryTerminologyLookup([
    concept('a', 'First meaning', '공통용어'),
    concept('b', 'Second meaning', '공통용어')
  ]);
  if (ambiguous.lookup('공통용어').length != 2) throw StateError('Ambiguity lost');
  if (before != jsonEncode(concepts.map((c) => c.card.toJson()).toList())) {
    throw StateError('Dictionary modified');
  }
  // ignore: avoid_print
  print('${cases.length + 2} terminology checks passed; dictionary unchanged.');
}
