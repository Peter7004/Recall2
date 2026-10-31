# Reader 보기 모드·위치 저장·검색 (2026-10-31)

## 구현

- 세로 연속 보기와 가로 페이지별 보기. 기본 배율에서 스와이프를 최대 한 페이지로 스냅한다. 확대 상태에서는 페이지 안을 이동하며, 페이지 화살표로 이동할 수 있다.
- 모드를 바꿀 때 현재 페이지와 페이지 내부 상대 위치를 유지한다. 뷰어와 컨트롤러를 재사용해 분리되는 문제를 방지한다.
- PDF 내용의 SHA-256으로 문서를 구분한다. 파일명이 같아도 내용이 다르면 기록이 독립적이며, 동일한 내용의 파일은 이름이 달라도 같은 기록을 사용한다.
- 페이지 번호, 페이지 내 화면 중심의 상대 좌표, 배율, 보기 모드를 SharedPreferences의 별도 키에 저장한다. 기존 사전 저장 키와 CSV는 수정하지 않는다.
- 위치 저장은 350ms 지연 후 수행하며 문서 전환, 화면 종료, 앱 백그라운드 전환에서도 수행한다. 쓰기는 순서대로 처리하며 저장 실패를 안내한다.
- 재시작 후 같은 PDF를 **다시 선택하면** 기록을 복원한다. PDF 관리 복사본과 최근 문서 목록은 이번 변경에 포함하지 않았다. 강제 종료 직전의 미완료 쓰기까지 보장하지 않는다.
- 본문 검색, 검색 진행률, 결과 수와 페이지/주변 문맥 목록, 좌표 기반 결과 이동과 검색 강조 표시를 추가한다. 검색은 대소문자를 무시하는 문자열 검색이며 OCR은 포함하지 않는다.
- 기존 텍스트 선택과 사전 팝업, 사전·북마크·플래시카드 진입 경로를 유지한다. AI 호출은 없다.

## 검증

| 항목 | 결과 | 범위 |
| --- | --- | --- |
| Flutter analyze | PASS | 영문 경로의 원본 소스 복사본, 최종 코드 |
| Flutter 전체 test | FAIL | 테스트 실행 전 pdfium_dart 네이티브 빌드 훅에서 Windows C++ 컴파일러 없음. 개별 케이스 결과로 간주하지 않음 |
| 위치 저장 단위 테스트 | PASS | PDF 의존성을 제외한 별도 Flutter 검사 프로젝트에서 실제 reader_progress.dart와 두 테스트 실행. 문서 분리, 좌표·배율·모드 왕복 저장, 누락·손상 데이터, 사전 키 유지 |
| 용어 검색 회귀 검사 | PASS | 기존 순수 Dart 검사 16개 |
| 웹 시작 화면 검사 | PASS | Node 검사 8개 |
| 웹 release 빌드 | PASS | 처음에는 한글 Pub 캐시 경로에서 셰이더 컴파일러 오류. 영문 캐시 경로로 해결 |
| 웹 PDF 동작 | PASS | 실제 5쪽 매뉴얼 두 개로 모드 전환, 한 페이지 스와이프, 문서별 위치 분리, 새로고침 후 재선택 복원, 검색 결과 페이지 이동. Edge headless와 터치 이벤트 사용 |
| Android 실기기 | NOT TESTED | 연결된 기기에서 수행한 검증이 아님 |
| 대용량·스캔·암호화·복사 제한 PDF | NOT TESTED | 해당 테스트 파일로 검증하지 않음 |

테스트 매뉴얼: `output/pdf/Recall_User_Manual_v1.0.2_ko.pdf`, `output/pdf/Recall_User_Manual_v1.0.3_ko.pdf`.
웹 검증은 Android 네이티브 호환성 또는 Galaxy S25 Ultra 검증을 대체하지 않는다.
APK 배포 파일이나 Android 최소 SDK는 변경하지 않았다.

## 관련 파일

- `lib/reader/pdf_reader_page.dart`: 보기 모드, 선택, 검색 UI와 이동, 수명 주기 저장
- `lib/reader/reader_progress.dart`: 문서 ID와 별도 위치 저장
- `lib/reader/terminology_lookup.dart`: 기존 읽기 전용 용어 검색
- `test/reader_progress_test.dart`: 위치 저장 회귀 검사
- `test/pdf_reader_test.dart`, `tool/reader_lookup_check.dart`: Reader와 용어 검색 검사
- `lib/main.dart`, `pubspec.yaml`, `pubspec.lock`: 기존 앱 진입 경로와 PDF/해시 의존성
- `tool/validate.ps1`: 격리 검증 시 테스트가 참조하는 tool 디렉터리도 복사

다음 검증은 Android 실기기의 파일 선택·제스처·프로세스 재시작 복원이다.
문서 라이브러리와 앱 전용 파일 보관 및 백업 제외 정책은 별도 단계로 구현해야 한다.
