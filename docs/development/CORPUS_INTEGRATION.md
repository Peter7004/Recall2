# 코퍼스 연동 구현 및 검증 — 2026-11-11

## 1. 기존 구조와 선행 배포

기본 CSV는 현재 834개 고유 용어이며 13열 형식이다. BundledVocabulary가 로딩하고,
RecallStore가 SharedPreferences `recall.data.v3`의 사전·북마크·복습 정보를 관리한다.
PDF는 pdfrx 2.11.0을 사용하고 DictionaryTerminologyLookup이 기존 RecallCard를 참조한다.
Reader 학습 출처는 별도 `recall.reader.learning.v1`에 저장한다.

사용자 요청에 따라 코퍼스 구현 전에 기본 사전 배포를 마쳤다.
원격 main의 v1→v2 삭제 코드가 수정한 뜻/북마크/복습 기록을 없애는 회귀를 재현하여 제거했다.
기존 카드가 있으면 그대로 재사용하고, 신규 용어만 추가한다. 기존 사용자에게는
834개 외에 이전 목록에만 있던 단어도 남는다. 이미 삭제된 기록을 자동 복구하지는 않는다.

- PR #4: https://github.com/Peter7004/Recall2/pull/4
- main 병합: c86f8570ba8071e46f7f68e642f17ea736293144
- 영구 서명 CI PASS: https://github.com/Peter7004/Recall-APK-Private/actions/runs/42975726693
- 웹 배포 PASS: https://github.com/Peter7004/Recall2/actions/runs/42976067818
- APK: https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.7
- 공개 웹 version.json의 1.0.7 / 8, APK의 패키지·834개 CSV·이전 인증서·SHA-256 검증 완료.
- APK SHA-256: ee14600965f9eb9909c8886115df0159b8e7e7c285de28f72b9c62cc364f4182

## 2. 코퍼스 변경 파일

| 파일 | 역할 |
| --- | --- |
| lib/corpus/corpus_stats.dart | 불변 모델, CSV 검증, 제한된 정규화, 필터·DF/TF 정렬, 매칭/연구 진단 |
| lib/corpus/corpus_loader.dart | asset 로딩 실패를 비활성 데이터로 처리 |
| lib/corpus/corpus_widgets.dart | 관측 정보와 코퍼스 필터/정렬 UI |
| lib/recall_store.dart | 읽기 전용 catalog 주입; 저장 직렬화는 변경하지 않음 |
| lib/main.dart | 시작 시 로딩, 기존 검색 결과에 관측 필터 적용, 상세 표시 |
| lib/reader/pdf_reader_page.dart | 기존 사전 조회 패널에 같은 관측 정보 표시 |
| assets/corpus/corpus_stats.csv | 실제 데이터 미제공 상태의 헤더만 수록 |
| assets/corpus/README.md | 실제 CSV 추가·검증 방법 |
| pubspec.yaml | 코퍼스 asset 등록만 추가; 신규 패키지 없음 |
| tool/validate_corpus.dart | 외부 파일 검증 CLI |
| test/corpus_test.dart / test/fixtures/corpus_small.csv | 검증·분류·저장 호환성·UI 테스트와 인공 fixture |
| tool/corpus_smoke.cjs | 테스트 브라우저에서만 fixture 응답을 주입하는 사전/PDF 통합 검증 |
| docs/development 기록 | 작업 상태, 로드맵, 결과 |

## 3. 구현 범위

완료: TF/DF 모델/파서, 중복·숫자·논리 오류 진단, 제한된 정규화 매칭,
전체/공통/교재 포함/초록 포함/미관측/교재만/초록만 필터, 한 코퍼스의 DF 우선·TF 보조 정렬,
사전 상세 및 PDF 조회 정보 표시. 통계가 없거나 잘못되면 코퍼스 UI가 숨겨지고 앱은 정상 실행된다.
전체/기존 검색순이 기본이며 관측 필터를 고르면 명시된 한 자료의 DF순으로 전환한다.
기존 learningPriority/priorityReason은 별개로 유지한다. TF 합산 종합 점수는 만들지 않는다.

미완료가 아니라 **자료 대기**인 항목: 실제 TF·DF의 타당성, 834개 완전 매칭 및 연구 집계 일치.
실제 파일이 없으므로 인공 통계나 가짜 검증 결과를 배포 파일에 넣지 않았다.
파일 추가 방법은 assets/corpus/README.md 참조.

## 4. 데이터 호환성

기존 13열 CSV, RecallCard JSON, 사용자/Reader 저장 키, 카드 ID, 마이그레이션 로직은
코퍼스 구현에서 변경하지 않았다. CorpusCatalog는 메모리의 읽기 전용 참조다.
기존 검색·우선순위·북마크 결과를 복사해서 필터/정렬하므로 기존 검색 캐시를 수정하지 않는다.
통계 연결 전후 저장 문자열 동일성과 기존 단어/복습 기록 재로딩을 테스트했다.
0은 명시된 미관측 통계이며 행이 없는 용어에는 미제공 안내를 표시한다.

## 5. 검증 결과

| 상태 | 항목 |
| --- | --- |
| PASS | 전체 flutter analyze: issues 없음 |
| PASS | release web build; 기존 CupertinoIcons 폰트 경고는 남아 있음 |
| PASS | 동일 소스의 격리 테스트 64개: 코퍼스 21 + 저장소 42 + 업그레이드 보존 1 |
| PASS | BOM/UTF-8, 공백·대소문자, 표기 차이, 중복, 누락/음수/소수/잘못된 숫자/따옴표/열 수, TF/DF 모순 |
| PASS | 범주 포함 관계, DF 우선/TF 보조, 0과 미제공, 저장 문자열 보존, 기존 검색/우선순위/PDF lookup |
| PASS | CLI: 배포 헤더만 파일은 exit 3, 834개 사전 인식; 소규모 fixture는 exit 0; 연구 검증은 불완전 자료를 exit 2로 거부 |
| PASS | 실제 Edge: 무자료 UI 숨김, fixture 주입 후 필터/상세/PDF 통계 및 원문 저장; 데이터 재작성 없음 |
| PASS | 기존 reader_learning_smoke 전체: 정확한 위치/다문서 복귀/재시작/문서 삭제 후 기록 보존/손상 문서 격리/이미지 PDF 안내 |
| FAIL (환경) | 전체 프로젝트 native flutter test: Windows C++ compiler 미설치로 pdfium 빌드 훅에서 중단 |
| NOT TESTED | 코퍼스 기능 Android APK/실기기, 실제 834개 TF·DF 통계, 전체 corpus 변경의 Linux CI |

코퍼스 변경은 원격에 올리지 않았으므로, 선행 v1.0.7 배포의 CI 성공을 코퍼스 CI 성공으로
계산하지 않았다. 격리 환경은 PDF 네이티브 의존성을 제외하고 실제 모델/저장소/코퍼스 소스를
복사한 C:/Users/Public/Recall-personal-unit-20261106이다. 전체 앱 검증 작업 공간은
C:/Users/Public/Recall-catalog-preserve-20261109이다.
최종 변경은 원래 프로젝트 C:/Users/유태현/OneDrive/Desktop/Recall의
codex/pdf-personal-vocabulary 브랜치에 미커밋 상태로 반영했다. 해당 로컬 브랜치만
배포된 main(c86f857)까지 fast-forward했으며 원격 브랜치는 변경하지 않았다.
무관한 스테이지 항목과 README 협업 문구는 유지했다. 앱 코드와 fixture의 해시가
검증 작업 공간과 일치하는지 확인했다.
브라우저 검증 초기 실패는 Flutter가 합쳐 노출하는 접근성 라벨과 메뉴 애니메이션에 맞지 않는
테스트 선택자 때문이었고 수정 후 통과했다. 통계 fixture는 앱 파일을 바꾸지 않고 테스트 요청에만 주입했다.

## 6. 실제 파일 확보 후

1. UTF-8 5열 파일을 일반 검증기로 검사해 오류·중복·미매칭을 해결한다.
2. --research-check로 834개 완전 매칭과 210/276/45/303 집계를 검사한다.
3. 검증된 파일로 asset을 교체하고 사전/PDF/Android 테스트를 실행한다.
4. 검토 후 별도 커밋·PR·배포한다. 현재 코퍼스 변경은 로컬 미커밋 상태다.
