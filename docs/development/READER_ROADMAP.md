# Recall Reader development roadmap

Authorized 2026-11-02: establish resumable development records, then begin the
previously proposed Reader improvements. Deliver small, tested milestones.

| ID | Status | Deliverable / completion criteria |
| --- | --- | --- |
| P0 | DONE | Repository handoff, journal, source checkpoint command. Snapshot manifest and all 30 source file hashes verified. |
| P1 | DONE; DEPLOYMENT TRACKED IN HANDOFF | Right-hand document page navigator and validated page entry. Widget tests, analyze, release web build, real PDF smoke and both full Linux CI test jobs PASS. Android device gestures NOT TESTED. |
| P2 | DONE; DEPLOYMENT TRACKED IN HANDOFF | Managed PDF library, native no-backup/web IndexedDB. Real browser CRUD/rollback, 11 isolated tests and both full Linux test jobs PASS. Desktop hover/selection verified. Android build and web deployment tracked separately; device behavior NOT TESTED. |
| P3 | DONE | Page bookmarks, embedded outline and lazy thumbnails. Separate keys, document-deletion cleanup/rollback. Visible cells only, 160x210 thumbnails, 2 render tasks, explicit cancellation/disposal. Both full Linux CI tests, web deployment and Android test APK build PASS; public PDF smoke PASS. Device/large-PDF behavior NOT TESTED. |
| P3a | DONE | Direct preview/bookmark grid with per-page stars/filter, separate outline entry, toggle always-on dictionary highlights versus hover-only. 19 isolated tests, full Linux CI, web deployment/public smoke and Android test APK build PASS; device tests NOT TESTED. |
| P4 | DONE | Save selected dictionary terms with document ID, page, selected text and geometry. Separate word identity from multiple occurrences; prevent duplicate learning entries. |
| P5 | DONE | Return from word card to source, persistent highlights, return-to-previous-reading-position. Deleted documents must disable source navigation while retaining learning records. |
| S1 | DONE | Priority P0 Reader store/tab collision safety, live refresh and stale dictionary auto-bookmark refusal. 45 isolated tests, full Linux CI web 41653024597 / Android test APK 41653024525 and public two-tab smoke PASS. Device NOT TESTED. See STORAGE_SAFETY_VERIFICATION.md. |
| P6 | PLANNED | Large-document performance and accessibility. Obtain real PDF fixtures and test Galaxy S25 Ultra; do not invent device or 100MB/500-page results. |

Existing baseline 6bfce4a: text PDF selection/lookup, continuous and horizontal
paged modes, per-content-hash progress preferences, search/results/highlighting.
P2 now stores managed PDF copies and metadata in native private/no-backup storage
or browser IndexedDB; restart then open from the recent library restores progress.

P1 design: a narrow right-hand page rail maps vertical pointer position to PDF
page number independently of document layout/zoom. On drag show a page preview
and navigate on release, avoiding repeated expensive rendering. Clicking the
current page count opens a validated integer entry dialog. Use existing pdfrx
controller; no dependency or database changes needed.

Out of scope: AI calls, OCR, accounts, cloud sync, FSRS, PDF content editing,
whole-app redesign. Preserve all prior user data and minimum-SDK policy.

The statuses describe development, not automatic scheduling. No automatic action
is scheduled at quota reset. The user resumes the chat when access is available.

2026-11-03 review follow-up: isolate corrupt document metadata without writes;
preserve preview scroll on star updates; distinguish highlight errors/unavailable/
zero matches with retry. Known-term source saving and return are implemented in
separate Reader preferences; no migration of dictionary data. Reader export and
manual unknown-term creation remain subsequent extensions after P4/P5 validation.

P4/P5 source 5593779 verified: web 41595274901 and Android test APK 41595274985
SUCCESS, including full Linux tests/analyze. Public learning/library/pixel smoke
PASS. P6 native/large-PDF checks remain NOT TESTED. Return history is session-only.

User learning feature priority plan (2026-11-03): LEARNING_FEATURE_PRIORITIES.md.
S1 is the first implementation; backup/consistency precede new quizzes/statistics.
