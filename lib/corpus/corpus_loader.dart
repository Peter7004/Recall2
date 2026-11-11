import 'package:flutter/services.dart';
import 'corpus_stats.dart';

Future<CorpusCatalog> loadCorpusStats({AssetBundle? bundle}) async {
  try {
    return CorpusCatalog.parse(await (bundle ?? rootBundle)
        .loadString('assets/corpus/corpus_stats.csv'));
  } catch (_) {
    return CorpusCatalog.unavailable('코퍼스 파일을 읽을 수 없습니다.');
  }
}
