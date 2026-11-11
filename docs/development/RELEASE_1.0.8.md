# Recall 1.0.8+9 release verification — 2026-11-11

Source: fdbb427eded7329a61b6db1105f28de7949001f7.
Runtime PR: https://github.com/Peter7004/Recall2/pull/5
Web: https://peter7004.github.io/Recall2/
Release: https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.8
APK: https://github.com/Peter7004/Recall-APK-Private/releases/latest/download/Recall.apk
APK bytes: 78346563.
APK SHA-256: ca1cd106c0badf40b1ed428b0013c36fd09e9b6c9610e6aba1eb4650f747443a
Certificate SHA-256: bc3842b9f7fd111587d9d337e434bd89406cf8b92a9bae114ad288692ae39977
Package: io.github.peter7004.recall; versionName 1.0.8; versionCode 9.

## PASS

- Full Linux PR checks 42982621625 / job130396336799: 187 Flutter tests,
  analyze and 8 Node startup tests. No missed-tap warnings after the test fix.
- Pages 42982937540: full tests/analyze/release build/deployment.
- Permanent signed APK 42982945172: 187 tests, analyze, 8 startup tests,
  APK build, apksigner verification, package/ABI checks and artifact upload.
- Separate test APK 42982937536. This artifact was NOT published as production.
- Downloaded signed artifact source SHA, package/version, checksum and existing
  v1.0.7 certificate match. Existing key and secrets were reused, not replaced.
- APK and public web vocabulary/corpus bytes match committed release source.
  Vocabulary: 834 unique terms. Production corpus: header only, no fabricated stats.
- Public UI smoke: home/dictionary/study/records/settings; bookmark and review
  reload persistence; unchanged storage on browsing; 320/430/640/1280 widths.
- Public mobile Reader menu: PDF import, page3 jump, search and desktop restoration.
- Public corpus smoke: hidden empty catalog; isolated browser fixture verifies
  filters/detail/PDF statistics and source save without rewriting vocabulary.
- Public full Reader learning smoke: exact second occurrence, deduplication,
  cross-document source/back, restart, preferences, dictionary-card source route,
  corrupted IndexedDB isolation, PDF deletion preserving learning/source records,
  missing-document links disabled, and image-only PDF guidance. No JS errors.
- Public latest APK re-downloaded without credentials; SHA-256 matches reviewed
  artifact/checksum. Previous v1.0.7 asset digests unchanged. Prior manual preserved
  unchanged and explicitly described as an earlier edition.
- Root index entries byte-for-byte identical to captured baseline; all 88 unrelated
  staged copies untouched. Work used C:/Users/Public/Recall-ui-release-20261111.

## FAIL, subsequently fixed or separately limited

- First Linux PR run42982129380: 180 PASS / 7 FAIL. test/widget_test.dart tapped
  clipped/offscreen management links and a bulk-selection row, and assumed a lazy
  low-priority row was already built. Centered targets, settled layout and asserted
  hit-testability; retained behavioral assertions. App source did not need changes.
  Commit4fbd5ed fixed all seven; complete rerun passed.
- Windows dart run invoked a pdfium build hook without a C++ compiler. Documented
  direct dart --packages CLI invocation passed fixture validation (exit0) and
  header-only unavailable-data validation (expected exit3).
- Local Windows Gradle environment repair remains unresolved. Parallel environment agent reports minimal
  independent Gradle projects fail while standalone Kotlin works; MSVC discovery
  was still in progress. Linux success does not prove local Windows is repaired.

## NOT TESTED

- Physical Android installation, gestures and native-device behavior.
- Real TF/DF statistics, full corpus research aggregates and large-PDF performance.

## Root synchronization

Primary agent already synced green test/widget_test.dart and pubspec.yaml to the root.
Root Reader and smoke files matched the synchronized release source; do not replace
newer root edits. Merge development records rather than overwriting concurrent work.
README has both version references updated; preserve root collaboration additions.
No AI, OCR, accounts, server dependency, persistence schema/key changes or fake
historical dashboard data were introduced. No quota-reset auto-resumption claim.
