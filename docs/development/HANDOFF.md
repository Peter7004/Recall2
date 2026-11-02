# Reader handoff — start here

Updated: 2026-11-02 (Asia/Seoul)
Baseline app: 6bfce4a420193d47db20961fa93d069c142b221b, branch main.
Handoff-system commit: 4887541.
P1 implementation commit: 1c2f113b74ec496c319acd5ad053072945b45bc6 (pushed to main).

## Active work

P0 complete: handoff, roadmap, journal and source snapshots established.
P1 implementation, local verification and full Linux CI tests complete.
Next: check web deployment / Android compilation status. P2 is the next
implementation milestone; its concrete plan is already saved.

## Next concrete action

1. Check GitHub Actions for 1c2f113: web run 41386604083, Android run 41386604117.
   Both full test steps PASS at last check. Web release build and Android test APK
   compilation still IN PROGRESS. Record deployment and Android build separately.
   If interrupted during CI, do not assume success. Inspect logs and fix within
   current scope if either fails; do not replace PDF packages or delete user data.
2. When run status changes, update handoff records using explicit docs paths.
   A docs-only [skip ci] message avoids launching identical builds again.
3. Begin P2: inspect native application-support/no-backup paths and web IndexedDB
   options; add a document-library repository with platform adapters, then recent
   document list/import/open/delete UI. Preserve source PDFs and study records.
   Add native PDF-specific backup exclusions instead of disabling all app backups.
   Initial code inspection and concrete adapter/test steps are saved in
   docs/development/P2_LIBRARY_PLAN.md. P2 application code is not implemented.

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
  analyze also PASS. Android compilation and web deployment not yet final.
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
