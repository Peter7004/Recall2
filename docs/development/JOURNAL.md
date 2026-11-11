# Reader development journal

## 2026-11-09 — Safe 834-term catalog upgrade

- Verified remote main 0248264 has 834 nonempty unique terms; version 1.0.6 web deploy
  42560022388 succeeded. Signed build 42560029792 exists but was not released.
- Regression reproduced against upstream: v1-to-v2 deletion replaces an edited
  bundled card, clearing its bookmark and lastReviewed value; missing legacy terms vanish.
- Removed the destructive deletion block. Existing matching cards are reused and
  unmatched old cards remain; fresh installations still load the exact 834 catalog terms.
- PASS: 43 isolated migration/store tests, full analyze and release web build. Android device NOT TESTED.
- Prepare 1.0.7+8 safety release before publishing APK; corpus work stays separate.

## 2026-11-08 — Plain unhighlighted PDF selection verified

- Existing implementation already allows saving any copyable selected text, with no
  dictionary-match requirement. No duplicate feature added.
- PASS browser test with RECALL_TEST_UNHIGHLIGHTED=1: selected ordinary fixture text,
  confirmed empty dictionary lookup, exact prefill, manual save and reload persistence.
- Test harness needed local server restart and focus before reading Flutter inputValue.
- Android touch selection NOT TESTED. Local feature not yet published to web/APK.

## 2026-11-08 — Personal vocabulary dialog UI

- Grouped required meaning and optional notes, outlined fields with spacing,
  readable source block, contextual duplicate confirmation, save progress indicator.
- Scrollable dialog keeps actions reachable with small viewport/keyboard insets.
- PASS: 8 focused tests, full analyze, release web build, browser save/reload with
  explicit stored memo assertion. Desktop/mobile screenshots visually inspected.
- Browser harness corrected: Flutter semantics focus changes made positional/fill
  input unreliable; named controls with key input pass. No production storage change.
- Android hardware/actual mobile keyboard NOT TESTED. No push or deployment.

## 2026-11-03 — P2 closed / P3 started

- Rechecked 826ed80: web run 41404851026 and Android run 41404851004 both SUCCESS.
- Android device/backup behavior still NOT TESTED; build is not a device test.
- P3: separate page bookmarks with deletion rollback, embedded outline, bounded
  visible-only thumbnails. Installed pdfrx APIs inspected before implementation.

## 2026-11-02 — Public web release verified

- Web run 41404851026 completed SUCCESS for 826ed80.
- Full library/hover smoke and real hover pixel assertions PASS at the public
  peter7004.github.io/Recall2 URL, including rollback and vocabulary preservation.
- Android test APK compilation still running; device behavior remains NOT TESTED.

## 2026-11-02 — P2 pushed / full Linux tests PASS

- Implementation pushed as 826ed802d878722b35933ffc36c52c49a2260f86.
- Web run 41404851026 and Android run 41404851004: full test steps PASS in both.
- Web deployment finalization and Android compilation still running at this point.
- No Android device is visible in ADB; native device behavior remains NOT TESTED.

## 2026-11-02 — P2 and desktop hover local verification complete

- Full real-PDF library smoke PASS, including IDB rollback after queued bytes,
  restart/reopen, duplicate detection, title change, cancel/confirm deletion and
  exact preservation of vocabulary JSON. Navigation/search regression smoke PASS.
- Real hover highlight pixel verification PASS: 0 -> 1137 -> 0. Native selection
  and Korean lookup popup remain functional. Normalization regression test added.
- Fixed list-refresh Future-returning setState callback; isolated 11-test suite PASS.
- Final analyze and release web build PASS. Windows full Flutter tests remain
  blocked by the existing C++ hook environment; full Linux CI is next.
- Detailed results, constraints and reproduction commands in P2_VERIFICATION.md.

## 2026-11-02 — P2 and requested desktop hover implementation

- Confirmed P1 web deployment and Android APK run both succeeded.
- Implemented separate document repository, native private/no-backup storage,
  browser IndexedDB metadata/bytes transactions, recent list/search/rename/delete.
- Added Android noBackupFilesDir MethodChannel without new permissions/minSdk changes.
- Added non-intercepting mouse hover overlay using longest dictionary matches and
  real PDF fragment geometry; existing native selection remains intact.
- Found/fixed independent X/Y normalization in real PDF test; actual hover pixel
  check PASS (0/1137/0) and selection popup still works.
- Isolated 11-test suite PASS, including native managed copy/restart/original
  preservation, write/delete failures and rollback, hover cancellation/cache and UI.
- Windows full tests blocked before test execution by missing PDFium C++ compiler.
- Real browser restart/reopen, duplicate prevention and injected IDB transaction
  rollback PASS. Full rename/delete smoke and final release rebuild still underway.

## 2026-11-02 — P0 started

- User authorized a resumable work system followed by the Reader roadmap.
- Added root agent instructions, roadmap and current-state handoff.
- Next: verify source snapshot utility, then begin page rail and page-entry UI.

## 2026-11-02 — P0 complete / P1 active

- Executed checkpoint utility; readable manifest and all 30 copied source hashes PASS.
- Snapshots include untracked source but exclude PDFs, credentials and duplicate files.
- Active next action: modular page navigation widgets and PDF controller integration.

## 2026-11-02 — P1 implemented and locally verified

- Added page-entry dialog with range/integer validation and a 48px right page rail.
  Rail previews a destination and commits on release in either viewing mode.
- Preserved existing progress storage, selection, dictionary and search behavior.
- Fixed accessibility increment/decrement metadata and pointer-cancel navigation
  discovered by the widget tests; all three isolated widget tests now PASS.
- Final analyze, release web build, 16 dictionary checks and 8 startup checks PASS.
- Real two-manual PDF smoke PASS for input, rail, both modes, reload, separate
  document positions and search navigation. Test tool is saved for future sessions.
- Whole Windows test command still FAILS before running tests because the existing
  PDF native hook needs a C++ compiler. Full Linux CI will be checked after push.
- Snapshot verification PASS for all 34 source/manifest hashes; no vocabulary data
  changed (bundled CSV SHA-256 remains 2a3a7a6e...209ec0e).

## 2026-11-02 — P1 pushed / P2 prepared

- P1 commit 1c2f113b74ec496c319acd5ad053072945b45bc6 pushed to main.
- Web CI 41386604083 and Android CI 41386604117 started; not assumed successful.
- P2 code inspection saved in P2_LIBRARY_PLAN.md, including native/web storage,
  deletion consistency, backup rules and tests. No P2 runtime code added yet.

## 2026-11-02 — P1 full test verification / hardened checkpoints

- Both Linux CI jobs completed full Flutter test steps successfully; analyze PASS.
- Web release build and Android test-APK compilation still running at this point.
- Hardened snapshot completion: manifest is published by rename only after all
  source copies finish. Partial snapshots must be ignored on resume.
- Verified all 35 original/copy/manifest hashes. Root AGENTS.md describes how to
  choose a complete verified snapshot and preserve unrelated staged user work.

## 2026-11-03 — P3 local verification complete

- Added per-document page bookmarks with normalized position/zoom and safe deletion
  rollback; existing vocabulary/word bookmarks/flashcards are untouched.
- Added lazy embedded outline and visible-only thumbnails with two render jobs,
  cancellation and image disposal. No new dependency or SDK change.
- Analyze, web build and 17 isolated tests PASS. Controlled real 5-page PDF smoke
  PASS for bookmark restoration/restart, modes, outline, thumbnails and deletion.
- Existing navigation/library/hover regression PASS; hover pixels 0 -> 1137 -> 0.
  Dictionary checks 16 and startup checks 8 PASS.
- Initial no-outline smoke selector FAIL was a Flutter semantics selector issue;
  screenshot showed correct UI. Corrected aria-label assertion now PASS.
- Full Windows tests blocked before cases by missing C++ toolchain. Full Linux CI
  pending push; Android physical-device and large-PDF behavior NOT TESTED.

## 2026-11-03 — P3 shipped and builds confirmed

- Source feecf59980b9562fa8c3ce30af89a6fbe1ece7b0 pushed to main.
- Web 41550906107 and Android test APK 41550905838 both SUCCESS, including full
  Linux tests and analyze. Public P3 real PDF smoke PASS in the deployed app.
- Narrow 360px canvas physical click saves bookmark and opens navigator. Activated
  web semantics pointer click is intercepted; accessibility path remains unresolved.
- Android device, large PDF and production release signing NOT TESTED/unchanged.
- P4 selected-word occurrence storage is next; no P4 source implemented yet.

## 2026-11-03 — Direct Reader controls and dictionary highlight toggle

- User steering: direct preview/bookmark grid and separate outline, retaining the
  current-page bookmark shortcut. Grid stars add/remove bookmarks; filter shows
  bookmarked pages. Existing bookmark locations and keys preserved.
- Highlight button toggles always-on dictionary terms vs mouse hover. Reuses PDF
  geometry and nearby-page cache; ignores obsolete results. No dictionary writes.
- Fixed Future-returning setState callback found by widget tests. Final 19 isolated
  tests, analyze and release web build PASS. Real PDF controls/filter/restart/delete
  smoke PASS; library/navigation/search regressions PASS.
- Pixel check: cursor away 0; hover 1137; exit 0; always-on 1137; hover-only 0.
  Native PDF selection and meaning popup also PASS while always-on enabled.
- Term checks 16/startup checks 8 PASS; CSV unchanged. No Android device test.

## 2026-11-03 — Reader controls deployed and verified

- Source 97443f16b3c21e5b9550e586497b0a9bd93840f2 pushed.
- Web 41558021272 and Android test APK 41558021226 both completed SUCCESS.
  Both full Linux test steps and analyze PASS. Production signed APK unchanged.
- Public controls/bookmark/filter/outline/delete and library/always-on selection
  smoke PASS. Public highlight pixel toggle check PASS (0/1137/0/1137/0).
- Next P4 term occurrence storage remains planned; device/large PDF checks remain
  NOT TESTED. Prior narrow web semantics pointer issue remains unverified.

## 2026-11-03 — Reliability repairs and P4/P5 local completion

- Fixed per-record native/IndexedDB metadata isolation without replacing corrupt
  records; preview star refresh retains scroll/mounted thumbnails. Highlight state
  distinguishes zero matches, unavailable text/geometry, errors and explicit retry.
- Added separate learning snapshot and exact per-content-hash/page/character-range
  source records, green fragment highlights, saved-term/document lists, source jump
  and return to prior view. Existing dictionary/review cards expose PDF source links.
- PDF deletion retains learning snapshots/context and disables missing source links.
  Dictionary bookmarking is idempotent with failure rollback; definitions preserved.
- Added English definitions to Reader popup; Reader display settings persist.
- Analyze/web build and 38 isolated tests PASS. Real synthetic PDF smoke PASS for
  same-page second occurrence, dedup, cross-document jump/back, restart, dictionary
  detail route, corruption isolation, image-only guidance and deletion retention.
- Existing library/hover, navigation/search and preview/bookmark smokes PASS. Pixel
  check 0/1137/0/1137/0, term checks 16/startup checks 8 PASS; bundled CSV unchanged.
- PDF adapter unit tests execute in Linux CI; browser-only Flutter unit test loading
  was not successful locally. Actual app IndexedDB injection passed separately.
- Native device/large/rotated/encrypted/restricted-PDF scenarios NOT TESTED.
- Manual unknown-term creation, Reader export and native path-based large-PDF
  opening remain later work. No AI/OCR/server/package/minSdk changes.

## 2026-11-03 — P4/P5 deployment verified

- Runtime 55937793390517cfef02f410a8b65260e45e6633 pushed. Web 41595274901 and
  Android test APK 41595274985 both SUCCESS, including full Linux tests/analyze.
- Public exact occurrence/source/back, dictionary detail, reload, damaged metadata
  isolation/reimport refusal, image-only guidance, PDF deletion-retained learning/
  disabled links, library rollback and hover pixels 0/1137/0/1137/0 PASS.
- Production signing unchanged; Android device/large-PDF behavior NOT TESTED.
- Next P6 native/performance verification. Manual unknown terms and Reader backup
  remain future work. Existing dictionary backup has not been expanded.

## 2026-11-03 — Learning priorities / Reader storage safety local verification

- Reviewed all ten screenshot features against actual existing review/stats/domain/
  related-term code. Recorded priority plan; data safety chosen before new records.
- Reader learning key/schema retained. Shared UI-isolate guard, Web Locks and
  read-latest mutation prevent stale overwrites/resurrection between new writers.
- Live process/storage-event refresh; failures preserve last good records. Missing
  lock support explicitly refuses mutation. Old app tabs must be refreshed.
- Reader automatic dictionary bookmark link detects a stale persisted dictionary
  and reports partial success rather than replacing it. Manual global dictionary
  multi-tab editing remains outside scope.
- 45 isolated tests, analyze and web release build PASS. Real two-tab held-lock,
  live refresh, suppressed-event stale save, unsupported lock refusal and existing
  PDF learning/source-return workflow PASS. Initial inactive-tab automation fixed.
- Commit/push and exact-SHA full Linux CI/public verification next.

## 2026-11-03 — S1 storage safety deployed / verified

- Source bd3ee40ae63f4a3916ac64e48dfea90fa14093f4 pushed. Web 41653024597 and
  Android test APK 41653024525 SUCCESS: full Linux tests/analyze and platform builds.
- Public two-tab safety smoke PASS: held-lock serialization, live additions/removals,
  no stale deletion resurrection, safe bookmark retry and unsupported-lock refusal.
  No JS runtime errors. Local existing PDF learning/source-return regression PASS.
- 45 isolated tests, 8 startup tests and CSV hash preservation PASS. Final snapshot
  manifests verified. Android device NOT TESTED (adb empty); native multi-process,
  large PDFs and mixed old/new writer versions NOT TESTED. Old tabs must reload.
- Permanent release APK unchanged; CI APK uses temporary test signer.
- Next first unfinished module: P1 latest/snapshot definition and source availability
  consistency; not implemented yet. Full learning-feature plan preserves all ten suggestions.

## 2026-11-03 — S2 consistency local implementation

- Current dictionary primary meaning/definition/explanation shown together; missing
  entries use labeled saved snapshots. Empty edits never revive outdated fields.
- Shared managed-file availability, isolated per-file failures, navigation recheck,
  duplicate-click guard and reported open failures. No storage key/data migration.
- 29 isolated tests and existing real PDF learning smoke PASS. Focused browser
  persisted edit/delete + IndexedDB missing bytes flow PASS; snapshots unchanged.
- Initial tester/temp/fake-clock/locator issues resolved and documented. Final
  analyze/build then scoped source commit and CI/public validation remain.


## 2026-11-04 — S2 verified and Recall v1.0.4 distributed

- S2 b3da5c2 passed both CI runs and public web consistency smoke.
- Source e752e34 sets 1.0.4+5 and passed Pages and Android test APK CI.
- Signed run 41791432029 published v1.0.4. Verified APK checksum, package,
  version code and matching v1.0.3 signer. Latest APK URL responds successfully.
- Android device install NOT TESTED. Next module is Reader backup/restore.


## 2026-11-04 — S3 single tap term lookup

- PASS: analyze and release web build. Browser click and emulated touch opened the definition and saved the lower of two matching PDF occurrences. Zoom and touch drag checks passed. Existing selection and source consistency smoke passed.
- Resolved smoke setup and locator failures involving semantics readiness, zoomed visibility and duplicate accessibility announcements.
- NOT TESTED: deployed web and Android device.


## 2026-11-04 — S3 public deployment

- The deployed app still required dragging while the click implementation was local. Released source 3afdd04 with the S3 commit.
- PASS: Pages 41802098782 and public click, emulated touch, zoom, exact source save and touch drag smoke.
- PASS: Signed build 41802098954 and public v1.0.5 APK download. Verified package identity, version code 6, previous certificate and SHA-256 92d94989a7dd66c80c057e7cd82c55717bb1adc67ba45090a87bf318a0ec2a85.
- NOT TESTED: Android device gestures and installation.
# 2026-11-08 — Manual PDF personal vocabulary

Added selection-to-manual-entry flow, conservative selected-offset sentence extraction,
personal identities without schema migration, duplicate confirmation and flashcard
back note/source. Reused existing dictionary CRUD and examples. Corrected test to use
deleteEntries (deleteCard intentionally only removes collection membership).
49 isolated tests, full analyze, release web build and actual browser save/reload PASS.
Full native tests blocked by missing Windows C++ compiler; Android device/build NOT TESTED.
See PERSONAL_VOCABULARY_VERIFICATION.md. No user data, unrelated staged copies or
collaboration changes removed. No AI/package/DB addition. Commit authorized; no push/merge.
