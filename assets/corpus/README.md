# 코퍼스 통계 추가 방법

현재 `corpus_stats.csv`에는 2026-11-11 재집계의 **834개 실제 용어별 잠정 채택 TF·DF**가 있습니다.
교재·강의자료 PDF **22개 파일**, 논문 **초록 후보 639개** 기준입니다.
논문 전체 본문이나 서로 독립적인 교재22권의 빈도가 아닙니다.

`corpus_metadata.json`은 CSV 해시, 자료 수, 집계 기준, 원본 파일 해시와 용어별
의미 보류 TF·DF를 보관합니다. 자동 전공문맥 판정의 잠정값이며 전문가 검수 완료값이 아닙니다.
보류14,733회(PDF)·2,130회(초록)는 채택값과 추천 정렬에서 제외합니다.
채택 DF와 보류 DF는 같은 문서를 포함하므로 더하지 않습니다.
PDF 전체 교재·장별 파일의 내용 중첩과 초록 후보의 인적 검토 미완료 상태는 남아 있습니다.

## 출처와 재현

다른 채팅의 `recall-recount-20261111` 폴더에서 `recount.json`, `manifest.json`,
`occurrences.jsonl`을 사용했습니다. 원문86,182개 출현 기록을 다시 합산하고
661개 문서 및 원래 CSV들의 SHA256을 대조한 후 앱용 통계만 추출했습니다.
원문, 문맥 인용문, 로컬 경로, 정의·뜻은 이 asset에 넣지 않습니다.

```powershell
python tool/import_corpus_recount.py path/to/recall-recount-20261111
dart --packages=.dart_tool/package_config.json tool/validate_corpus.dart assets/corpus/corpus_stats.csv --recount-check
```

최신 채택 기준: 공통225 / PDF만326 / 초록만37 / 양쪽 채택0 246.
기존 포스터의210/276/45/303은 이전 KWIC 집계이며 새 값의 검증 기준으로 섞지 않습니다.

## 외부 파일 형식

UTF-8 CSV를 다음 5개 열 순서로 준비합니다.

```csv
term_en,textbook_tf,textbook_df,abstract_tf,abstract_df
```

- 모든 수치는 0 이상의 정수이며 누락값은 허용하지 않습니다. 모르는 값을 0으로 채우지 마세요.
- 각 자료에서 DF ≤ TF여야 하며, TF가 0이면 DF도 0, TF가 양수이면 DF도 양수여야 합니다.
- 현재 데이터의 미관측은 네 채택 통계가 모두0인 행이며, 보류 용례가 있을 수 있습니다.
  통계 행이 없는 단어는 미제공입니다.
- 매칭은 앞뒤 공백 제거, 연속 공백 통일, 소문자 비교만 수행합니다. 하이픈/복수형/약어는 별개입니다.
- 정규화한 중복 용어, 숫자 오류, 잘못된 CSV가 하나라도 있으면 파일 전체를 비활성화합니다.
- 기존 13열 단어 CSV나 사용자 저장 데이터는 수정하지 않습니다.

프로젝트에서 `flutter pub get`을 실행한 뒤 검사합니다. Windows에서는 설치한 Dart 실행 파일 경로를 사용할 수 있습니다.

```powershell
dart --packages=.dart_tool/package_config.json tool/validate_corpus.dart path/to/actual_stats.csv
dart --packages=.dart_tool/package_config.json tool/validate_corpus.dart path/to/actual_stats.csv assets/vocabulary/recall_core_v1.csv --research-check
```

첫 명령은 오류, 매칭 수, 미매칭 통계, 통계 없는 사전 용어, 사전 중복, 관측 집계를 JSON으로 출력합니다.
`--research-check`는 이전 KWIC 기준834개 완전 매칭 및210/276/45/303을 검사합니다.
현재 재집계에는 `--recount-check`를 사용합니다. 이 옵션은 metadata와 CSV 해시도 검사합니다.
집계는 검증 기준일 뿐 개별 TF·DF를 만들어 내는 데 사용하지 않습니다.
종료 코드: 0=유효한 통계 파일, 2=형식/연구 검증 실패, 3=헤더만 있어 데이터 미제공.
부분 통계 파일은 일반 검사를 통과할 수 있으므로 배포 전 해당 집계 기준의 검증도 실행하세요.

검증된 실제 CSV와 이에 대응하는 metadata를 함께 교체하고 앱을 다시 빌드합니다.
metadata가 누락되거나 CSV와 맞지 않으면 앱은 통계를 숨기며 사용자 저장 데이터는 유지합니다.
이미 asset 경로가 등록돼 있어 추가 DB/서버 설정은 필요하지 않습니다.
`test/fixtures/corpus_small.csv`는 5행의 인공 테스트 자료이며 실제 학습 자료가 아닙니다.
