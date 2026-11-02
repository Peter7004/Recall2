# Reader handoff — start here

Updated: 2026-11-02 (Asia/Seoul)
Baseline: 6bfce4a420193d47db20961fa93d069c142b221b, branch main.

## Active work

P0 complete: handoff, roadmap, journal and source snapshots established.
P1 active: implement page-number dialog and right-hand document page rail.
No P1 source changes yet.

## Next concrete action

1. Implement P1 in modular navigation widgets, wire into PdfReaderPage, add tests.
2. Snapshot before analyze/build; record actual results and commit only owned files.
3. Continue roadmap with P2 after the P1 milestone is verified.

## Verification / environment

- P0 PASS: executed checkpoint utility and verified the manifest and all 30 copied
  file hashes. Snapshot: build/reader-checkpoints/20261102-125609-940-c1c1c6.
- P1: tests not run yet.
- Prior 6bfce4a: full tests and web deployment passed in GitHub Actions. Recheck
  prior Android run 41190835373 rather than assuming its final result.
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
Read the latest manifest, compare its base commit and files with current git/code,
then resume. Snapshots do not overwrite files or run git commands on restoration.
Disk writes already completed survive a usage-limit interruption; unsaved editor
buffers or work after the latest checkpoint cannot be promised recoverable.

User resume message: **“개발 인계 기록을 읽고 마지막 미완료 작업부터 계속해 줘.”**
