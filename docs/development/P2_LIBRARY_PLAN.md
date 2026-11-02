# P2 document library — implementation starting point

Original investigation 2026-11-02. This plan has now been implemented in 826ed80;
see P2_VERIFICATION.md and HANDOFF.md for actual results and remaining limits.
Historical investigation/design notes are preserved below. The chosen Android
adapter uses noBackupFilesDir, so PDF-specific backup XML was not needed.

## Confirmed from current code

- Reader still uses file_picker withData and holds a Uint8List in widget state.
- ReaderProgress uses content SHA-256, separate per-document SharedPreferences keys.
- No library metadata, durable PDF copy, document deletion, or PDF backup rules exist.
- path_provider 2.1.6 and web 1.1.1 already exist as transitive dependencies.
  path_provider exposes application support paths; web contains IndexedDB bindings.
  Declare them directly if used; do not add a large database package automatically.
- Android MainActivity is a plain FlutterActivity. Manifest does not specify
  fullBackupContent/dataExtractionRules. Do not disable existing vocabulary backups.
- RecallStore backup exports learning data, not a Reader document library. Keep
  its existing format and storage keys intact.

## Small implementation steps

1. Define ReaderDocument metadata and DocumentRepository interface: list, import
   bytes, load bytes, update last-opened/page-count, delete, availability check.
   ID remains the full content hash; equal filenames must not imply equal PDFs.
2. Add an in-memory fake repository for behavioral tests and dependency injection.
3. Add conditional native/web adapters. Native: managed private folder, temporary
   write then rename, metadata only after successful bytes write. Resolve and
   validate every managed path; never delete or overwrite the picked source path.
   Web: store PDF bytes as Blob/ArrayBuffer in IndexedDB, not localStorage/base64;
   use transactions for document metadata and bytes. Handle quota/private-mode errors.
4. Add recent-library UI, import/open actions, duplicate notification, rename title
   and explicit delete confirmation. Keep the existing reader/controller reusable.
   Do not mark page count known until PDF parsing has actually reported it.
5. Delete managed copy + library record + exact progress key and future page
   bookmarks. Preserve dictionary/learning occurrences; source availability false
   disables returning to a deleted document. Design repository deletion failure
   handling before exposing the button, so failed writes do not hide existing PDFs.
6. Apply PDF-specific Android backup exclusions for both legacy and Android 12+
   configuration, or use native noBackupFilesDir through a narrow adapter. Confirm
   the actual selected path before writing backup rules. Check current official
   Android documentation during implementation; verify merged manifests/build.
7. Verify import, duplicate import, restart/open without picker, missing file,
   insufficient storage, failed/cancelled writes and deletion rollback. Native
   and web tests are separate. Browser storage can be cleared by users/browser;
   never promise permanent retention. No original PDF or user learning-data deletion.

## Candidate new files

- lib/reader/library/reader_document.dart
- lib/reader/library/document_repository.dart
- lib/reader/library/document_repository_io.dart
- lib/reader/library/document_repository_web.dart
- lib/reader/library/reader_library_page.dart
- test/reader_library_test.dart

Before changing Android XML/native sources, extend the checkpoint source allowlist
to include those exact owned files. Exclude signing/local.properties/keys as before.
Record choices and each verified substep in HANDOFF.md; no new approval needed for
this already authorized phase unless an actual destructive scope change is required.
