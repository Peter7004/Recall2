# Recall Reader MVP

The existing Flutter project, routes, file_picker, and dictionary store are
retained. The header PDF button opens `PdfReaderPage`. PDF bytes live only in
the reader session; vocabulary is never modified. Reading progress is stored
separately in `recall.reader.progress.v1.<SHA-256 of PDF contents>` preferences.
Reopening the same file after restarting restores its page, normalized page-local
viewport center, zoom, and viewing mode. Renamed identical files share progress;
different contents (even with identical filenames) have independent progress.
There is no managed-file library yet: after restart, select the PDF again.

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
loaded into memory by the file picker; document caching and a recent-file library
are deliberately outside this first version.

Windows and Android are supported by pdfrx, but successful web builds do not
prove native compatibility. Windows needs Developer Mode for dependency
symlinks, the Visual Studio C++ toolchain, and platform project scaffolding (this
repository originally has Android, iOS, and web targets only). Android needs its
existing Android SDK/JDK setup and permanent release signing configuration.

No OCR, AI calls, summaries, generated questions, or terminology migration is
included. Future lookup services can replace the placeholder without changing
the dictionary store or PDF rendering layer.
