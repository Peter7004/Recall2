# Recall1.0.10+11 — 실제 코퍼스 빈도

런타임 커밋:31f704f6f9b40a5f95805e6999877ed6489dbb85.
PR9 병합:d4619715cb7e29a05c28cb40c8bbeb834a3e311e.

기존 헤더만 있던 코퍼스 파일에 실제834개 용어의22 PDF/639초록 재집계값을 연결했다.
잠정 채택 빈도와 의미 보류를 구분한다. 자세한 출처·집계 한계·변경 파일은
REAL_CORPUS_INTEGRATION.md와 assets/corpus/README.md를 참조한다.

## PASS

- 원문 출현86,182건 재합산 및661문서/3원본CSV해시,834완전 매칭.
- 로컬Windows191 Flutter테스트, analyze, 웹빌드, CLI재집계검사, startup8.
- PR CI43014655807, Pages43015022187.
- 공개 웹 vocabulary/corpus/metadata asset 바이트가 병합 소스와 완전히 일치.
- 실제 공개 웹의 채택/보류 표시, 공통225개필터, 초록DF정렬,320/390폭.
- 실제 공개 PDF에서 통계조회/단어저장/원문좌표/재실행 유지.
- 누락/합성 통계 fallback 및 기존 UI/북마크/복습 회귀 검사.
- 격리된 동일 브라우저에서 실제1.0.9→1.0.10업데이트: 모든Recall localStorage
  값의 완전 일치, 북마크/복습, 관리PDF, 마지막3페이지 복원.
  브라우저 캐시만 우회했으며 사용자 저장소는 삭제하지 않았다.

## APK 배포 확인

영구서명 workflow43015043216 PASS. 로컬 apksigner/aapt 재검증PASS.
패키지 `io.github.peter7004.recall`, versionCode11/name1.0.10.
기존1.0.9와 동일한 영구서명 SHA256:
`bc3842b9f7fd111587d9d337e434bd89406cf8b92a9bae114ad288692ae39977`.
APK78,389,033바이트, SHA256:
`7b8f7541701b398e173a70135b7acd1efc00e80348308814ad41389e4605636d`.
내부 vocabulary/corpus/metadata의 바이트와 병합 소스,834행/22PDF/639초록/CSV해시 일치PASS.
v1.0.10게시 후 인증 없는 공개 APK전체다운로드 SHA256검증PASS.
이전v1.0.9모든asset digest변경 없음PASS. 기존매뉴얼 파일은 이전판 그대로 유지했다.

[웹앱](https://peter7004.github.io/Recall2/) ·
[정식 APK](https://github.com/Peter7004/Recall-APK-Private/releases/latest/download/Recall.apk) ·
[릴리스](https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.10)

## FAIL / 수정

최초 위젯 테스트는 화면 밖 단어항목 클릭으로 실패했다. 스크롤 후 클릭하도록
수정한 뒤191개 전체PASS. 브라우저 스크립트도Flutter접근성 라벨 병합,
포커스 생성 지연, 드롭다운 애니메이션, 정상recentViews갱신에 맞게 수정했다.
최종 런타임 실패는 확인되지 않았다.

## NOT TESTED

Android실기기 설치/조작, 전체 용례에 대한 전문가 의미 검수.
빌드 및 산술 검증 성공을 기기 동작/전문 의미의 검증으로 간주하지 않는다.

기본13열 CSV, 사용자 카드ID/북마크/복습과 모든 기존 저장 키/형식을 보존했다.
원문 PDF·초록 전문, PC원본 경로와 비밀정보는 배포하지 않았다.
root의 관련 없는 staged88개는 그대로다.

검증 산출물: `C:/Users/Public/Recall-release-110/build/release-1.0.10/` 및
root `build/corpus-real-*.log`, `build/corpus-public-browser.log`.
