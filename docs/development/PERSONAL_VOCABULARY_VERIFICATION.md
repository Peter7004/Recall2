# PDF 개인 단어장 검증 — 2026-11-08

## 구현 범위

- pdfrx 2.11.0의 기존 선택 패널에 `내 단어장에 추가` 버튼 추가.
- 선택 텍스트 공백 정리, 단어 수정, 필수 뜻, 선택 메모/원문 편집.
- `PdfPageTextRange.start/end`(끝 제외)를 사용해 선택한 위치의 문장 추출.
  여러 범위, 미완성 문장, 빈 줄/탭, 약어 경계 등 불명확한 경우 빈칸.
- 기존 RecallCard의 collector=`reader:personal`로 개인 항목 구분.
  뜻은 meaning/meanings, 메모는 explanationKo, 원문은 example/exampleSentence,
  파일명과 페이지는 source/sources에 저장. 기존 저장 키/스키마 유지.
- 같은 단어는 확인 후 별도 ID로 저장. CSV/기본 제공 단어 병합에서 개인 항목 제외.
- 사전의 기존 편집/삭제와 플래시카드 재사용. 원문/메모/출처는 카드 뒷면.
- 저장 오류 시 추가 항목 롤백. 최신 저장 내용과 다른 오래된 화면의 추가 거부.

## 검증

| 상태 | 항목 |
| --- | --- |
| PASS | 전체 `flutter analyze --no-pub` |
| PASS | `flutter build web --release --no-pub` |
| PASS | 개인 단어 7개 + 기존 저장소 42개 = 49개 격리 테스트 |
| PASS | 실제 Edge PDF 드래그 → 등록 창 → 직접 뜻/메모/원문 입력 → 저장 → 같은 페이지 유지 → 새로고침 후 저장값 유지, JS 오류 없음 |
| PASS | 기존 reader_learning_smoke.cjs 전체 회귀: 동일 단어의 정확한 위치, 여러 문서 원문 복귀, 재실행, PDF 삭제 후 학습 기록 보존, 손상 메타데이터 격리, 이미지 PDF 안내 |
| FAIL (환경) | 전체 프로젝트에서 native flutter test 실행: pdfium_dart 빌드 훅에 필요한 Windows C++ 컴파일러 없음 |
| NOT TESTED | Android APK 빌드 및 실제 기기 동작; adb 연결 기기 없음 |
| NOT TESTED | 모바일 키보드/터치, 실제 대형·다단·암호화 PDF, Windows 네이티브 UI |

한글 경로에서 기존 분석 서버 오류가 발생해 ASCII 경로의 HEAD 복사본에
이번 수정 파일을 그대로 복사해 검증했다. 원본 의존성은 변경하지 않았다.
전체 프로젝트: `C:/Users/Public/Recall-personal-20261106`.
격리 테스트: `C:/Users/Public/Recall-personal-unit-20261106`.
격리 환경은 PDF 네이티브 의존성만 제외하고 원본 저장소/모델/등록 창을 테스트한다.
전체 native 테스트 성공으로 간주하지 않는다.
최종 빌드 대상과 원본 앱 수정 파일의 SHA-256 일치를 확인했다.
웹 빌드는 성공했지만 기존 CupertinoIcons 폰트 경고가 남는다.

브라우저 재현: `python tool/make_reader_learning_fixture.py`로 fixture 생성 후,
웹 빌드를 로컬 서버에 제공하고 `tool/personal_vocabulary_smoke.cjs` 실행.
외부 Playwright 경로는 RECALL_PLAYWRIGHT_MODULE, 서버는 RECALL_READER_TEST_URL.
테스트용 라이브러리는 외부 경로에만 설치했으며 앱 패키지에는 추가하지 않았다.

## 기존 데이터와 한계

기존 데이터/복습 기록 보존, 새 DB/AI API/패키지 없음.
문장 추출은 PDF 텍스트의 읽기 순서가 정확하다는 보장이 없으므로 사용자 수정이 필요하다.
OCR, 의미 자동 생성, 복사 제한 우회는 지원하지 않는다.
새 개인 항목의 PDF 출처는 파일명/페이지 표시이며 클릭으로 정확한 좌표에 복귀하는
새 연결은 이번 범위에 추가하지 않았다. 기존 사전 항목의 원문 복귀는 유지한다.
등록한 단어는 사전에서 `내 단어`로 표시되고 전체 용어 복습에 포함된다.
별도 개인 단어 목록 화면은 중복 구현하지 않았다.

수정 파일: lib/vocabulary.dart, lib/recall_store.dart, lib/main.dart,
lib/reader/pdf_reader_page.dart, lib/reader/personal_vocabulary_context.dart,
lib/reader/personal_vocabulary_dialog.dart, test/personal_vocabulary_test.dart,
tool/personal_vocabulary_smoke.cjs 및 개발 기록 4개.
