# Recall Reader development roadmap

Authorized 2026-11-02: establish resumable development records, then begin the
previously proposed Reader improvements. Deliver small, tested milestones.

| ID | Status | Deliverable / completion criteria |
| --- | --- | --- |
| P0 | DONE | Repository handoff, journal, source checkpoint command. Snapshot manifest and all 30 source file hashes verified. |
| P1 | DONE; DEPLOYMENT TRACKED IN HANDOFF | Right-hand document page navigator and validated page entry. Widget tests, analyze, release web build, real PDF smoke and both full Linux CI test jobs PASS. Android device gestures NOT TESTED. |
| P2 | DONE; DEPLOYMENT TRACKED IN HANDOFF | Managed PDF library, native no-backup/web IndexedDB. Real browser CRUD/rollback, 11 isolated tests and both full Linux test jobs PASS. Desktop hover/selection verified. Android build and web deployment tracked separately; device behavior NOT TESTED. |
| P3 | IMPLEMENTED; CI PENDING | Page bookmarks, embedded outline and lazy thumbnails. Separate keys, document-deletion cleanup/rollback. Visible cells only, 160x210 thumbnails, 2 render tasks, explicit cancellation/disposal. |
| P4 | PLANNED | Save selected dictionary terms with document ID, page, selected text and geometry. Separate word identity from multiple occurrences; prevent duplicate learning entries. |
| P5 | PLANNED | Return from word card to source, persistent highlights, return-to-previous-reading-position. Deleted documents must disable source navigation while retaining learning records. |
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
