# 코퍼스 통계 추가 방법

현재 `corpus_stats.csv`에는 헤더만 있습니다. 실제 TF·DF가 아직 제공되지 않았으며,
앱은 코퍼스 추천/통계 UI를 숨깁니다. 테스트 데이터를 여기에 복사하지 마세요.

UTF-8 CSV를 다음 5개 열 순서로 준비합니다.

```csv
term_en,textbook_tf,textbook_df,abstract_tf,abstract_df
```

- 모든 수치는 0 이상의 정수이며 누락값은 허용하지 않습니다. 모르는 값을 0으로 채우지 마세요.
- 각 자료에서 DF ≤ TF여야 하며, TF가 0이면 DF도 0, TF가 양수이면 DF도 양수여야 합니다.
- 미관측은 실제 제공된 네 통계가 모두 0인 행입니다. 통계 행이 없는 단어는 미제공입니다.
- 매칭은 앞뒤 공백 제거, 연속 공백 통일, 소문자 비교만 수행합니다. 하이픈/복수형/약어는 별개입니다.
- 정규화한 중복 용어, 숫자 오류, 잘못된 CSV가 하나라도 있으면 파일 전체를 비활성화합니다.
- 기존 13열 단어 CSV나 사용자 저장 데이터는 수정하지 않습니다.

프로젝트에서 `flutter pub get`을 실행한 뒤 검사합니다. Windows에서는 설치한 Dart 실행 파일 경로를 사용할 수 있습니다.

```powershell
dart --packages=.dart_tool/package_config.json tool/validate_corpus.dart path/to/actual_stats.csv
dart --packages=.dart_tool/package_config.json tool/validate_corpus.dart path/to/actual_stats.csv assets/vocabulary/recall_core_v1.csv --research-check
```

첫 명령은 오류, 매칭 수, 미매칭 통계, 통계 없는 사전 용어, 사전 중복, 관측 집계를 JSON으로 출력합니다.
두 번째 명령은 834개 완전 매칭과 공통 210 / 교재만 276 / 초록만 45 / 미관측 303도 검사합니다.
집계는 검증 기준일 뿐 개별 TF·DF를 만들어 내는 데 사용하지 않습니다.
종료 코드: 0=유효한 통계 파일, 2=형식/연구 검증 실패, 3=헤더만 있어 데이터 미제공.
부분 통계 파일은 일반 검사를 통과할 수 있으므로 배포 전 반드시 연구 검증도 실행하세요.

검증된 실제 파일만 `assets/corpus/corpus_stats.csv`로 교체하고 앱을 다시 빌드합니다.
이미 asset 경로가 등록돼 있어 추가 DB/서버 설정은 필요하지 않습니다.
`test/fixtures/corpus_small.csv`는 5행의 인공 테스트 자료이며 실제 학습 자료가 아닙니다.
