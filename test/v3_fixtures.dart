import 'package:csv/csv.dart';
import 'package:recall/recall_store.dart';

String v3Csv(List<Map<String, String>> entries) =>
    const ListToCsvConverter(eol: '\n').convert([
      recallV3Columns,
      for (final entry in entries)
        [for (final column in recallV3Columns) entry[column] ?? ''],
    ]);
