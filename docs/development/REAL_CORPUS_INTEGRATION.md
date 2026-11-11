# 실제 코퍼스 빈도 연동 — 2026-11-11

기존 배포본1.0.9에는 코퍼스 CSV 헤더만 있어 통계가 표시되지 않았다.
다른 채팅의 최신 재집계 자료를 로컬에서 찾아834개 사전 용어에 연결했다.

## 출처와 의미

- 출처 작업: `x20/work/recall-recount-20261111`의 recount/manifest/occurrences/term_rules.
- PDF22개 파일 + 고유 DOI 논문 초록639개. 논문 전체 본문이나 독립 교재22권이 아니다.
- 전공 문맥 자동 판정에 따른 **잠정 채택값**이며 전문가 의미 검수 완료값이 아니다.
- 공통225 / PDF만326 / 초록만37 / 양쪽 채택0인 용어246 =834.
- 채택 TF: PDF62,295 / 초록3,778. 의미 보류: PDF14,733 / 초록2,130.
- 보류 건수는 별도로 표시하고 필터·정렬에서는 제외한다. 채택0이 실제 미출현을 뜻하지 않는다.
- PDF전체 교재와 장별 파일이 중복될 수 있고, 초록 후보의 인적 검토는 미완료다.
- 이전 포스터210/276/45/303은 이전 방식 집계다. 변경 원인을 오탈자 수정만으로 해석하지 않는다.

## 변경 범위

- `assets/corpus/corpus_stats.csv`:834개 실제 채택 TF·DF.
- `assets/corpus/corpus_metadata.json`:자료 수, 기준일, CSV/출처 해시, 보류 TF·DF.
- corpus model/loader/widgets:CSV와 기준 파일 검증, 잠정값·보류·집계 기준 표시.
- `lib/main.dart`:사전 필터에 집계 정보 전달. 기존 PDF의 CorpusInfo를 그대로 재사용.
- `tool/import_corpus_recount.py`:원본 해시 및 출현 기록을 검증한 뒤 통계만 내보내기.
- CLI/단위/브라우저 테스트, README/인계 기록, pubspec버전·asset등록.
- `.gitattributes`:CSV가 Windows체크아웃에서도 해시가 바뀌지 않도록 바이트 보존.

원문 PDF,초록 전문,문맥 인용문,PC 경로 및 비밀정보는 앱에 포함하지 않았다.
기본13열 사전 CSV, 카드ID, 북마크, 복습 일정, `recall.data.v3`,
`recall.reader.learning.v1` 및 기타 Reader저장소는 변경하지 않았다.

## 검증

PASS: 원문 출현86,182건 재합산,661개 원본 문서와3개 원본 CSV해시 대조,
834개 완전 매칭, 중복/미매칭 없음, 논리적인TF·DF범위, 보류 합계, 관측범주.

PASS: Windows전체191개 테스트, Flutter analyze, 웹 빌드, CLI `--recount-check`.
처음 위젯 테스트는 필터 높이 증가로 화면 밖 항목을 클릭해 실패했다.
해당 테스트를 먼저 스크롤하도록 고친 후 전체 테스트가 통과했다.

PASS: 모바일/데스크톱 기존 UI 회귀 테스트(320/430/640/1280폭),
북마크·복습 기록 재실행 유지. 실제 통계 브라우저:Voltage/Frequency채택·보류,
집계 기준, 공통225개, 초록DF정렬,320/390폭, PDF통계·단어저장·출처·재실행 유지PASS.
누락/합성 통계 fallback 및PDF연동도PASS. 웹 시작 타이밍8개PASS.
브라우저 테스트는 Flutter접근성 합쳐진 라벨과 포커스 생성 지연에 맞게 수정했다.
단어 상세 방문으로 기존 recentViews가 갱신되는 것은 정상 동작이며,
그 외 단어·북마크·복습 데이터는 그대로인지 비교했다.

NOT TESTED: Android실기기 업데이트·조작, 모든 용례에 대한 전문가 의미 검수.
해시/산술 검증 성공이 전문적 의미 판정의 정확성을 보증하지 않는다.

## 재현

`assets/corpus/README.md`의 내보내기 및 검사 명령을 사용한다.
실제 데이터 테스트는 `tool/corpus_real_smoke.cjs`,
누락 및 합성 fixture테스트는 `tool/corpus_smoke.cjs`로 분리했다.
두 브라우저 테스트는 격리된 프로필만 사용한다.
데이터 수정 시 CSV와 대응 metadata를 함께 갱신한다. 둘이 다르면 통계만 숨기고 앱은 실행한다.
