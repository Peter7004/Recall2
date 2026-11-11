# Recall 1.0.9+10 배포 검증 — 2026-11-11

- 코드 커밋: `2d2903ac8c956d2677da86ea9af550ed90d83f86`
- 배포 소스: `8868ae4a03009bc1c53a771683794d0197086bbb`
- PR: https://github.com/Peter7004/Recall2/pull/7
- 웹앱: https://peter7004.github.io/Recall2/
- 정식 APK: https://github.com/Peter7004/Recall-APK-Private/releases/latest/download/Recall.apk

## 변경 내용

하단 메뉴를 홈·사전·Reader·학습·기록으로 구성하고 Reader와 학습 화면의
탭 전환 중 상태를 유지한다. 반복적인 안내 문구를 줄였다. 기존 사전·학습·PDF
기능과 모바일 Reader 원형 메뉴는 유지했다. Windows 테스트와 APK 빌드에
사용하는 물리적 영문 경로의 개발 도구 및 실행 스크립트를 준비했다.

## PASS

- 로컬 Windows: Flutter188 테스트, 실제 PDFium 텍스트 추출·렌더링1,
  analyze, debug APK 빌드. 이전 작업의 검증이며 실행 소스는 버전 번호 외 동일하다.
- GitHub PR 검사 `42989014089` / job `130417019121`:
  Flutter188, analyze, 웹 시작8 테스트.
- Pages `42989311938`: 테스트·분석·release 웹 빌드·배포 성공.
  공개 `version.json`에서 1.0.9 / build10 확인.
- 공개 웹 UI: 홈·사전·학습·기록·설정, 북마크·복습 재실행 유지,
  320/430/640/1280 너비, 모바일 메뉴·페이지 이동·검색·탭 복귀.
- 공개 PDF: 동일 페이지의 두 번째 등장 위치 저장, 중복 방지,
  두 문서 간 원문 복귀, 재시작 복원, 사전에서 출처 열기, 손상 데이터 격리,
  PDF 삭제 시 학습 기록 보존, 스캔 PDF 텍스트 없음 안내. JS 오류 없음.
- 공개 코퍼스 UI: 실제 통계 미제공 상태에서 숨김. 별도 테스트 브라우저에만
  fixture를 주입하여 필터·상세·PDF 통계·출처 저장 검증. 운영 데이터 변경 없음.
- 실제 배포 전후 같은 격리 브라우저 프로필: 1.0.8에서 북마크와 복습을 기록하고
  PDF를 가져와 3페이지를 저장한 뒤, 1.0.9를 로드했다. 모든 `flutter.recall.*`
  localStorage 값을 원문 그대로 비교하여 일치했고, 관리 PDF와 3페이지를 복원했다.
  캐시를 우회하는 새로고침만 사용했으며 저장 데이터와 IndexedDB는 지우지 않았다.

## 정식 APK

영구 서명 workflow `42989316358`: PASS. 내려받은 artifact를 로컬
`apksigner verify --print-certs` 및 `aapt dump badging`으로 다시 검증했다.

- 패키지: `io.github.peter7004.recall` (이전 정식 APK와 동일)
- versionName `1.0.9`, versionCode `10` (이전9보다 높음)
- 인증서 SHA256: `bc3842b9f7fd111587d9d337e434bd89406cf8b92a9bae114ad288692ae39977`
- APK SHA256: `473d50776f868edef9d494aa6d641ddd918857b19824b6db07322f4931b3a7e8`
- 크기: 78,346,643 bytes
- 이전 1.0.8 인증서 일치, artifact 소스 SHA 및 checksum 일치.
- 내장 834개 고유 용어와 헤더만 있는 코퍼스 asset이 커밋 소스와 일치.
- 공개 latest APK를 인증 정보 없이 다시 내려받아 동일 SHA256을 확인했다.
  v1.0.9 정식 릴리스가 latest이며 v1.0.8의 모든 asset digest는 그대로다.
  이전 매뉴얼도 내용 변경 없이 보존하고 이전 판임을 릴리스 설명에 명시했다.

## 데이터 호환성

기존 `recall.data.v3`, Reader 저장 키·모델·저장소 및 Android 설정은 수정하지
않았다. 기본 CSV와 코퍼스 asset, 의존성 lockfile도 이전 배포와 동일하다.
정식 APK의 패키지와 서명 유지 및 versionCode9→10을 검증하여 기존 정식 앱 위의
업데이트 조건을 확인한다. 테스트 패키지 `com.example.recall`은 별도 앱이다.
앱 삭제나 데이터 초기화는 업데이트 절차에 포함하지 않는다.

## FAIL 및 조치

업데이트 검사 첫 시도에서 기존 HTTP 캐시가 1.0.8 UI를 계속 보여 주어 새 Reader
탭을 찾지 못했다. 저장 데이터는 그대로 두고 네트워크 캐시·service worker를
우회한 새로고침 후 새 UI와 데이터 보존이 통과했다. 기존 캐시를 지워야만
데이터가 이전되는 구조로 변경한 것은 아니다.

## NOT TESTED

- Android 실기기 덮어쓰기 설치 및 터치 동작: `adb devices` 연결 기기 없음.
- Windows 데스크톱 실행 파일 빌드, 실제 대용량 PDF 성능.
- 미제공된 실제 TF·DF 데이터.

Windows 빌드와 웹 테스트를 Android 실기기 검증으로 표현하지 않는다.
원본 작업 폴더의 무관한 staged88개 파일은 변경하지 않았다.
