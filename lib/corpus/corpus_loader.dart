import 'package:flutter/services.dart';
import 'corpus_stats.dart';

Future<CorpusCatalog> loadCorpusStats({AssetBundle? bundle}) async {
  try {
    final assets = bundle ?? rootBundle;
    final csv = await assets.loadString('assets/corpus/corpus_stats.csv');
    final catalog = CorpusCatalog.parse(csv);
    if (!catalog.available) return catalog;
    String metadata;
    try {
      metadata = await assets.loadString('assets/corpus/corpus_metadata.json');
    } catch (_) {
      return CorpusCatalog.unavailable('코퍼스 집계 기준 파일을 읽을 수 없습니다.');
    }
    return catalog.withMetadata(metadata, csv);
  } catch (_) {
    return CorpusCatalog.unavailable('코퍼스 파일을 읽을 수 없습니다.');
  }
}
