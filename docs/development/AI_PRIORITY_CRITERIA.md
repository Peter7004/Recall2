# AI 판단 학습 우선순위: 회수한 기준과 확인 범위

2026-11-12 사용자가 명칭 변경과 과거 프롬프트 기반 판단 기준 표시를 요청했다.
기준을 새로 설계하거나 기존 등급을 재평가하지 않는다.

## 확인한 원본

- 로컬 `C:/Users/유태현/Downloads/Recall_Master_Guidelines_v3.0.txt`, 5절 및 7절.
- 원본 SHA-256: `ae706cb7d883453c901489674d6fbc4e8f711e8b0976e05dee7decba053063b1`.
- Codex 대화 **리뷰 요청 코드 검토** (`01a1292b-9477-7a50-80a7-851d265fc788`)의 최초 사용자 첨부:
  `C:/Users/유태현/.codex/attachments/8af3e290-3823-4c40-85df-cbf8708a6f9b/붙여넣은 텍스트.txt`, 240~272행의 분류 프롬프트.
  `conceptual/educational centrality`, high/medium/low 정의, 길이/친숙함 배제와 모호한 medium/low의 검토 규칙이 원본과 부합한다.
- ChatGPT 대화 **전기공학 단어 분류표 작성** (`6aca4b26-00f4-83ec-9676-92b18aeb71bd`)에서 v3.0 기반 31개/35개 분류 및 검수 전 초안이라고 보고한 기록을 확인했다.
  이 대화의 첨부 원문은 도구에 포함되지 않았으므로, 해당 대화만으로 기준 전문을 확인했다고 하지 않는다.
- **Recall Reader DB 자동화 리팩터링**의 과거 사용자 코드에도 v3.0 및 educational centrality 지침이 있다.
- 위 관련 대화의 이전 페이지까지 확인했다. 무관한 개인 대화는 판단 기준으로 사용하지 않았다.

## 원본 5절 발췌

```text
5. 학습 우선순위(learning_priority)
어휘 유형과 독립적으로 high / medium / low 중 하나를 부여한다. 단어의 길이, 난이도, 친숙함, 일상 빈도 대신 해당 전공에서의 개념적·교육적 중요성을 평가한다.
- high: 전공 필수 과목의 핵심 개념, 공식·법칙·계산에 직접 쓰이는 물리량, 다른 개념의 토대, 여러 과목에 반복적으로 등장하는 개념, 실습·설계·분석에 필수적인 용어.
- medium: 전공 학습과 기술 문서에 유용하나 핵심 원리를 이해하는 데 필수적이지 않은 장비·부품·응용 표현. 예: cooling fan, mounting bracket, cable gland (전공·수업에 따라 달라짐).
- low: 전공 관련성이 약하거나 독립적인 학습 가치가 낮은 일반 표현·주변 용어. 단순히 익숙하거나 쉬운 핵심 전문 용어라는 이유로 low를 부여하지 않는다.
전기공학에서 원칙적으로 high로 검토할 핵심 용어: voltage, current, resistance, impedance, reactance, capacitance, inductance, conductance, admittance, frequency, phase angle, power factor, active power, reactive power, apparent power, Ohm's law, Kirchhoff's laws, electric field, magnetic field, magnetic flux, electromagnetic induction, electromotive force, transformer, induction motor, synchronous generator, torque, slip, short circuit, grounding, three-phase power.
특히 power factor, reactance, impedance, capacitance를 technical/low로 분류하지 않는다(전기공학 기초 학습 기준 technical/high).
반도체공정에서 원칙적으로 high로 검토할 핵심 용어: wafer, semiconductor, photolithography, photoresist, etching, deposition, doping, ion implantation, oxidation, diffusion, thin film, lithography, semiconductor device.
이 예시는 완전한 목록이 아니며, 프로젝트 대상 전공과 제공된 교육과정에 따라 조정한다. 실제 강의자료가 주어지지 않았다면 교육과정 출현 빈도를 확인한 것처럼 단정하지 않는다.
판단이 애매한 medium/low 경계에서는 medium으로 잠정 평가하고 notes에 '학습 우선순위 검토 필요'를 기록한다. 단, 모든 단어를 일률적으로 medium으로 분류하지 않는다. high 비율도 인위적으로 조정하지 않는다.
```

원본 7절의 `priority_reason`: **교육적 중요도 판단 근거 한 문장.**
원본 1절은 AI 결과를 검수 전 초안으로 규정하며, 9절은 AI 자체 검증을 독립적인 출처 검증으로 간주하지 않는다.

## 화면 적용

- 기존 일반 사전 상세의 제목과 그래프 축/접근성 명칭을 `AI 판단 학습 우선순위`로 변경한다.
- 저장된 등급의 기준과 기존 `priority_reason`을 구분해서 표시한다.
- `판단 기준` 창에 세 등급, 예외/모호성 처리, 출처 및 확인 한계를 표시한다.
- 위 발췌의 핵심 용어 예시를 전체 단어의 확정 목록으로 확장하지 않는다.
- Reader 개인 단어는 `내 학습 우선순위`로 표시한다. AI 기준을 개인 단어에 적용했다고 주장하지 않는다.
- 코퍼스 DF/N 그래프, 순위, 데이터 값 및 저장 구조는 그대로 유지한다. AI/API 호출 없음.

## 확인하지 못한 것

- 기본 834개 각각에 실제 사용된 프롬프트 버전/전체 입력, 모델 버전, 실행 결과 원본, 검수 완료/수정 이력.
  `source_title` 등의 일반 출처 문자열만으로 이를 증명할 수 없다.
- 모든 현재 등급이 v3.0 기준을 실제로 충족하는지 여부. 이번 작업은 재검수가 아니다.
- 원본 지침에 수치 점수, 가중치, high/medium/low의 빈도 임계값은 명시되어 있지 않다. 만들지 않는다.

이 파일과 UI는 **회수된 공통 기준**을 설명한다. 항목별 적용 사실을 인증하지 않는다.
