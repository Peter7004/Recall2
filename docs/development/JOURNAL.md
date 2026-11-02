# Reader development journal

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
