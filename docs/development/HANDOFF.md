# Reader handoff — start here

Updated: 2026-11-03 (Asia/Seoul). Branch main.
Latest runtime: bd3ee40ae63f4a3916ac64e48dfea90fa14093f4 (pushed; web/Android CI verified).
Earlier milestones: P0 4887541, P1 1c2f113, P2/hover 826ed80, P3 feecf59,
P3a 97443f1. History is preserved in JOURNAL.md.

## Latest completed module — S1 storage collision safety (2026-11-03)

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

## Next concrete action

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
