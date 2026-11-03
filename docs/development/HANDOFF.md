# Reader handoff — start here

Updated: 2026-11-03 (Asia/Seoul)
Baseline app: 6bfce4a420193d47db20961fa93d069c142b221b, branch main.
Handoff-system commit: 4887541.
P1 implementation commit: 1c2f113b74ec496c319acd5ad053072945b45bc6 (pushed to main).
P2 + desktop hover commit: 826ed802d878722b35933ffc36c52c49a2260f86 (pushed).
P2 web CI 41404851026 and Android CI 41404851004 both completed SUCCESS,
confirmed again 2026-11-03. Public library/hover smoke and pixel verification PASS.

## Current module — user-requested Reader controls (2026-11-03)

COMPLETE: direct preview/bookmark grid plus separate outline button; keep current-page
bookmark shortcut. Add toggle between always-on dictionary highlights and hover-only.
Reuse actual PDF geometry and read-only dictionary matching; no vocabulary writes.
Runtime implemented in document_navigator.dart, pdf_reader_page.dart, term_hover_region.dart.
Combined grid has per-page stars and bookmark-only filter; saved pages restore their
saved viewport on opening. Outline opens directly without loading thumbnails.
Always-on loads PDF geometry for viewer cache-extent pages, no full-document scan.
19 isolated tests PASS after fixing Future-returning setState in bookmark refresh.
Final analyze and final release web build PASS. Actual PDF direct preview/bookmark
stars/filter/restart/outline/deletion smoke PASS. Library/navigation regressions PASS.
Always-on highlight pixel check PASS: hover 0/1137/0; always 1137; hover-only 0.
Text selection and dictionary popup PASS even while always-on. CSV unchanged.
Pushed as 97443f16b3c21e5b9550e586497b0a9bd93840f2.
Web 41558021272 full tests/analyze/build/deployment SUCCESS.
Android 41558021226 full tests/analyze/test APK build SUCCESS.
Public controls/highlight smokes and pixel assertions PASS, including star/filter/
restart/delete and selection while always-on. Both exact-SHA workflows SUCCESS.
Next implementation milestone: P4 term occurrence storage, still not implemented.
Verify exact-SHA full tests/builds and public controls/highlight smoke before closure.
Do not assume completion. Production signed APK is unchanged.
P4 occurrence storage remains planned. See READER_CONTROLS_VERIFICATION.md.

## Active work

P0 complete: handoff, roadmap, journal and source snapshots established.
P1 implementation, local verification and full Linux CI tests complete.
P1 web deployment and Android test APK compilation both confirmed SUCCESS.
P2 COMPLETE: managed copies (Android noBackupFilesDir, native private folder,
web IndexedDB), recent list/open/rename/delete. MainActivity added to checkpoints.
Additional authorized request: desktop mouse hover highlights recognized dictionary
words/compound terms on actual PDF geometry, without changing selection behavior.
P2 and hover runtime files/tests complete locally. Analyze and release web build PASS.
Isolated unit harness PASS (11: repository/native filesystem, library UI, hover,
navigation). Fixed a debug-only setState callback returning Future in list refresh.
Real PDF hover pixel check initially FAIL: pdfrx toRect uses uniform height scale;
fixed by converting to natural page rect then normalizing X/width and Y/height.
Added regression test. Real hover pixel check now PASS (0 -> 1137 -> 0 gold pixels),
and actual text selection/lookup PASS. Browser duplicate detection, restart/reopen
without picker and injected IndexedDB transaction failure rollback PASS.
Complete library smoke now PASS, including rename/cancel/confirm deletion and
unchanged vocabulary JSON. Navigation regression smoke also PASS on the new UI.
Full Windows Flutter test still fails before tests (existing missing C++ hook).
P3 runtime COMPLETE locally: separate page bookmarks, embedded outline and lazy
thumbnails. Isolated tests PASS (17); analyze and release web build PASS.
Real 5-page PDF browser smoke PASS: bookmark page-relative restoration, mode
preservation, nested outline destination, rendered thumbnail navigation, restart,
independent documents, absent outline, delete warning/cancel/cleanup and unchanged
vocabulary JSON. Existing navigation/library/hover regression smoke PASS.
Full Windows tests FAIL before execution (missing native C++ toolchain).
P3 full Linux tests and analyze PASS in both CI workflows. Web deployment
41550906107 and Android test APK 41550905838 both completed SUCCESS.
Android device behavior NOT TESTED. Public P3 smoke PASS (same complete flow).
360px web: physical canvas star click/navigation sheet PASS; automated semantics
pointer click intercepted by another semantics node. Narrow semantics issue remains
unresolved; not an Android result. Record in P3_VERIFICATION.md.

## Next concrete action

1. P3 COMPLETE: feecf59980b9562fa8c3ce30af89a6fbe1ece7b0. Web run 41550906107
   and Android test APK run 41550905838 both SUCCESS. Full Linux tests and analyze
   PASS in both; public P3 smoke PASS. Production signed APK is not updated here.
2. Before P4 read this record, roadmap and actual git/code. Ignore unrelated staged
   Korean copies. Keep dictionary and occurrence storage separate. No AI or OCR.
3. P4 next: save selected dictionary terms with document/page/geometry, separating
   word identity from occurrences. No P4 runtime implemented yet. Preserve existing
   dictionary key recall.data.v3 and all learning records. See P3_VERIFICATION.md.
4. Local audit C:/Users/Public/Recall-reader-navigator-20261103; isolated harness
   C:/Users/Public/Recall-p3-unit-20261103. Smoke URL localhost:5204/Recall2/.
   Recreate controlled fixtures using tool/make_reader_outline_fixture.py.
   No large-PDF/device performance claims: 500-page widget test is virtual only.

## Verification / environment

- P0 PASS: executed checkpoint utility and verified the manifest and all 30 copied
  file hashes. Snapshot: build/reader-checkpoints/20261102-125609-940-c1c1c6.
- P1 first widget run: FAIL. Found missing accessibility increased/decreased values
  and cancelled drag still navigating. Fixed both; isolated widget suite PASS (3).
  Changed files: lib/reader/reader_navigation.dart,
  lib/reader/pdf_reader_page.dart, test/reader_navigation_test.dart.
- P1 final analyze PASS; final web release build PASS; terminology regression PASS
  (16), startup regression PASS (8). Complete real-PDF browser smoke PASS: invalid
  entry, valid entry, rail preview/release, first/last page in both modes, mode
  preservation, reload/reopen, independent documents, search navigation; no JS errors.
- Reproduce: tool/reader_navigation_smoke.cjs with RECALL_PLAYWRIGHT_MODULE pointing
  to installed Playwright and RECALL_READER_TEST_URL set to the served web build.
  Defaults to localhost:5202/Recall2/. Requires the two manuals below. Screenshots:
  build/reader-navigation-smoke. Flutter input automation needs focus/key events
  and tooltip animation settling, not raw DOM fill alone.
- Local source audit: C:/Users/Public/Recall-reader-navigation-20261102. Cache and
  TEMP use ASCII paths. Native Windows SDK scaffolding is absent; do not invent tests.
- P1 full Windows test FAIL before execution: existing missing C++ toolchain.
- P1 full Linux Flutter tests PASS in both web and Android CI workflows. Remote
  analyze also PASS. Android compilation and web deployment confirmed SUCCESS.
- Rechecked prior Android run 41190835373: completed SUCCESS. This does not verify
  P1 or actual Android device behavior.
- Prior 6bfce4a: full tests and web deployment passed in GitHub Actions.
- Flutter: C:/Users/Public/Recall-flutter-sdk. ASCII Pub cache junction:
  C:/Users/Public/Recall-reader-pub-cache.
- Windows full Flutter tests previously blocked by missing C++ compiler for
  pdfium_dart. Linux CI can run them. Do not change packages to hide this.
- Use isolated ASCII validation copy, excluding Korean copy files. See tool/validate.ps1.
- Android device behavior NOT TESTED. Existing SDK is under
  C:/Users/Public/BeforeAfterAndroidToolchain/sdk; do not touch another app's source.
- Real fixtures: output/pdf/Recall_User_Manual_v1.0.2_ko.pdf and v1.0.3 (5 pages each).
  Large, scanned, encrypted and restricted PDF scenarios need real fixtures.

## Safety and recovery

Unrelated pre-staged copy files and untracked automation/output/tmp are user work.
Do not reset/clean/stage them. Never use `git add .` or a blanket commit.
No credentials, signing keys, PDFs or user data belong in snapshots or handoffs.

Snapshots: build/reader-checkpoints/<timestamp>/manifest.json and source/.
Last verified complete snapshot: 20261102-130834-438-813e24 (35 files, atomic
manifest publication and comparison against current source PASS). Newer complete
snapshots may exist; verify them instead of assuming this is always the latest.
Read the latest manifest, compare its base commit and files with current git/code,
then resume. Snapshots do not overwrite files or run git commands on restoration.
Choose the latest complete manifest whose hashes verify. Ignore partial folders
without manifest.json; the utility publishes that file only after all source copies.
Disk writes already completed survive a usage-limit interruption; unsaved editor
buffers or work after the latest checkpoint cannot be promised recoverable.

User resume message: **“개발 인계 기록을 읽고 마지막 미완료 작업부터 계속해 줘.”**
