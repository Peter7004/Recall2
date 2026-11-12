# Recall Reader development roadmap

Authorized 2026-11-02: establish resumable development records, then begin the
previously proposed Reader improvements. Deliver small, tested milestones.

| ID | Status | Deliverable / completion criteria |
| --- | --- | --- |
| C4a | COMPLETE LOCALLY | AI 판단 학습 우선순위 label, recovered v3.0 grade criteria/source/provenance limits.206 tests/analyze/web and real1100/390/320 UI/storage PASS. No data/rank changes; personal cards distinct. Not committed/deployed. |
| C4 | RELEASED1.0.14+15 | Dictionary priority × source DF/N decision map, reasons and exact counts. PR14/281cde4;206 tests/analyze/web/startup8 and public1100/390/320 corpus/PDF regressions PASS. Actual1.0.13→1.0.14 saved-data preservation and permanent APK signature/package/public checksum PASS. No data/ranking changes. Android device NOT TESTED. |
| H1 | RELEASED1.0.13+14 | Loaded-page geometry and cache fix. PR13/19e570a, CI/Pages/permanent APK and public source-return checks PASS; actual1.0.12→1.0.13 saved-data preservation and APK certificate/package/checksum PASS. Physical Android/user profile NOT TESTED. |
| C3 | RELEASED1.0.12+13 | Recommendation DF/N donuts and source DF/TF; context-filter wording with explicit method limits. Windows201/analyze/web, public mobile/desktop graph and actual1.0.11→1.0.12 saved-data checks PASS; permanent signed APK/public checksum verified. No statistics or storage changes. Android device NOT TESTED. |
| C2 | RELEASED1.0.11+12 | Home textbook/abstract focus, source-specific daily recommendations/study, separate preference persistence and preserved explicit sessions. Windows198/analyze/web/startup8, public browser and actual1.0.10→1.0.11 stored-data preservation PASS; signed APK/public checksum verified. See DAILY_CORPUS_RECOMMENDATIONS.md. Android device NOT TESTED. |
| UI3 / WIN | RELEASED 1.0.9+10 | Five bottom tabs with persistent Reader/study and concise copy. Windows188 tests/PDFium1/analyze/debug APK, Linux188/startup8, public web/Reader/corpus and 1.0.8→1.0.9 saved-data upgrade PASS. Permanent signature/package retained; public APK checksum PASS. Android device NOT TESTED. See RELEASE_1.0.9.md and WINDOWS_LOCAL_DEVELOPMENT.md. |
| UI2 | RELEASED 1.0.8+9 | Supplied UI v2 theme/home/records/dictionary/flashcards/settings integrated with real data. Full Linux187 tests, public browser regressions and permanent signed APK PASS. Device NOT TESTED; see RELEASE_1.0.8.md. |
| C1 | RELEASED1.0.10+11 | 834-term latest provisional accepted TF/DF for22 PDF files/639 abstracts; pending counts/provenance separated. Ledger86182/661 hashes/834 matches, Windows191/analyze/web/CLI, Linux CI, public corpus/PDF and1.0.9→1.0.10 saved-data upgrade PASS. Permanent APK certificate/package/payload/public checksum PASS. See REAL_CORPUS_INTEGRATION.md and RELEASE_1.0.10.md. Android device/expert semantic review NOT TESTED. |
| M1 | IMPLEMENTED; verification in PERSONAL_VOCABULARY_VERIFICATION.md | Manual PDF personal vocabulary, editable context and existing flashcard integration. 49 isolated tests/analyze/web build/browser save-reload PASS; native host tests blocked by C++ toolchain; Android NOT TESTED. |
| P0 | DONE | Repository handoff, journal, source checkpoint command. Snapshot manifest and all 30 source file hashes verified. |
| P1 | DONE; DEPLOYMENT TRACKED IN HANDOFF | Right-hand document page navigator and validated page entry. Widget tests, analyze, release web build, real PDF smoke and both full Linux CI test jobs PASS. Android device gestures NOT TESTED. |
| P2 | DONE; DEPLOYMENT TRACKED IN HANDOFF | Managed PDF library, native no-backup/web IndexedDB. Real browser CRUD/rollback, 11 isolated tests and both full Linux test jobs PASS. Desktop hover/selection verified. Android build and web deployment tracked separately; device behavior NOT TESTED. |
| P3 | DONE | Page bookmarks, embedded outline and lazy thumbnails. Separate keys, document-deletion cleanup/rollback. Visible cells only, 160x210 thumbnails, 2 render tasks, explicit cancellation/disposal. Both full Linux CI tests, web deployment and Android test APK build PASS; public PDF smoke PASS. Device/large-PDF behavior NOT TESTED. |
| P3a | DONE | Direct preview/bookmark grid with per-page stars/filter, separate outline entry, toggle always-on dictionary highlights versus hover-only. 19 isolated tests, full Linux CI, web deployment/public smoke and Android test APK build PASS; device tests NOT TESTED. |
| P4 | DONE | Save selected dictionary terms with document ID, page, selected text and geometry. Separate word identity from multiple occurrences; prevent duplicate learning entries. |
| P5 | DONE | Return from word card to source, persistent highlights, return-to-previous-reading-position. Deleted documents must disable source navigation while retaining learning records. |
| S1 | DONE | Priority P0 Reader store/tab collision safety, live refresh and stale dictionary auto-bookmark refusal. 45 isolated tests, full Linux CI web 41653024597 / Android test APK 41653024525 and public two-tab smoke PASS. Device NOT TESTED. See STORAGE_SAFETY_VERIFICATION.md. |
| S2 | DONE | Coherent current definitions versus labeled snapshots; common source availability and navigation recheck. Public web smoke PASS and signed v1.0.4 published. See CONSISTENCY_VERIFICATION.md. |
| S3 | DONE | Single tap or click opens the existing term popup and saves the exact PDF range. Public mouse and emulated touch smoke passed. Signed APK v1.0.5 published. |
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
