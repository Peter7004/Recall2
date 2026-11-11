import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:recall/corpus/corpus_stats.dart';

void main(List<String> args) {
  final paths = args.where((arg) => !arg.startsWith('--')).toList();
  if (paths.isEmpty ||
      paths.length > 2 ||
      args
          .where((arg) => arg.startsWith('--'))
          .any((arg) => arg != '--research-check')) {
    stderr.writeln(
        'Usage: dart --packages=.dart_tool/package_config.json tool/validate_corpus.dart '
        '<corpus.csv> [dictionary.csv] [--research-check]');
    exitCode = 2;
    return;
  }
  try {
    final catalog =
        CorpusCatalog.parse(File(paths.first).readAsStringSync(encoding: utf8));
    final path =
        paths.length >= 2 ? paths[1] : 'assets/vocabulary/recall_core_v1.csv';
    final rows = const CsvToListConverter(
            shouldParseNumbers: false, allowInvalid: false, eol: '\n')
        .convert(File(path)
            .readAsStringSync(encoding: utf8)
            .replaceFirst('\uFEFF', '')
            .replaceAll('\r\n', '\n'));
    final index = rows.isEmpty ? -1 : rows.first.indexOf('term_en');
    if (index < 0) throw const FormatException('사전 CSV에 term_en 열이 없습니다.');
    final terms = <String>[];
    for (final row in rows.skip(1)) {
      if (row.length == 1 && row.single.toString().trim().isEmpty) continue;
      if (row.length != rows.first.length) {
        throw const FormatException('사전 CSV 열 수 오류');
      }
      terms.add(row[index].toString());
    }
    final research = args.contains('--research-check')
        ? catalog.verifyResearch(terms)
        : null;
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      ...catalog.diagnose(terms),
      if (research != null) 'researchErrors': research,
    }));
    exitCode = catalog.errors.isNotEmpty || (research?.isNotEmpty ?? false)
        ? 2
        : catalog.available
            ? 0
            : 3;
  } on FileSystemException catch (error) {
    stderr.writeln('파일 읽기 실패: ${error.path}');
    exitCode = 2;
  } on FormatException catch (error) {
    stderr.writeln('파일 형식/UTF-8 오류: ${error.message}');
    exitCode = 2;
  }
}
