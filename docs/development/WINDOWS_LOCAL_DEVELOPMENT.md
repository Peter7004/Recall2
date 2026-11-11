# Windows 로컬 개발 및 5개 하단 메뉴 검증

2026-11-11. 이 PC에서 실행한 결과이며 Android 실기기 결과와 구분한다.

## 실행 방법

Recall 프로젝트 폴더에서 PowerShell로 실행한다.

```powershell
./tool/windows.ps1 -Action Test
./tool/windows.ps1 -Action Analyze
./tool/windows.ps1 -Action NativeSmoke
./tool/windows.ps1 -Action ApkDebug
```

`Test`는 전체 Flutter 테스트, `Analyze`는 정적 분석, `NativeSmoke`는
Windows의 실제 PDFium 라이브러리로 PDF 열기·텍스트 추출·렌더링을 검사한다.
`ApkDebug`의 결과는 원본 프로젝트의 `build/windows/Recall-debug.apk`이다.

이 실행기는 현재 PC에 준비된 도구를 사용한다. 다른 PC에 도구를 자동 설치하는
스크립트는 아니다. 일반 `flutter` 명령이나 IDE가 기존 SDK를 계속 참조할 수 있으므로,
현재 PC의 재현 가능한 검사와 APK 빌드는 위 명령을 사용한다.
Windows 데스크톱 실행 파일 빌드는 이번 검증 범위가 아니다.

## 원인과 수정

1. PDF 네이티브 테스트: C++ 컴파일러 검색이 실패했다. 기존 portable MSVC와
   Windows SDK를 검사하고, 해당 프로세스에만 컴파일러 검색 경로를 연결했다.
   Visual Studio 설치로 위장하거나 시스템에 등록하지 않는다.
2. Gradle 설정 및 Flutter 플러그인 컴파일: 영문 경로의 연결 폴더가 실제로는
   한글 사용자 폴더를 가리켰다. 기존과 같은 Flutter·Gradle을 실제 영문 폴더에
   복사한 뒤 Gradle `help`와 플러그인 컴파일이 통과했다.
3. APK의 JNI 빌드: Android SDK의 CMake/ninja 실행 경로도 연결 폴더의 한글
   대상 경로로 해석되었다. Android SDK·JDK·pub cache도 실제 영문 경로로 옮긴 뒤
   `flutter build apk --debug --no-pub`가 성공했다.

사용하는 경로:

| 도구 | 경로 |
| --- | --- |
| Flutter 3.47.6 / Dart 3.13.5 | `C:/Users/Public/Recall-windows-sdk` |
| Android SDK | `C:/Users/Public/Recall-windows-android-sdk` |
| JDK 17 | `C:/Users/Public/Recall-windows-jdk` |
| Gradle 9.3.1 및 캐시 | `C:/Users/Public/Recall-gradle-toolchain` |
| pub cache | `C:/Users/Public/Recall-windows-pub-cache` |
| MSVC 14.44.35207 / Windows SDK 10.0.26100.0 | `C:/Users/Public/BeforeAfterAndroidToolchain/recall-native/msvc` |
| 전용 빌드 복사본 | `C:/Users/Public/Recall-windows-build` |

원본 코드를 전용 빌드 폴더에 복사하므로 원본 OneDrive 경로를 이동할 필요가 없다.
소유자 표시와 파일 목록을 검사하며, 이전에 복사한 소스 중 원본에서 사라진 파일만
전용 폴더에서 제거한다. 사용자 데이터, 서명 키, Git 상태를 복사하거나 변경하지 않는다.
환경 변수는 실행 중인 프로세스에만 적용하고 종료 시 복구한다.
Flutter·패키지 소스, 의존성 버전, 기존 저장 형식은 변경하지 않았다.

## 화면 변경

- 하단 메뉴: 홈 / 사전 / Reader / 학습 / 기록.
- 상단 Reader 버튼을 하단 탭으로 이동. 모바일 Reader의 원형 기능 메뉴는 유지.
- PDF와 학습 화면을 탭 전환 중 유지한다. PDF 페이지와 현재 카드가 초기화되지 않는다.
- 청록색, 밝은 배경, 흰 카드, 간결한 상단 로고 등 제공된 시안의 스타일을 유지한다.
- 반복적인 학습 안내·홍보 문구를 제거했다. 입력 오류, 삭제 확인, 저장 실패 안내는 유지했다.
- 학습 범위, 앞뒷면 전환, 출처, 기존 사전·북마크·복습·개인 단어 기능을 유지했다.

## 검증

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| Windows 전체 Flutter 테스트 | PASS, 188개 | `build/windows-final-tests.log` |
| 실제 Windows PDFium 텍스트 추출 및 렌더링 | PASS, 1개 | `build/windows-final-native.log` |
| Flutter analyze | PASS, 문제 없음 | `build/windows-final-analyze.log` |
| Windows 로컬 debug APK | PASS | `build/windows-apk-physical.log` |
| APK 패키지·버전·서명 | PASS | aapt / apksigner 직접 검사 |
| 브라우저 5개 메뉴 및 UI | PASS | `tool/ui_v2_smoke.cjs`, 320/430/640/1280 너비 |
| 모바일 크기 Reader 메뉴 및 탭 전환 | PASS | `tool/reader_mobile_menu_smoke.cjs` |
| PDF 단어 저장·출처·재실행·삭제 정책 | PASS | `tool/reader_learning_smoke.cjs` |
| 코퍼스 연결 및 기존 데이터 유지 | PASS | `tool/corpus_smoke.cjs`; 실제 추천 데이터는 여전히 미제공 |
| Android 실기기·Galaxy S25 Ultra | NOT TESTED | 연결된 기기로 직접 실행하지 않음 |
| Windows 데스크톱 앱 빌드 | NOT TESTED | APK와 Windows 호스트 테스트가 이번 범위 |

초기 Gradle/네이티브 빌드 실패는 위 원인 분석 후 재실행에서 해결되었다.
현재 남은 SDK XML 및 file_picker의 향후 Kotlin 마이그레이션 경고는 빌드를
실패시키지 않는다. 이 수정에서 패키지 교체나 Kotlin 버전 변경은 하지 않았다.

테스트 APK 정보:

- 패키지: `com.example.recall` (별도 테스트 앱)
- 버전: `1.0.8+9`, min SDK 24, target SDK 36 (기존 설정 유지)
- 서명: Android Debug. 운영 배포의 영구 서명 APK가 아니다.
- 크기: 194,339,150 bytes. 디버그 빌드이므로 배포 APK보다 크다.
- SHA256: `79326286502a90369cdfbc7a086f32f412fcd4b1cd3fa77c8b4cbd6ede2cee33`

이번 변경은 로컬 작업이며 새 커밋·push·배포를 수행하지 않았다.
공개 1.0.8 배포와 별도로 관리한다. 기존에 staged 상태였던 무관한 88개 파일은 그대로 두었다.

## 변경 파일

- `lib/main.dart`, `lib/ui/recall_dashboard.dart`
- `test/widget_test.dart`
- `tool/windows.ps1`, `tool/recall-windows.ps1`, `tool/native_pdf_smoke_test.dart`
- `tool/ui_v2_smoke.cjs`, `tool/reader_mobile_menu_smoke.cjs`,
  `tool/corpus_smoke.cjs`, `tool/reader_learning_smoke.cjs`
- 이 문서와 HANDOFF / JOURNAL / READER_ROADMAP

## 다음 확인

Galaxy S25 Ultra에서 설치·파일 선택·터치 선택·백그라운드 복귀를 직접 확인한다.
공개 배포를 진행할 때는 별도 버전 번호와 기존 운영 서명으로 release APK를 만든다.
