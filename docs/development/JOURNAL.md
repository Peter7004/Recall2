# Reader development journal

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
