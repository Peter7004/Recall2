> Release update 2026-11-11: shipped as 1.0.8+9 (PR5/fdbb427). Full Linux187 tests, public browser regressions and permanently signed APK PASS. Actual corpus data and Android device behavior NOT TESTED. See [release verification](RELEASE_1.0.8.md). The local-stage notes below are historical.

# UI v2 적용 및 검증 — 2026-11-11

첨부 HTML/Flutter 코드는 24개 예시 단어를 사용하는 독립 시안입니다. 실제 앱의 main.dart를 덮어쓰지 않고 색상·레이아웃·카드 디자인을 기존 데이터 및 동작에 연결했습니다.

## 적용한 내용

- 청록색 / 남색 / 연한 배경, R 헤더, 둥근 흰색 카드.
- 홈 / 사전 / 학습 / 기록 네 가지 기본 탭.
- 홈: 실제 학습 목표와 횟수, 전체 단어·북마크 수, 검색, 실제 과목, 오늘의 추천 단어. PDF 리더·모음·북마크 관리 진입점 유지.
- 사전: 기존 유형·과목·학습 우선순위·코퍼스 필터와 대량 선택 유지. 작은 화면에서는 필터와 지연 생성되는 목록을 함께 스크롤.
- 학습: 기존 범위 선택과 복습 로직 유지. 흰색 플래시카드 아래에 정답 확인과 목표 진행률 배치. 원문/메모는 답을 본 뒤 표시하는 기존 동작 유지.
- 기록: 실제 오늘 학습 횟수, 한 번 이상 학습한 단어 수, 북마크와 목표 달성률.
- 설정: 5/10/15/20회 빠른 선택과 기존 1~200회 슬라이더 유지. 백업 저장·확인 후 복원 유지.

## 시안과 의도적으로 다른 부분

현재 사용자 목표값을 보존합니다. 기본값 24를 임의로 20으로 바꾸지 않습니다. 과목 역시 시안의 전기·반도체·자동화로 덮어쓰지 않습니다.

기존 저장 구조는 학습 횟수와 카드별 마지막 학습일을 저장하며 완전한 일별 이력이나 오답 횟수는 저장하지 않습니다. 따라서 7일 그래프와 예시 8/8/4 배분을 만들지 않았습니다. 동일 단어 반복 학습도 포함하므로 오늘 지표의 단위는 '단어 수'가 아니라 '횟수'입니다. 시안의 데이터 초기화 기능은 복사하지 않았습니다.

## 파일

- `lib/main.dart`: 테마, 탐색, 사전, 플래시카드, 설정.
- `lib/ui/recall_dashboard.dart`: 기존 store를 읽는 홈·기록 및 공통 위젯. 저장 로직 없음.
- `test/widget_test.dart`, `test/branding_test.dart`, `test/bundled_vocabulary_test.dart`: 시작 화면·탐색·버튼 변경에 맞춘 기대값.
- `tool/ui_v2_smoke.cjs`: 실제 Flutter 웹의 UI/저장 회귀 검사 및 화면 캡처.
- `tool/corpus_smoke.cjs`: 홈에서 사전으로 이동하도록 기존 테스트 조정.
- 개발 인계·로드맵·일지.

## 검증 결과

| 항목 | 결과 | 근거 / 제한 |
| --- | --- | --- |
| Flutter analyze | PASS | ASCII 작업 사본, 오류 없음. 원본 한글 경로에서는 기존 LSP 통신 오류 발생 |
| Flutter release web build | PASS | 기존 CupertinoIcons 폰트 경고는 남아 있음 |
| 실제 Edge UI 흐름 | PASS | 홈·검색·북마크·기록·설정·복습·재시작 유지 |
| 화면 크기 | PASS | 320×640, 430×900, 640×360, 1280×900 캡처. 홈·사전 확인 |
| 사전 읽기만 수행 시 데이터 불변 | PASS | localStorage 원문 비교 |
| 기존 Reader 학습 회귀 | PASS | 두 PDF의 위치 구분, 출처 복귀, 재시작, 손상 격리, 문서 삭제 후 단어 유지, 스캔 안내 |
| 코퍼스 연동 | PASS | 실제 자산은 헤더만 있으므로 숨김. 격리 브라우저에만 fixture를 주입해 필터·상세·PDF 저장 검증 |
| Flutter test | FAIL / 환경 차단 | pdfium_dart native hook의 Windows C++ 컴파일러 부재. Chrome 대상도 동일하게 시작 단계 실패 |
| Android debug APK | FAIL / 환경 차단 | 기존 Gradle Kotlin settings.gradle.kts의 run/file/require/plugins 해석 실패. 이전 Android 감사 기록에서도 동일한 오류 |
| Android 실제 기기 | NOT TESTED | 새 APK 빌드가 완료되지 않음 |

검증은 `C:/Users/Public/Recall-catalog-preserve-20261109`에서 원본과 동일한 수정 파일로 수행했습니다. 브라우저 테스트는 별도 임시 프로필을 사용했습니다. 원본 UI 캡처는 `build/ui-v2-smoke/`에 있습니다.

## 데이터와 배포

이번 UI 변경에서 RecallStore, vocabulary 모델, PDF 리더 및 pubspec은 수정하지 않았습니다. UI 시작 전 체크포인트와 파일 해시가 같습니다. 앞선 코퍼스 변경과 사용자 데이터 키는 그대로 유지했습니다.

원격 push, main 병합, 공개 웹 배포, APK 릴리스는 수행하지 않았습니다. 기존 staged 복사본 88개도 그대로 유지했습니다. 로컬 미리보기는 서버 실행 중 `http://127.0.0.1:5220/`에서 확인할 수 있습니다.
