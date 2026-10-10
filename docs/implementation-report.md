# Recall v3.0 Implementation Report

## Implemented Changes

Recall now opens the dictionary and exposes Dictionary, Subjects, Bookmarks,
Flashcards, and Collections. Entries expose only `general_technical` and
`technical`, plus `high`/`medium`/`low` learning priorities. Korean meanings,
English definitions, concise Korean explanations, and existing examples remain.
Search is local, case-insensitive, supports partial English/Korean matches, and
filters by vocabulary type, priority, subject, and bookmarks. Related terms navigate only
when a real entry exists. The editor supports meanings, priorities, and sources.
Management recommendations, collectors, notes, priority reasons, verification,
and arbitrary extra fields are hidden from learner screens and search. Formulas,
symbols, units, and application contexts are retained in storage but are not
actively displayed or edited. No LaTeX, FSRS, or recognition engine was added.

## Files

| File | Change |
| --- | --- |
| `lib/vocabulary.dart` | New typed vocabulary, meaning, source, category, and compatible card models |
| `lib/csv_import.dart` | New CSV parser, validation, preview, and import reports |
| `lib/recall_store.dart` | Global dictionary, collection references, migration, shared updates, and search |
| `lib/main.dart` | Dictionary-first navigation, filtering, details, editing, collection membership, and review |
| `test/recall_store_test.dart` | Data, migration, shared entries, CSV, classification, search, and persistence tests |
| `test/widget_test.dart` | Priority filters, metadata invisibility, safe editing, review, and responsive regression tests |
| `test/v3_fixtures.dart` | Structured generation of fixed-schema CSV test data |
| `pubspec.yaml`, `pubspec.lock` | Added the CSV parsing package |
| `analysis_options.yaml`, `.gitignore` | Excluded source copies and local backups |
| `tool/validate.ps1` | Windows validation outside OneDrive with ASCII temporary paths |
| `examples/vocabulary.csv` | Fixed 13-column example covering both types and all priorities |
| `README.md` | Feature, CSV, migration, verification, and operating documentation |

Fourteen existing Android source/resource copies were moved into
`.recall-backups/android-source-copies/`. Their contents were verified against
the previously staged blobs: 14/14 are unchanged. Existing Git staging was not
modified; the working tree records these moves separately.
Three OneDrive-created invalid Git ref copies were also preserved unchanged
under `.recall-backups/git-ref-copies/` to restore normal fetch/push operation.
Normal refs and unrelated staged copy files were not changed.

## Data Model

`RecallCard` retains existing fields and adds `vocabularyType`, `partOfSpeech`,
`meanings`, `sources`, `verificationStatus`, and `extraFields`. V3 adds
`learningPriority`, `priorityReason`, `inclusionRecommendation`, `collector`, and
`notes`. Meanings serialize `definition_en`/`explanation_ko` and still accept old
`definition`/`explanation` keys. Legacy meaning types and engineering metadata
remain internal compatibility fields, not a third learner vocabulary type.

Schema v3 stores global entries separately from collection `entryIds`. Entry
updates and bookmarks are shared across collections, and each entry appears only
once in dictionary search and global review. Unchecking collection membership
only removes a relationship. Explicit permanent word deletion and collection
deletion now remove the entries, their other collection links, bookmarks, recent
views, and per-entry review history after a warning/confirmation.

## Migration and Compatibility

`recall.data.v1` or `recall.data.v2` is migrated to `recall.data.v3` without
overwriting either original. Explicit legacy `general` becomes
`general_technical`, with its original value preserved in hidden extra fields.
Missing priorities default to `medium`; missing recommendations default to
`review`. Legacy definitions are preserved without automatic translation.
Legacy IDs, images, bookmarks, review exclusions/history, categories, goals,
and recent views remain available. Duplicate legacy IDs are repaired; separate
legacy records are retained to protect their individual history. Legacy fields
remain available to existing screens and API callers. Invalid saves show an
error and are not silently replaced.

CSV supports legacy and extended headers, UTF-8/BOM, quoted commas, escaped quotes,
and multiline fields. V3 requires the supplied 13 column names and order:

```text
term_en, vocabulary_type, primary_meaning_ko, part_of_speech, subject,
definition_en, explanation_ko, learning_priority, priority_reason,
inclusion_recommendation, collector, source_title, notes
```

`term_en` and `primary_meaning_ko` are required. Blank optional enum values use
defaults for new entries, but do not reset existing metadata on reimport.
Invalid enums and non-13-cell data rows are reported before import. Incorrect
v3 headers reject the whole file. Legacy aliases/no-header CSV remain supported.
New/repeated imports merge distinct meanings, subjects,
sources, and related terms by normalized English term. Unknown fields are retained
as hidden metadata. Explicit classifications/priorities/recommendations are
updated without replacing bookmarks, images, or review history. Invalid rows are
identified before confirmation. AI drafts are
never automatically verified, and merging draft meanings invalidates a verified
entry's status.

## Preserved Functionality

Photo upload/capture, bookmarks, collections, renaming, simple bidirectional
flashcards, per-entry review exclusion, daily goals, progress, recent views,
CSV import, local storage, settings, and optional learning guidance remain.
Malformed legacy image data now falls back to a placeholder. Existing collection
tiles now use a Material surface so their interactions render correctly.
Inclusion recommendations are not mapped to learner review exclusion. Existing
`exclude`-recommended entries remain searchable, bookmarkable, and reviewable.
No FSRS or advanced spaced repetition was added.

## Confirmed Deletion Update

- Collection deletion now cascades to its vocabulary, including shared entries.
  Unrelated vocabulary and other collection containers are preserved.
- Dictionary, Bookmarks, and Collections support selection, select-all/clear,
  individual checkbox toggles, cancel, and one confirmed bulk delete.
- Warnings show the entry count, sample words, affected collections, loss of
  bookmarks/review history, and that the operation has no in-app undo.
- Filtered-out entries are pruned from selection. Store writes are batched per
  deletion, and failed deletion writes restore the in-memory state and reload
  the preferences cache from persistent storage.
- Active flashcard queues skip deleted entries and continue with surviving ones.
- Existing-only CSV reimports now report successful collection linking instead
  of incorrectly claiming that no vocabulary was found.
- This affects only current local personal data. A future common read-only
  terminology catalog must remain separate from personal deletions and edits.

## Subject Management Update

- Fresh installations seed only Electrical Engineering and Semiconductor
  Engineering, always shown first with locks and protected at the storage API.
- Existing subjects and assignments survive upgrade. English-named fixed roots
  reuse their IDs; previous default subjects are not re-created after deletion.
- Subjects can be added with optional parents. Empty/path-separator names and
  sibling duplicates are rejected.
- Confirmed custom-subject deletion removes its subtree and category references,
  never the vocabulary, collection memberships, bookmarks, or learning history.
- Deleted subject filters reset safely. Failed additions/deletions restore the
  categories, assignments, and preferences cache.

## Verification

- `flutter analyze`: passed, no issues.
- `flutter test --concurrency=1`: 59 tests passed (37 store, 22 widget), including
  cascade, bulk, cancellation, rollback, filtered selection, and live
  flashcard-queue regression coverage, fixed-subject protection, custom-subject
  creation/deletion, upgrade preservation, and subject-save failure recovery.
- `flutter build web --release`: succeeded.
- `git diff --check`: passed.
- Playwright with Microsoft Edge: actual 13-column CSV selection, preview/import,
  priority filtering, definition/explanation detail, bookmarking, reload
  persistence, bulk-selection cancellation/deletion, filtered selection,
  shared-collection cascade cancellation/deletion, single-delete cancellation,
  simulated browser quota-failure recovery, and desktop/mobile screenshots.
  Subject checks cover fixed-root locks, name validation, root/nested creation,
  subtree deletion and cancellation, retained vocabulary/bookmarks, stale-filter
  reset, reload persistence, and quota-failure rollback for additions/deletions.
  No page errors or failed local asset responses were observed.
- Viewports checked: 1280x900, 390x844, and 360x780 in the browser;
  360x780 in widget tests.
- Final Dart source/test files were hash-compared with the validated source copy.

The Windows helper completed analysis, tests, and a release build in a fresh
ASCII-path copy. The preview is served at `http://127.0.0.1:5189/` from the verified
web build. Browser smoke-test data used an isolated test browser context.

## Known Limitations

Android builds were not executed because the Android SDK is unavailable. iOS
builds/device camera testing require macOS/Xcode and physical devices. The web
build succeeds with an existing warning about a missing CupertinoIcons font;
Apple-platform navigation icons need checking before an iOS release.

Storage remains device/browser-local SharedPreferences without synchronization
or transactional database indexing. Formulas are not rendered or edited;
their historical values remain stored but hidden. Vocabulary types and
priorities are editorial metadata, not
automatic content validation. Legacy duplicate records remain separate when
merging could lose review history. Example terminology is illustrative and
unverified and does not contain invented source references.

## Recommended Next Steps

1. Review vocabulary definitions, classifications, priorities, and real sources.
2. Add export/restore and a content-review queue.
3. Move large datasets to SQLite/IndexedDB with indexed search.
4. Complete Android/iOS device, camera/gallery, and navigation-font validation.
5. Consider formulas/LaTeX, detailed concepts, FSRS, and recognition only in
   separate later development, keeping this release focused on vocabulary.
