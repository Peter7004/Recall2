# Reader handoff — start here

## Active UI follow-up — 2026-11-08
User authorized UI improvements and commit. Scope: personal_vocabulary_dialog.dart,
focused widget/browser tests and development records. Add field spacing/borders, required vs
optional sections, readable source block, contextual duplicate confirmation and
scrollable keyboard-safe layout. Storage unchanged. 8 focused tests PASS, including
390x844 viewport with 300px simulated keyboard inset. Full analyze, release web build,
browser drag/save/reload PASS. Desktop/mobile screenshots inspected. Browser smoke
uses named fields and real key input because Flutter editable semantics rebuild on
focus; fixed test harness failures, confirmed saved explanation_ko. Ready for task-only
commit; no push/deploy. Android device/actual mobile keyboard NOT TESTED.

## Active task — manual PDF vocabulary (2026-11-08)
User authorized implementation and commit. Inspecting existing pdfrx selection,
RecallCard meanings/examples/sources and SharedPreferences v3. Reuse existing
dictionary edit/delete and flashcards. Add a manual selection dialog, conservative
offset-based context extraction and separate personal identities; no AI or DB migration.
Expected files: vocabulary.dart, recall_store.dart, main.dart, reader/pdf_reader_page.dart,
new personal vocabulary dialog/context helper, focused tests and development records.
Implemented: manual dialog, conservative selected-offset context, distinct personal
entries, existing dictionary editing/deletion and flashcard back content reused.
PASS: 49 isolated tests (same app source and locked compatible dependencies),
full analyze, release web build and actual browser PDF-selection/save/reload smoke.
FAIL (environment): full native test invocation stops at pdfium C++ build hook;
Windows C++ compiler is not configured. Android device/build NOT TESTED; adb has no devices.
Final same-source release web build and existing full Reader learning/source browser
regression PASS. Verified source hashes match the tested full-project copy.
Ready for task-only commit on codex/pdf-personal-vocabulary; next validation requires
Android hardware and a configured native C++ toolchain. No push/merge/deploy authorized.
Unrelated staged copies and collaboration changes remain untouched.
See PERSONAL_VOCABULARY_VERIFICATION.md for scope, commands and limitations.

Updated: 2026-11-04 (Asia/Seoul). Branch main.
Latest runtime: 3afdd04efdd3522ed8c848bed0787a5941a85a12 (v1.0.5+6).
Earlier milestones: P0 4887541, P1 1c2f113, P2/hover 826ed80, P3 feecf59,
P3a 97443f1. History is preserved in JOURNAL.md.

## Latest completed module — S3 tap and click lookup

Use the viewer's confirmed single tap and existing matched PDF rectangles to
select the exact dictionary occurrence. Reuse the selection popup and source
saving. Keep scroll, zoom, native selection and PDF link handling.
Implemented in pdf_reader_page.dart and pdf_term_hover.dart. PASS: analyze, release web build, browser click and emulated touch, exact source save, zoom, touch drag, and existing selection and source consistency smoke. The smoke selectors were corrected after early harness failures. Android device verification NOT TESTED. Reported deployed app still required drag because S3 was local. Release v1.0.5+6 includes S3. Pages 41802098782 and public mouse/touch smoke PASS. Signed build 41802098954 PASS. v1.0.5 published with package io.github.peter7004.recall, version code 6, and the v1.0.4 certificate. Next product module: Reader backup and restore.


## Latest completed module — S2 definition and source consistency

Authorized continuation 2026-11-03. Scope: learning list shows all current primary
meaning/definition/explanation fields together when dictionary entry exists; otherwise
show explicitly labeled saved snapshot. Preserve stored snapshots and dictionary keys.
Share managed-file availability checks between Reader list and card sources; recheck
before source navigation. Missing bytes/damaged metadata disable links; no full-PDF
validation/performance claim. No backup feature in this module.
Expected files: reader_learning_view.dart, pdf_reader_page.dart,
reader_card_sources_page.dart, library/document_repository.dart, reader_learning_store.dart; focused tests/docs.
Implementation complete; 29 isolated tests PASS, analyze and release web build PASS.
Existing full PDF learning/source regression PASS. Focused browser consistency smoke PASS: persisted dictionary edits/deletion and
missing-byte navigation race; no JS errors, raw Reader snapshot unchanged.
Initial test harness failures fixed: ASCII TEMP/TMP needed for Windows tester; grouped
source scenarios avoid cross-test fake-clock/common-queue interference; use IconButton
predicate rather than RawTooltip cast. Windows full native hook still lacks C++.
Final source: retry repository creation after failure; one-pass source document IDs.
29 tests re-PASS. Final analyze/release web build PASS (session 61410).
Final same-source consistency browser smoke PASS (including snapshot fallback).
Source committed/pushed b3da5c2a32173b899d526504fb76f1431fbe6b7d.
S2 CI PASS: web 41658314912 and Android test APK 41658314699. Public consistency smoke PASS.
Production APK requested 2026-11-04. Source e752e34 bumped version to 1.0.4+5. Signed build 41791432029 PASS and v1.0.4 published. APK package io.github.peter7004.recall, versionCode 5 and previous certificate match verified. Public latest download and release SHA-256 verified. Android on-device install NOT TESTED.
After S2, first unfinished product module is Reader export/restore (not started).
See CONSISTENCY_VERIFICATION.md.
For isolated tests set TEMP/TMP=C:/Users/Public/Recall-reader-test-temp. Native
Android device testing needs connected hardware. Preserve unrelated staged copies.

## Previous completed module — S1 storage collision safety (2026-11-03)

User authorized prioritization of proposed/screenshot learning features and starting
highest priority. P0 is preventing Reader record loss/resurrection across independently
loaded stores and browser tabs. Keep existing storage keys/data; no server/dependency.
Plan: per-process serialized mutation, reload latest snapshot inside exclusive guard,
Web Locks for cooperative cross-tab writers, explicit refusal when safe locking is
unavailable, and refresh other instances/tabs. Preserve deletion semantics: no blind
merging stale snapshots. Validate two-store concurrent saves, deletion resurrection,
write failure, corrupt snapshot, real two-tab browser scenarios and existing workflows.
Priority review complete in LEARNING_FEATURE_PRIORITIES.md.
Guard/coordinator + read-latest mutation and cross-instance refresh implemented.
Existing key/schema retained. Web unsupported-lock writes explicitly refused.
Reader auto-bookmark link also refuses stale dictionary snapshots, avoiding v3
clobbering during simultaneous Reader saves. This does NOT serialize every legacy
manual dictionary edit across tabs; that remains outside this scoped repair.
45 isolated regression tests PASS; analyze/release web build PASS. Real two-tab test PASS for held-lock serialized
writes, suppression-resistant deletion handling and unsupported lock refusal.
An already open learning list also receives storage-event removal/addition live.
Final two-tab + existing learning/source-return flow PASS on localhost:5206.
See STORAGE_SAFETY_VERIFICATION.md for guarantees and limits.
Source committed/pushed as bd3ee40ae63f4a3916ac64e48dfea90fa14093f4.
Exact-SHA CI: web 41653024597 SUCCESS (full tests/analyze/build/deploy).
Android 41653024525 SUCCESS: full tests/analyze/build and test APK artifact.
Temporary test signer only; permanent production download APK unchanged.
Public two-tab safety smoke PASS: held lock, live removal/addition, stale-tab
delete preservation, retry bookmark and unsupported-lock refusal. No JS errors.
adb devices reports no device; native device behavior NOT TESTED.
Next concrete action: inspect ReaderLearningView definition resolution and
ReaderCardSourcesPage document availability checks, then implement P1 definition/
snapshot and source-availability consistency as a separate module. Not started.
No unfinished S1 source changes remain. Reload ALL old app tabs before using the new protocol.
Old code ignoring the lock cannot be coordinated.
Historical P4/P5 verification below is preserved separately from S1 results.

## Current state — COMPLETE through P4/P5

- Damaged native/web PDF metadata is isolated and reported. Healthy documents
  remain usable; damaged records are never automatically deleted or overwritten.
  Reimport of a damaged record is explicitly refused.
- Preview star refresh retains scroll and mounted thumbnails.
- Highlight state distinguishes loading, successful zero matches, unavailable
  text/geometry and errors with explicit retry. Copy restrictions are respected.
- Known-term saving separates a card snapshot from exact occurrences: document
  hash/title, page, actual text/context, char offsets and normalized fragment
  rectangles. Duplicate saves deduplicate; different same-text locations remain.
- Saved fragments remain green after reopening. Reader lists, dictionary detail
  and flashcard pages link to source geometry. One-step source return history is
  current-session-only; saved terms/occurrences and document progress persist.
- PDF deletion retains learning/context and disables missing links. Original card
  deletion still leaves a readable saved snapshot. English definitions are shown;
  highlight/default view settings persist. Existing-word bookmarking is idempotent
  with failure rollback. Reader/dictionary writes are separate; partial failure is reported.

## Final verification

Exact runtime 55937793390517cfef02f410a8b65260e45e6633:
- PASS: web 41595274901 full Linux tests/analyze/build/deployment.
- PASS: Android test APK 41595274985 full Linux tests/analyze/build/artifact.
  Temporary test signer; NOT the permanently signed production download APK.
- PASS: public peter7004.github.io/Recall2 learning/library smokes: selection/save,
  duplicate prevention, SECOND same-page occurrence, cross-document source/back,
  restart/settings, dictionary card source route, damaged IDB isolation/reimport
  refusal, image-only guidance, deletion-retained records/disabled links and
  injected write rollback. No JS runtime errors.
- PASS: local 38 isolated tests, analyze/web build. PDF adapter tests passed in
  both full Linux jobs. Existing navigation/search and preview/bookmark smokes PASS.
- PASS: public/local hover pixels 0/1137/0/1137/0; selection with always-on works.
  Dictionary checks 16/startup 8 PASS. CSV unchanged:
  2a3a7a6ea639ecc7a9ac600e7c6666f5bf4a159e90c90aa72457e4802209ec0e.
- NOT TESTED: Android device/backup (ADB had no devices), large/rotated/encrypted/
  copy-restricted native PDFs and Windows native build. Prior narrow-web semantics
  pointer issue remains unresolved/unverified.
- NOT TESTED: browser-only Flutter corruption unit (loading interrupted). Actual
  application IndexedDB injection passed separately.
- Existing Windows full Flutter tests fail BEFORE cases: missing C++ compiler for
  pdfium_dart. Linux tests/builds do not prove device behavior.
See P4_P5_VERIFICATION.md for scope and limitations.

## Historical P4/P5 follow-up

1. Inspect git status, actual code and latest complete checkpoint hashes. Do not
   redo P4/P5. No deployment or build remains pending.
2. P6: Galaxy S25 Ultra verification; obtain representative large/scanned/encrypted/
   restricted PDFs, profile import/render/search/highlights/memory. No real
   500-page/100MB result exists. Virtual widget tests are not PDF performance tests.
   Keep Android 10+ target; do not change minSdk without compatibility checks.
3. Subsequent product work: manual unknown-term creation, Reader export/restore,
   native managed-file path opening. These are NOT implemented. Existing vocabulary
   backup does NOT include Reader records. No AI/OCR/accounts/cloud/server/FSRS.

## Data and environment

- Preserve recall.data.v3 dictionary/bookmarks/flashcards. Only explicit user save
  activates the corresponding word bookmark. No dictionary migration.
- Reader keys: recall.reader.progress.v1.<hash>, recall.reader.pageBookmarks.v1.<hash>,
  recall.reader.learning.v1, recall.reader.settings.v1.
- Managed PDFs: Android noBackupFilesDir/recall_reader; web IndexedDB
  recall.reader.library.v1. Original PDFs are never modified.
- SDK C:/Users/Public/Recall-flutter-sdk (3.47.6); cache
  C:/Users/Public/Recall-reader-pub-cache; Android SDK
  C:/Users/Public/BeforeAfterAndroidToolchain/sdk. No Windows platform scaffold.
- Current full audit C:/Users/Public/Recall-reader-safety-20261103; isolated no-pdfrx
  harness C:/Users/Public/Recall-p3-unit-20261103 is not a whole-app build.
- Local localhost:5206/Recall2 server was stopped. Recreate from audit/serve;
  Recall2 junction points to audit/build/web. Exclude Korean copy files when syncing.
- Scripts: reader_learning_smoke.cjs, reader_library_smoke.cjs,
  reader_navigation_smoke.cjs, reader_document_navigator_smoke.cjs,
  check_reader_hover.py. External Playwright via RECALL_PLAYWRIGHT_MODULE;
  RECALL_READER_TEST_URL selects local/public URL. Run picker smokes sequentially;
  appbar import is more reliable for semantics automation.
- Fixtures: original two 5-page manuals under output/pdf (never modify). Synthetic
  5-page source-a/source-b, 1-page image-only via make_reader_learning_fixture.py;
  outline/plain via make_reader_outline_fixture.py. Generated PDFs stay ignored.

## Safety and recovery

Unrelated staged Korean copies and untracked automation/output/tmp are user work.
Never commit/reset/clean them. Commit only explicit owned paths.
Update HANDOFF/JOURNAL and run tool/checkpoint-reader.ps1 -Note 'implemented / next'
before long verification and after meaningful fixes.
Snapshots: ignored build/reader-checkpoints/<timestamp>/source and manifest.json.
Choose the latest COMPLETE manifest and verify every hash; ignore partial/invalid
snapshots. Compare base commit and diffs; never overwrite newer files blindly.
No keys/PDF/user content in handoffs. Checkpoints do not stage/restore automatically.
Quota reset does not auto-resume development.

Resume: **“개발 인계 기록을 읽고 마지막 미완료 작업부터 계속해 줘.”**
