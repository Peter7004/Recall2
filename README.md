# Recall v3.0

A dictionary-first Flutter application for English vocabulary and electrical
engineering terminology, with optional photo-assisted flashcard review.

## Features

- Dictionary, Subjects, Bookmarks, Flashcards, and Collections navigation.
- Reference-logo startup screen with a single brief reveal and matching header branding.
- Two vocabulary types: `general_technical` and `technical`.
- Learning priorities `high`, `medium`, and `low`, with visible labels and filters
  in the dictionary and bookmarks.
- Local English/Korean search, partial matching, type and subject filters.
- Korean meanings, English definitions (`definition_en`), concise Korean
  explanations (`explanation_ko`), and existing examples/translations.
- Custom subjects with optional deletion-protection pins, existing nested
  categories, and terms shared across
  subjects and collections without copying the dictionary entry.
- Persistent bookmarks with search/filtering and recently viewed terminology.
- Entry editing, sources, and related-entry navigation.
- Confirmed permanent word deletion, collection deletion with its vocabulary,
  and checkbox-based bulk deletion in Dictionary, Bookmarks, and Collections.
- Simple forward/reverse flashcards from the dictionary, bookmarks, subjects,
  or collections. Existing photos, review exclusion, daily goals, and progress remain.
- CSV validation and preview, safe merging, UTF-8 Korean, quoted commas/newlines,
  and preservation of legacy unrecognized columns as hidden metadata.

Inclusion recommendations (`include`, `review`, `exclude`), collectors, editorial
notes, priority reasons, and legacy verification fields are management metadata.
They are persisted but not displayed in learner lists, details, editors, search,
or flashcards. An `exclude` recommendation does not delete or hide an entry and
does not change the learner's independent review-exclusion setting.

No formula/LaTeX rendering, detailed technical concept panels, FSRS, handwriting,
or formula recognition is introduced. Existing engineering metadata is retained
for later development without active learner controls.

## Branding and Startup

`web/branding/recall-logo.png` is the unchanged user-provided artwork. The header
displays the book and original `Recall` wordmark in separate viewport crops;
no substitute font is used and other application text retains its existing font.
The startup screen displays the original stacked logo on white.

Web startup shows the logo before Flutter initializes, with one 700 ms fade and
8 px upward reveal after the image is available. Reduced-motion settings disable
this animation. The HTML logo stays visible for at least 700 ms after its image
loads and is removed once Flutter's first frame is ready. Slower initialization
does not add another delay. Local-data loading uses the same logo without
replaying the animation on web. Script/engine failures cancel pending removal
and show a retry action that reloads the page without clearing saved vocabulary.
Existing local-data errors retain their original recovery screen.

Native Flutter loading uses the same artwork, 700 ms minimum display, and finite
reveal, respecting system motion preferences. Data-load errors appear immediately.
Platform launch screens, launcher icons, and the browser favicon are unchanged.

## Local Storage and Migration

The application continues using `shared_preferences`. `recall.data.v3` stores
one global `entries` list and collections with `entryIds`, plus categories,
bookmarks, recent views, daily goals, and review progress.

On first load, previous `recall.data.v1` or `recall.data.v2` saves are migrated
into v3. Both old values remain untouched as backups. IDs, photos, bookmark/exclusion flags, review
history, category assignments, and original card fields are retained. Conflicting
legacy IDs are repaired. Existing separate legacy records are retained to avoid
losing individual review history. New/imported terms are merged by normalized
English term, preserving distinct meanings, subjects, and sources.

Deleting a collection permanently deletes its vocabulary from the current local
dictionary, including links from other collections, bookmarks, recent views,
and per-entry review history. Unrelated entries and other collection containers
remain. Every learner deletion requires confirmation describing the number of
words and affected collections. Canceling the dialog makes no data changes.

Bulk selection operates only on the displayed search/filter results. Changing
filters removes hidden words from the selection. Selected-word deletion keeps
the collection itself, even when it becomes empty. Active flashcard queues skip
deleted entries, and failed deletion saves restore the in-memory vocabulary
and refresh the preferences cache from storage.
Unchecking a collection-membership checkbox remains a relationship-only action;
it is not the permanent-delete command. Migration never deletes words on its own.
Unreadable saves show an error and are not silently replaced by empty data.

Legacy `general` maps to `general_technical`; its original explicit value is
retained in `extra_fields.legacy_vocabulary_type`. Missing priorities default to
`medium`, and missing inclusion recommendations default to `review`.
Legacy types without an explicit classification default to `general_technical`;
entries with existing formulas/symbols/units are provisionally treated as technical.
Legacy definition/explanation values remain available through the new field names
without automatic translation or fabricated content. Subject assignment alone
does not make a word technical.

## Subject Management

The Subjects screen supports adding top-level subjects or selecting an optional
parent for a subsubject. Empty names, names containing the `/` path separator,
and case-insensitive sibling duplicates are rejected.

Fresh installations have no mandatory subjects. A one-time upgrade removes the
previous mandatory roots `전기공학` (Electrical Engineering) and `반도체공학`
(Semiconductor Engineering), including their English aliases. Their direct
children become independent subjects with unchanged IDs, descendants, and pins.
Only the retired roots' assignments are cleared; vocabulary, collections,
bookmarks, and learning history remain intact. `subjectSettingsVersion` records
the upgrade, so subjects later created/imported with those names are retained.

Each subject has a pin/unpin icon. A pinned subject cannot be deleted, and a
parent cannot be deleted while any descendant is pinned. Both the delete control
and storage API enforce this protection. Unpinning restores confirmed deletion;
pinning does not prevent editing vocabulary or removing an unpinned child.
Pins persist across restarts. Existing subjects without a pin field are unpinned.

Deleting a custom subject asks for confirmation and includes its descendants.
The warning shows subsubjects and the affected vocabulary count. Unlike deleting
a collection, subject deletion only clears those subject assignments: entries,
collections, bookmarks, recent views, and review history remain. Other subject
assignments remain unchanged. A deleted dictionary subject filter returns to
all subjects. Failed subject saves restore the categories and assignments and
refresh the preferences cache, including failed pin/unpin operations.

## CSV Import

Legacy files support `front,meaning,example`, `word,meaning,example_sentence`,
Korean headers, or three columns without a header. The previous extended format
with `term_ko,term_en,definition,category,subcategory` also remains supported.

Recall v3.0 uses exactly these 13 columns in this order:

```csv
term_en,vocabulary_type,primary_meaning_ko,part_of_speech,subject,definition_en,explanation_ko,learning_priority,priority_reason,inclusion_recommendation,collector,source_title,notes
maintain,general_technical,유지하다,verb,,Keep something in its existing state.,기존 상태를 유지하다,medium,,review,,,
```

`term_en` and `primary_meaning_ko` are required. Every row must contain 13 cells,
including empty optional cells. Blank `vocabulary_type` defaults to
`general_technical`; blank `learning_priority` defaults to `medium`; blank
`inclusion_recommendation` defaults to `review` for new entries. Nonblank enum
values must be valid. `general` is accepted only in the legacy importer.

Files using a v3-specific header (`definition_en`, `explanation_ko`,
`learning_priority`, `priority_reason`, or `inclusion_recommendation`) must match
the fixed schema. Missing, reordered, duplicate, or extra headers reject import.
Legacy header aliases and no-header files remain supported separately.

Distinct meaning content is preserved; identical meanings are not added twice.
Explicit imported types/priorities/recommendations update existing entries, while
blank values do not reset their metadata. Bookmarks, photos, review history, and
old meanings are preserved. Collector and notes values are combined without
duplicating identical lines. Use `;` or `|` for multiple subjects or parts of
speech and `/` for nested subject paths. English subject names map to existing
Korean subjects.

`source_title` supplies a source label; other historical source metadata remains
preserved by legacy import and storage. The app does not independently verify
definitions or generate citations.

Invalid records are reported in the preview and skipped only after confirmation.
Malformed quoting or ambiguous duplicate headers reject the import. Unknown
legacy columns are named in the preview and stored in hidden `extra_fields`.
Re-importing a term links its existing entry into the new collection.

See [examples/vocabulary.csv](examples/vocabulary.csv) for a small illustrative
dataset covering both types and all three priorities. It is illustrative,
unverified content and is not automatically installed.

## Run and Verify

```sh
flutter pub get
flutter analyze
flutter test
node --test test/web/startup_test.cjs
flutter run -d chrome
```

On Windows, Flutter's test engine can fail when its generated temporary files
use a non-ASCII path. OneDrive can also block cleanup of generated build files.
The verification helper creates a fresh source copy and uses ASCII SDK/cache
links and temporary paths outside OneDrive:

```powershell
.\tool\validate.ps1 -BuildWeb
```

This runs analysis, all Flutter tests, and a release web build. Run the Node
startup tests separately using the command above. The source checkout is not
moved, and environment overrides are restored when the helper exits.

Fourteen existing Android source/resource copies with ` - 복사본` names were
preserved in the ignored `.recall-backups/android-source-copies/` directory,
outside Android compilation roots. Dart source copies are excluded from analysis.
Existing Git staging was not changed.

Android requires an installed Android SDK; iOS requires macOS/Xcode. GitHub
Actions still analyzes, tests, builds, and deploys the web app to GitHub Pages.

## Web Deployment

The published app is at https://peter7004.github.io/Recall2/.
Repository Settings > Pages > Build and deployment > Source must be **GitHub
Actions**, not **Deploy from a branch**. Branch publishing from the source root
builds the README with Jekyll and competes with the Flutter deployment.

`.github/workflows/deploy.yml` builds with `--base-href /Recall2/`, verifies the
Flutter HTML/bootstrap/JavaScript entry points, and uploads only `build/web`.
The repository source and documentation are not the Pages deployment artifact.
Push to `main` or manually run this workflow to publish a new web build.
If an old information page is cached, use a hard refresh; do not clear local
site data, because it contains the vocabulary, bookmarks, and review history.

## Limitations and Next Steps

For the intended terminology dictionary, keep the editor-curated common catalog
separate from personal collections, custom entries, bookmarks, and review state.
A bundled read-only catalog is a sensible first release; later a catalog database
can deliver editorial updates, and an authenticated user database can synchronize
personal state. Using a database does not imply allowing users to edit or delete
the shared catalog. Personal deletion must never mutate the shared source.

The current app does not yet ship that common catalog: imported/created terms
are local personal data. Collected terminology must be provided as reviewed data
before it can be packaged as the app's base dictionary. No backend, account
system, or unrequested database migration was introduced in this change.

Storage is local to the device/browser, with no cloud sync or multiuser editing.
Classifications, priorities, and definitions require editorial review.
SharedPreferences is appropriate
for modest datasets; SQLite/IndexedDB indexing is the next step for large libraries.
An export/restore workflow and database indexing are future improvements, not
part of this focused vocabulary release. Camera/gallery integration still needs testing
on physical Android/iOS devices.
