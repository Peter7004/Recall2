# Recall Reader MVP

The existing Flutter project, routes, file_picker, and dictionary store are
retained. The header PDF button opens `PdfReaderPage` and its recent-document
library. Import creates a managed copy; vocabulary is never modified. Reading progress is stored
separately in `recall.reader.progress.v1.<SHA-256 of PDF contents>` preferences.
Reopening the same file after restarting restores its page, normalized page-local
viewport center, zoom, and viewing mode. Renamed identical files share progress;
different contents (even with identical filenames) have independent progress.
After restarting, open a saved document from the library without selecting the
source file again. Content-hash duplicates share one document and reading record.
Renaming a library title does not rename or modify the source PDF.

Android stores managed files under `Context.noBackupFilesDir/recall_reader` through
a narrow MethodChannel. PDF copies/metadata are excluded from Android system backup;
existing dictionary/preferences backup behavior is preserved. Other native targets
use application support storage. Web stores metadata and bytes separately in
IndexedDB with atomic import/delete transactions. Browser storage can be cleared
by users or eviction; keep original PDFs. No document is uploaded by the app.

Deletion requires confirmation and removes the managed document and its reading
position, preserving original PDFs and learning data. Failed deletion before the
native logical rename restores progress. A physical cleanup failure is reported
and the private deleted-folder cleanup retries on library listing. Future page
bookmarks and learning occurrence links are separate roadmap work.

Continuous mode lays out pages vertically. Paged mode lays them out horizontally
and snaps a fit-scale swipe to at most one adjacent page. At increased zoom,
gestures pan the page; use the page arrows to navigate. Mode switches preserve
the current page and page-relative viewport center. Position writes are debounced,
serialized, and flushed on document switches, route disposal, and lifecycle
background events. Abrupt process termination before a write can still lose the
last fraction of a second; no storage API promises a flush after force-stop.

The search button exposes case-insensitive literal full-document text search,
progress, result counts and a virtualized result list with page/context. Selecting
a result uses its PDF text geometry, not a first-string-match heuristic. Matches
are highlighted with the package paint callback. `PdfTextSearchSession` keeps
bounded per-match context rather than retaining all structured page text.
Scans without an embedded text layer are not searchable. No OCR is attempted.

The viewer uses pdfrx (MIT) and PDFium. Its native text selection paints the
selection highlight. A debounced selection callback preserves Unicode and looks
up English, Korean, and mixed-language selections (up to 2000 UTF-16 code units).
The nonmodal popup shows existing equivalents and Korean explanations, or an
explicit unavailable state; it does not generate translations. Stale asynchronous
selection results are ignored when selection changes or a new file opens.

`terminology_lookup.dart` provides a read-only concept/alias model and lookup
interface. Multiple expressions can map to a card ID, and ambiguous aliases can
return multiple cards. English matching ignores case, respects Unicode word
boundaries, and accepts whitespace across line breaks. Korean matching tolerates
spacing differences and a conservative particle whitelist, not full morphology.
Longer overlapping matches take precedence. The highlight remains the selected
PDF range, including particles; it is not trimmed to the canonical dictionary
expression. Up to five matches are shown. AI draft/review statuses remain visible.

Desktop mouse hover also highlights a recognized term/compound expression using
the actual PDF text fragments. It is transient, handles fragments on separate
lines and never changes native selection. Unknown text, whitespace and scanned
images are not highlighted. Matching/geometry loads on hover per visible page;
mouse exit, viewport change and pointer down clear the highlight. The copy
permission flag is respected. No AI or OCR is used.

The bundled 288 source rows have no empty English terms, Korean primary meanings,
English definitions, or Korean explanations. This does not verify correctness or
guarantee that every surface form or synonym exists in the data. No synonyms are
invented or automatically split out of prose definitions. Additional aliases can
be supplied to ReaderConcept without modifying stored vocabulary. Decomposed
Unicode (NFD), missing PDF ToUnicode maps, unusual hyphenation, multi-column
reading order, and equations may prevent correct matching. No OCR is attempted.

Run `dart tool/reader_lookup_check.dart` for native-toolchain-independent matching
checks. These do not replace PDF gesture tests or Windows/Android device tests.

Single-tap word hit testing has not been implemented or device-verified. Use the
library's default desktop text selection or mobile long-press selection handles.
PDFs without embedded selectable text need OCR, which is not included. Encrypted
or damaged PDFs use the viewer's existing error handling. Large documents are
loaded into memory by the file picker/viewer; 100MB+ memory/performance behavior
has not been verified. Library metadata listing does not read all PDF bytes.

Windows and Android are supported by pdfrx, but successful web builds do not
prove native compatibility. Windows needs Developer Mode for dependency
symlinks, the Visual Studio C++ toolchain, and platform project scaffolding (this
repository originally has Android, iOS, and web targets only). Android needs its
existing Android SDK/JDK setup and permanent release signing configuration.

No OCR, AI calls, summaries, generated questions, or terminology migration is
included. Future lookup services can replace the placeholder without changing
the dictionary store or PDF rendering layer.
