## Active: release AI priority criteria1.0.15+16 — 2026-11-12
User explicitly authorized commit/deploy. Worktree C:/Users/Public/Recall-ai-priority-release, codex/ai-priority-release from main281cde4. Copy explicit tested UI/test/provenance/docs only; increment version. Root88 unrelated staged files untouched.
Prior implementation PASS analyze/206 tests/web/1100-390-320 real UI/storage. No implementation changes since verification, only version/docs. Next: seed public1.0.14 upgrade profile, commit/PR checks, merge, Pages/permanent APK, public UI/upgrade and signature/download verification. Android device NOT TESTED.

## Completed locally: AI priority naming and recovered criteria — 2026-11-12
User requested AI 판단 학습 우선순위 and criteria recovered from past prompts, without inventing missing rules.
Found original Downloads/Recall_Master_Guidelines_v3.0.txt sections5/7 and matching historical attachment8af3e290 in Codex 리뷰 요청 코드 검토; related ChatGPT/Codex older turns inspected. Detailed source/hash/excerpts and limits in docs/development/AI_PRIORITY_CRITERIA.md.
Implemented heading/axis/semantics rename, current-grade v3.0 criteria, separate stored card reason, full criteria/source/limits dialog. Reader personal cards retain 내 학습 우선순위; missing reasons remain missing. No invented score/weights/thresholds, no AI calls or reclassification.
Unconfirmed: actual per-card executed prompt/version/model and review completion; not proof that all834 current grades comply with v3.0. Explicitly disclosed in dialog.
Changed: lib/corpus/study_evidence.dart, test/study_evidence_test.dart, tool/study_evidence_smoke.cjs, criteria provenance doc and development records. No dependencies, data/schema/IDs/rank changes.
PASS flutter analyze, all206 tests, release web build, real Edge1100/390/320 criteria/source-toggle/unchanged-storage checks. Mobile and criteria screenshots visually inspected. Source model/store unchanged except pre-existing worktree line endings; vocabulary/corpus bytes unchanged.
Evidence build/ai-priority-{analyze,tests,web,browser}.log and build/study-evidence/*.png/result.json. Existing Cupertino font warning remains; build succeeds.
Local preview http://127.0.0.1:5220/ now shows new label. Dictionary -> term detail -> scroll to AI 판단 학습 우선순위 -> 판단 기준.
NOT TESTED Android physical device. No commit/push/deploy requested in this follow-up; public1.0.14 remains prior release. Root88 unrelated staged files untouched.
Next only when requested: commit/deploy this coherent change using explicit files from clean origin/main worktree. No unfinished local implementation/verification.

## Completed release1.0.14+15 — 2026-11-12
User-authorized GitHub commit/web/permanent APK deployment COMPLETE.
Feature commit ac4e348243876e18a58b8845ef4bfcf28c278569; PR14 merged281cde430cded91f9e12202504d0ed3908e3fe8e.
PASS Windows206 Flutter tests, analyze, release web build; startup8. PASS PR CI43155416805, Pages43155732038, permanent APK43155742071.
PASS public dictionary graph/source toggles/criteria at1100/390/320, screenshots inspected; corpus filtering/sorting and PDF lookup/save/source/reload regressions.
PASS actual same-profile1.0.13→1.0.14 exact five-key preservation: dictionary/bookmark/review/focus, Reader term+occurrence, page bookmark and progress; managed PDF reopens at page3.
PASS local apksigner/aapt: same production package io.github.peter7004.recall, permanent certificate bc3842b9f7fd111587d9d337e434bd89406cf8b92a9bae114ad288692ae39977, versionCode15/name1.0.14.
PASS APK/public web834-term vocabulary/corpus/provenance payload equals merged source. No storage/key/schema/ranking/data changes.
APK78470993 bytes; SHA2567b2dbd95b1e8ef6f3b31005243f170c68b111f4e482479cce98b4c6f4c19926e. Full unauthenticated latest-link download verified. Previous1.0.13 assets unchanged; preserved earlier manual attached.
Web https://peter7004.github.io/Recall2/ ; release https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.14
UI location: Dictionary -> term detail -> scroll to 학습 우선순위 판단. Local5220 serves1.0.14; current served JavaScript matched latest build, fresh browser displayed graph. Cause in user's previously open tab remains unconfirmed. Do not clear user storage.
Evidence C:/Users/Public/Recall-study-evidence-release/build/release-1.0.14/{verification.json,upgrade-result.json,local-signature.txt,local-package-info.txt}; build/study-evidence and corpus-real-smoke in same worktree.
NOT TESTED physical Android install/update (adb empty) and user's actual browser profile. Web/build checks do not prove Android device behavior.
Source worktree codex/study-evidence-release clean and pushed. Root88 unrelated staged files untouched. Final post-deploy records local for next handoff.
No unfinished release step. Next: user confirmation of detail graph and physical Android update when available. Historical entries below are not pending.

## Completed locally: dictionary study-decision visualization — 2026-11-12
User wants AI priority and corpus observation combined as evidence for choosing
what to study. Dictionary detail now has StudyEvidence: categorical priority Y,
selected source DF/N X, source tabs, exact DF/TF, priority reason and method dialog.
The source tabs are view-only; no aggregate score, ranking or storage changes.
Personal priority is labeled separately; other cards use AI/stored priority because
per-field AI-vs-human edit provenance is not stored. Explanation discloses this.
Zero/pending/missing-data/missing-denominator are distinguished; unknown data draws
no point. Pending observations excluded. Counts, source assets, IDs and records unchanged.
Files: lib/main.dart, lib/corpus/study_evidence.dart,
test/study_evidence_test.dart, test/widget_test.dart,
tool/study_evidence_smoke.cjs, tool/corpus_real_smoke.cjs and development records.
PASS all206 Flutter tests, analyze, release web build. Existing Cupertino font
warning persists. PASS real browser1100/390/320 widths, source toggles, criteria
and exact unchanged Recall storage; corpus filter/sort/PDF lookup/save/source/reload.
Screenshots in build/study-evidence visually inspected (desktop and320px).
Initial FAIL: opaque container/ExpansionTile Material assertion and large-text axis
overflow fixed. Criteria changed to explicit accessible dialog button. Old test
expecting priority reason hidden updated for this request; management fields hidden.
Final logs build/study-decision-{tests,analyze,web,browser,corpus-browser}.log.
Preview http://127.0.0.1:5220/ (server PID4160, hidden). Dictionary -> term detail.
NOT TESTED Android physical device. No new AI, dependencies, data migration or API.
Root staged88 unrelated files untouched. No commit/push/merge/deploy requested for
this UI task; public web/APK still1.0.13. Next when requested: commit and deploy.
Older release entries below are history, not pending work.

## Completed release1.0.13+14 — 2026-11-12
User-authorized GitHub upload/web/permanent APK deployment COMPLETE.
Fix d285589; release0f2025f; PR13 merged19e570a533252304a3b2e29dea8aeca3267cc8b8.
PASS PR CI43050086480, Pages43050507536, permanent APK43050531058.
PASS203 Flutter tests/analyze/web and startup8; public circuit PDF source-return,
search panel, zoom and page mode screenshots checked after deployment.
PASS actual same-profile1.0.12→1.0.13: all five Recall stored values exactly preserved,
including dictionary/bookmark/review/focus, PDF term+occurrence, page bookmark and
reading progress; managed PDF reopens at page3. No keys/schemas/assets migrated.
PASS local apksigner/aapt: unchanged production package io.github.peter7004.recall,
permanent certificate bc3842b9f7fd111587d9d337e434bd89406cf8b92a9bae114ad288692ae39977,
versionCode14/name1.0.13. Exact834 vocabulary/corpus/provenance payload verified.
APK78470953 bytes, SHA256 c147312c227e7e505c75fd4174db8e8b10ace74bb789d97119dee0d7202f8c56.
PASS unauthenticated latest APK full-download checksum; previous1.0.12 assets unchanged.
Release https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.13
Web https://peter7004.github.io/Recall2/ ; local5220 preview updated to1.0.13.
Evidence: C:/Users/Public/Recall-highlight-fix/build/release-1.0.13/verification.json,
upgrade-result.json, local-signature.txt, local-package-info.txt; root build/highlight-public.
Root staged88 unrelated files untouched. Source worktree branch codex/reader-highlight-alignment
is clean and pushed; final post-deployment evidence is recorded here locally for next handoff.
NOT TESTED: physical Android install/update (adb empty), user's actual browser profile,
and all995 textbook pages. Do not infer these from build or isolated-profile success.
No unfinished deployment step. Next when available: user-profile/physical-device confirmation.
Older entries below are history, not active release work.

## Completed locally: source-return highlight geometry — 2026-11-12
User reports PC web PDF learning-source return offsets throughout circuit textbook.
Confirmed regression: text came from the loaded PdfPage while highlight normalization
used placeholder dimensions/rotation. Resolve one loaded page for both operations;
include page identity in the hover cache key so replacement pages invalidate geometry.
Files: lib/reader/pdf_term_hover.dart, lib/reader/pdf_reader_page.dart,
test/pdf_term_adapter_test.dart and development records. No storage/schema changes.
FAIL before fix: new progressive-page regression (201 existing tests passed).
PASS after fix: all203 Flutter tests, flutter analyze, release web build.
PASS real Edge browser: existing learning smoke (save/duplicate/source/independent
PDF/reload/deletion persistence), circuit PDF995 pages /24.3MB page344 source return,
search panel open/close, zoom and paged-mode screenshots visually checked.
The circuit PDF cover561.53x757.69 differs from body576.68x736.68; no fixed offset used.
NOT TESTED: user's exact saved browser state, all995 pages, Android physical device.
Initial browser harness retry timed out locating the search toggle with a tooltip;
using the explicit search-close control passed. No remaining test failures.
Web build retains existing Cupertino font warning; analyze has no issues.
Evidence (ignored): build/highlight-test-before.log, highlight-test-after.log,
highlight-analyze.log, highlight-web.log, highlight-learning-after.log,
highlight-real-after-final.log and highlight-alignment/*.png. Textbook not committed.
Isolated branch codex/reader-highlight-alignment at C:/Users/Public/Recall-highlight-fix.
Next: review commit; public web/APK have NOT been updated by this task. Local5220
preview contains the fix. Recheck user's existing browser state when deployed.
Root staged88 unrelated files untouched. No push, merge or deployment performed.

## Completed release1.0.12+13 — 2026-11-12
User-authorized commit/web/permanent APK update complete. PR12/8b6ffe4 merged
567270df2faa8b71bf9127cfa54736b813374547. CI43042651851 and Pages43043054362 PASS;
permanent signed APK43043073226 PASS. Changes: recommendation source DF/N rings,
DF/TF values and context-filter/pending-excluded copy with explicit method limits.
PASS Windows201/analyze/web, public daily graph/queue/focus/320-390-1200 browser,
actual same-profile1.0.11→1.0.12 exact Recall storage/focus/bookmark/review/PDF/page3.
PASS apksigner/aapt: same package io.github.peter7004.recall and permanent cert,
code13/name1.0.12; exact834 vocabulary/corpus payload; unauthenticated APK download.
APK SHA256:8dcbb37fea452b5d60f868cdd3612a6ec0fd0e29a3ba269b869dc505641d8e83
Previous1.0.11 assets unchanged. No corpus/ranking/user/Reader storage changes.
Release: https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.12
Evidence/helper: C:/Users/Public/Recall-release-112/build/release-1.0.12.
Worktree: C:/Users/Public/Recall-release-112; branch codex/corpus-coverage-112.
Root staged88 unrelated files untouched. Local5220 preview1.0.12 remains available.
Android physical update NOT TESTED: adb devices empty. Full expert semantic review
NOT TESTED. No unfinished release step. Next when available: physical-device update
and Reader validation; do not infer those passed from web/APK checks.
Older checkpoints below are history, not pending release actions.

## Completed locally: recommendation coverage graphs — 2026-11-11
User requested numeric/circular textbook-vs-abstract recommendation evidence and
clarification of provisional wording. Suggested term now shows independent DF/N
rings, source DF and TF, selected-focus border/label. Responsive stacked mobile /
side-by-side desktop; compact ring/count rows. No totals -> no invented percentage.
Visible provisional wording replaced with context-filter/pending-excluded labels;
method dialog retains automatic classification/no full human review, source overlap,
abstract-vs-fulltext limits and percentage definition. Metadata and statistics unchanged.
Files: lib/ui/recall_dashboard.dart, lib/corpus/corpus_widgets.dart,
test/corpus_test.dart, tool/daily_corpus_smoke.cjs, tool/corpus_real_smoke.cjs,
docs/development/HANDOFF.md, READER_ROADMAP.md, JOURNAL.md and
DAILY_CORPUS_RECOMMENDATIONS.md. No dependency/store/ranking/schema changes.
PASS Windows201 tests (including zero/pending/no-total/2x-text cases), analyze, web.
PASS real browser daily source/queue/DF-TF/rings/320-390-1200 widths/storage reload;
existing real-corpus dictionary/PDF lookup/save/source/reload checks. Visual screenshots
inspected. Initial desktop test timed out because pointer180px was outside centered
scroll area; fixed test to use viewport center, rerun PASS. No product failure remains.
Logs build/corpus-coverage-*-final.log; screenshots build/daily-corpus-smoke.
Local preview http://127.0.0.1:5220/ serves changes (refresh). Public web/APK remain
release1.0.11 without these new UI changes; no commit/push/deploy in this task.
Root staged88 untouched. Android device NOT TESTED; full expert semantic review NOT TESTED.
No unfinished implementation step. Next if requested: commit/release via isolated
worktree/PR, preserving unrelated root staged files and existing signing identity.
Original review workbook and full-evidence ZIP available under
C:/Users/유태현/Documents/Codex/2026-10-12/x20/outputs/recall-recount-20261111.

## Completed daily corpus recommendations1.0.11+12 — 2026-11-11
Home supports textbook/abstract learning focus and uses the same ranked candidates
for the suggested word and default daily study. Source preference is separate;
vocabulary, Reader, bookmarks, IDs and review data remain unchanged.
PR11 head1c71bf8 merged40b08902baa6684c9f0a369eab06f7e085267472.
PASS Windows198 tests/analyze/web/startup8, Linux CI43033524596, public browser
DF/TF ranking/default queue/mobile320–390/preference and review persistence.
PASS Pages43033916563 and actual same-profile1.0.10→1.0.11 exact localStorage,
bookmark/review/managedPDF/page3 upgrade. Existing UI320–1280 regression PASS.
PASS signed APK43033941811, local apksigner/aapt: unchanged package/permanent cert,
code12/name1.0.11, exact834-term/corpus assets. Public unauthenticated download and
previous1.0.10 assets unchanged verified. APK SHA256:
35fcfb664d76da6bbdfe75daff1c03a0de15d493d8e34b12b9619d6411535e11.
Release: https://github.com/Peter7004/Recall-APK-Private/releases/tag/v1.0.11
Evidence/helpers: C:/Users/Public/Recall-release-111/build/release-1.0.11.
Local5220 preview1.0.11 remains available. Root staged88 untouched.
No unfinished release step. Next: Galaxy S25 Ultra update/device validation when
available; Android physical device and expert semantic review NOT TESTED.
See DAILY_CORPUS_RECOMMENDATIONS.md. Older checkpoints below are history.

## Completed real corpus release1.0.10+11 — 2026-11-11
PR9/d4619715cb7e29a05c28cb40c8bbeb834a3e311e; CI43014655807,
Pages43015022187 and signed APK43015043216 PASS. Actual834-term data from22PDF files
and639abstracts now public; provisional accepted counts and pending meanings separated.
PASS public actual corpus/filter/PDF/source/reload; real same-profile1.0.9→1.0.10
exact stored-data/managedPDF/page3 upgrade; APK permanent cert/package/code11/payload
and unauthenticated public download. Prior v1.0.9 assets unchanged.
APK SHA2567b8f7541701b398e173a70135b7acd1efc00e80348308814ad41389e4605636d.
See RELEASE_1.0.10.md and REAL_CORPUS_INTEGRATION.md. Root staged88 preserved.
No functional release blocker remains. Next: Android device validation and human
semantic/source-overlap review when available. Neither has been performed.
Historical checkpoints below are not unfinished release actions.

## Real corpus preparation history — 2026-11-11
User reports missing 22-PDF/639-abstract frequencies. Found other chat01a13054 and
x20/work/recall-recount-20261111:834 matched terms, 661-source manifest, occurrence ledger.
Released1.0.9 CSV was header-only. Now exported latest accepted provisional counts with separate
pending counts, corpus sizes and explicit source/method note. Optional preference had no reply;
proceeding with stated recommended latest-recount default.
Files to change: assets/corpus CSV/metadata/README; corpus model/loader/widgets; main
controls; validation/export tool and tests; pubspec asset registration; development records.
Preserve13-column vocabulary and all user/Reader stores. PASS ledger86182/661 hashes/834 matches,
categories225/326/37/246; Windows191 tests/analyze/web, CLI recount validation and mobile UI
storage regression. Test fixture tap corrected to scroll first; browser assertions being updated
for merged Flutter accessibility labels. No product runtime failure identified.
PASS real corpus browser: actual Voltage/Frequency counts and pending, method dialog,
225 common filter, abstract DF sorting,320/390 widths, PDF stats/save/source/reload.
PASS absent/mocked corpus fallback and startup8. Browser selectors/focus waits corrected
for Flutter semantics; normal detail visits intentionally change recentViews only.
PR9 runtime31f704f merged d4619715cb7e29a05c28cb40c8bbeb834a3e311e after CI43014655807 PASS.
PASS Pages43015022187 and public834 corpus/metadata byte-for-byte against merged source.
PASS public real corpus smoke and same-profile1.0.9→1.0.10: exact Recall localStorage,
bookmark/review, managed PDF/page3. Signed APK43015043216 still building.
Next download and verify permanent signed APK1.0.10+11, payload/hash/cert, publish and
verify public release. Helpers/baseline in C:/Users/Public/Recall-release-110/build.
Root staged88 untouched; no Android device test.
Do not claim Android device test. Existing staged88 untouched.
## Completed 1.0.9+10 release — 2026-11-11
User-authorized commit/deployment complete. PR7 merged8868ae4a03009bc1c53a771683794d0197086bbb.
PASS PR42989014089:188 Flutter/analyze/startup8; Pages42989311938;
permanent signed APK42989316358; public UI/mobile/Reader/corpus regressions.
Same isolated 1.0.8 browser profile upgraded to1.0.9: exact Recall localStorage,
bookmarks/review, managed PDF and page3 retained after cache-bypassing reload.
APK io.github.peter7004.recall code10/name1.0.9, unchanged permanent certificate;
SHA256473d50776f868edef9d494aa6d641ddd918857b19824b6db07322f4931b3a7e8.
Public latest download re-verified without auth. Existing v1.0.8 assets unchanged.
See RELEASE_1.0.9.md. Android device upgrade NOT TESTED (adb empty).
No storage/model/catalog/Android settings or dependency changes. Root index88 preserved.
Next: device validation when Galaxy S25 Ultra is connected; no release blocker remains.
Historical checkpoints below are not active tasks.
## Release preparation checkpoint 1.0.9+10 — 2026-11-11
User authorized GitHub commit, web deployment and permanent-signed APK update.
Worktree: C:/Users/Public/Recall-release-109; branch codex/five-tab-release-109.
Files: main/dashboard, widget/browser tests, Windows scripts, version/README and records.
Preserve io.github.peter7004.recall and the existing distribution certificate;
versionCode increases9→10. No vocabulary/persistence/model/Android config changes.
Baseline Windows188 tests/PDFium/analyze/debug APK and browser regressions PASS.
Next: PR checks, merge pinned commit, Pages/signed APK workflows, compare certificate,
package, payload and existing-browser upgrade data before publishing release assets.
Android physical-device upgrade NOT TESTED. Root staged88 must remain unchanged.
## Completed local Windows repair / five-tab UI — 2026-11-11

User request complete locally. Home / dictionary / Reader / study / records now
share five bottom tabs; PDF page and current study card survive tab switches.
Removed repetitive coaching copy. See WINDOWS_LOCAL_DEVELOPMENT.md for files,
commands, physical SDK paths, root causes and validation limits.

PASS on this Windows PC: final native suite188, actual PDFium extraction/render1,
Flutter analyze (no issues), local debug APK. PASS real browser UI widths320–1280,
mobile Reader menu/tab persistence, corpus and full Reader learning/source tests.
No dependency/version/storage changes. Tool runner stages exact current source into
owned physical C:/Users/Public/Recall-windows-build; process environment restored.
APK build/windows/Recall-debug.apk: com.example.recall, Android Debug signer,
1.0.8+9, SHA256 79326286502a90369cdfbc7a086f32f412fcd4b1cd3fa77c8b4cbd6ede2cee33.
It is a separate test app, not a production update. Android device and Windows
desktop app build NOT TESTED. No new commit/push/publication; staged88 untouched.

Next concrete action: device validation on Galaxy S25 Ultra when connected.
If publication is requested, prepare a new version and permanent-signed release;
do not replace the existing production APK with this debug artifact.
Historical checkpoints below describe earlier states, not current blockers.

# Completed UI/corpus/mobile release — 2026-11-11

1.0.8+9 is publicly released. PR5 merged fdbb427. Full Linux187 tests and
startup8 PASS; Pages42982937540 and permanent signed APK42982945172 PASS.
Public UI/corpus/mobile/full Reader browser regressions and APK re-download SHA256
PASS. Previous certificate and v1.0.7 assets preserved; root staged88 unchanged.
APK SHA256 ca1cd106c0badf40b1ed428b0013c36fd09e9b6c9610e6aba1eb4650f747443a.
See RELEASE_1.0.8.md for exact URLs, hashes, scope and PASS/FAIL/NOT TESTED.
Primary agent synced green widget_test.dart/pubspec.yaml to root; merge these final docs and
README version-only edits while preserving root collaboration content.
Next product validation: actual Android device and real corpus statistics when supplied.
At the time of that release, local Windows Gradle/native repair was unresolved;
the completed local repair above supersedes that environment status.
Earlier checkpoints below are chronological evidence, not current release blockers.

## Release execution checkpoint — 2026-11-11

PR #5 merged: fdbb427eded7329a61b6db1105f28de7949001f7 (1.0.8+9).
PASS: Linux PR 42982621625, job 130396336799: 187 Flutter tests, analyze,
8 Node startup tests. Original run 42982129380: 180 PASS / 7 FAIL; fixed only
widget-test scroll/visibility; subsequent full run has no missed-tap warnings.
Active: Pages 42982937540; permanent signed APK 42982945172 pinned to merge SHA;
separate test APK 42982937536 must not be published as production.
Next: wait for builds; verify APK signer/package/version/assets/hash, publish v1.0.8,
verify public web/downloads and run UI/corpus/Reader browser smokes on production.
Primary agent synced green test/widget_test.dart and pubspec.yaml back to root; no root
edits performed by this release coordinator. Root staged88 remain intact.
PASS: Pages42982937540; public version1.0.8+9 and exact CSV asset hashes; public
UI-v2 smoke. Primary agent independently reports public mobile Reader smoke PASS.
Coordinator public UI-v2, mobile-menu, corpus fixture integration and full Reader
learning/source/deletion/corruption/image-PDF smokes all PASS (no JS errors).
Corpus fixture was injected only into isolated test browser; production asset unchanged.
NOT TESTED: Android device installation/gestures; signed artifact/public deployment pending.
Local Windows environment repair remains unresolved: parallel environment agent reports minimal independent
Gradle projects fail too while standalone Kotlin works; MSVC discovery still in progress.
Do not claim local Windows fixed. Primary agent will sync verified widget_test/pubspec/docs to root.

## Active mobile Reader / release — 2026-11-11

## Active release coordination — 2026-11-11 (1.0.8+9)

User authorized commit/push/PR/merge/web and permanently signed APK deployment.
Reader ready signal received: mobile <700 circular FAB / scrollable action sheet;
desktop unchanged. Exact relevant root files copied to isolated worktree
C:/Users/Public/Recall-ui-release-20261111 on codex/ui-release-20261111,
based on origin/main c86f8570ba8071e46f7f68e642f17ea736293144.
Root staged 88 entries are protected by build/release-coordination/root-index-baseline.bin.
Sync hashes and explicit paths: build/release-coordination/sync-manifest.json.
Changed scope: UI/main/store read-only corpus, Reader menu, corpus assets/models,
widget/corpus/browser tests, validator, PR workflow, version and release docs.
PR #5 https://github.com/Peter7004/Recall2/pull/5 opened at bccc4df.
First Linux PR run 42982129380 FAIL: 180 PASS / 7 FAIL, all widget navigation.
Failures: management links clipped/covered; lazy low-priority row not built; bulk
selection tapped a clipped row. Test-only fix in test/widget_test.dart centers
targets, completes layout and asserts hit testing before actions. Branding/reveal
tests already PASS. Root test file not overwritten; copy back after green CI.
Next: rerun full Linux PR CI,
fix navigation regressions here, report changed test files for root sync; merge only
when checks pass, verify Pages and signed APK from exact released source.
PASS: exact initial file sync, staged-entry count 88, local Node startup tests 8/8, release-worktree full flutter analyze.
User-reported PASS: final Reader analyze/web build; Edge menu import, page 3, search,
desktop toolbar restoration. Final mobile smoke script resynced after resize-wait fix.
FAIL (environment): dart run invokes pdfium native hook without Windows C++ compiler.
PASS: documented direct dart --packages invocation validates fixture (exit 0) and
production header-only corpus (expected exit 3); Linux PR analyze PASS, tests running.
NOT TESTED: full Linux tests/build, signed APK and Android device.
Existing Windows C++/Gradle limitations recorded below are historical, not new results.
Corpus CSV contains only its header; actual TF/DF data is unavailable. No fake data.
Release helpers under build contain stale version constants; do not run their publish,
configure or verify modes unchanged. Reuse existing key only; never replace secrets.

User authorized environment repair, mobile circular Reader menu, commit/push/PR/web/permanent-signed APK release. Main edits reader page; parallel agents inspect toolchain and prepare clean release worktree. Preserve original staged88. Next implement adaptive menu then browser validate and CI.

# Reader handoff — UI checkpoint

## Active mobile Reader / release — 2026-11-11
User authorized environment repair, mobile circular Reader menu, commit/push/PR/web/permanent-signed APK release. Main edits reader page; parallel agents inspect toolchain and prepare clean release worktree. Preserve original staged88. Adaptive menu implemented in reader page: width<700 circle FAB and scrollable bottom sheet, page bar retained, wide toolbar unchanged. PASS final analyze/web and real mobile browser import/page3/search/resize; UI v2 smoke re-run PASS. Clean release worktree preparing1.0.8+9 CI. Native environment diagnosis ongoing.

## Active UI redesign — 2026-11-11
User supplied Temp README/main.dart/index.html/screenshots. Integrated visual reference into existing Flutter app, NOT the standalone 24-word demo. Local branch codex/pdf-personal-vocabulary at c86f857; no UI/corpus commit, push, merge or deployment.
Implemented teal/navy theme, R header, Home/Dictionary/Study/Records navigation, real-data home/recommendation/record views, white dictionary and flashcards, settings goal chips/backup cards. Collections, subject management, bookmarks and Reader remain accessible. Dictionary controls and lazy result list scroll together on short screens. Existing study scope selection is retained before the redesigned flashcard session.
Changes: lib/main.dart; new lib/ui/recall_dashboard.dart; test/widget_test.dart, branding_test.dart, bundled_vocabulary_test.dart; tool/corpus_smoke.cjs navigation; new tool/ui_v2_smoke.cjs. No changes to data models, store, Reader or dependencies during UI work (hash comparison with 162736 checkpoint PASS). Prior corpus work remains local.
PASS: final full Flutter analyze and release web build in ASCII worktree C:/Users/Public/Recall-catalog-preserve-20261109; real Edge UI smoke at 320/430/640/1280 widths; search/bookmark/review/reload; production no-corpus and mocked corpus filter/detail/PDF source smoke; full existing Reader learning/source/delete/reload smoke. Source files copied exactly to ASCII worktree. Preview http://127.0.0.1:5220/; screenshots original workspace build/ui-v2-smoke.
FAIL (environment): root Korean-path analyze LSP JSON framing; ASCII analyze passed. Flutter test (including Chrome target) blocked by pdfium_dart Windows C++ compiler absence. Android debug build failed during existing Kotlin settings.gradle.kts evaluation (run/file/require/plugins unresolved), before app compilation; matches earlier Android audit failure. Do not claim Android build/device PASS.
NOT TESTED: native widget test execution, physical Android device, signed APK packaging. Existing 88 unrelated staged copy files preserved. No new APK released.
Intentional differences: preserve actual goal (default24), actual categories and 834 dictionary; progress counts reviews, not unique daily terms. No invented 8/8/4 breakdown, seven-day totals, incorrect-answer totals, or destructive demo reset. Existing storage lacks full daily history, so records explain why no 7-day graph. No automatic reset when changing goal.
Next: user visual review; native toolchain repair/CI authorization before APK validation. See UI_V2_VERIFICATION.md. Current local UI is implemented and browser verified, not published.

## Active corpus integration — 2026-11-11
Prerequisite completed: 834 unique terms verified in remote/public CSV. PR #4 merged
c86f857; signed CI 42975726693 and Pages 42976067818 PASS. v1.0.7+8 published;
APK SHA256 ee14600965f9eb9909c8886115df0159b8e7e7c285de28f72b9c62cc364f4182,
same prior certificate and 834-term payload verified; public download HTTP 200.
Corpus changes are now in the original workspace on codex/pdf-personal-vocabulary,
locally fast-forwarded to c86f857. Validation used the ASCII worktree
C:/Users/Public/Recall-catalog-preserve-20261109. NO corpus commit/push/merge/deploy.
Unrelated staged entries were byte-for-byte preserved; README collaboration additions
were three-way merged. Original incomplete draft was backed up under build/corpus-sync-20261111-161547
before copying verified corpus files. Actual TF/DF file absent.
Implemented read-only catalog/validator, hidden-by-default filters/detail/PDF integration.
PASS: 64 isolated tests, full analyze/release web build, fixture-injected browser corpus
filter/detail/PDF save and existing full Reader learning/source smoke. Native tests blocked
by Windows C++ toolchain. Actual full TF/DF and Android corpus behavior NOT TESTED.
See CORPUS_INTEGRATION.md. Next: user review of LOCAL changes; obtain actual stats and
run --research-check before corpus publication. No corpus commit/push/merge/deploy.

## Catalog release safety — 2026-11-09
Remote main 0248264 contains 834 unique terms and web 1.0.6 deployment succeeded.
Signed 1.0.6 build 42560029792 succeeded but has not been published as a release.
Found v1-to-v2 seeding deletes existing bundled cards and their attached history.
Release fix removes destructive replacement, preserving IDs, user edits, bookmarks,
reviews, collections and Reader references. Keep unmatched legacy cards as well.
Version 1.0.7+8 prepared. PASS: 43 isolated tests, full analyze and release web build.
Upstream regression reproduced (lost edited meaning/bookmark/review); fixed source passes.
2026-11-11 resume: same source verified; next commit/PR and signed CI, then authorized release.
PR #4 created. First signed CI 42975305117 failed only the old test that explicitly
expected legacy-card deletion. Updated that test for the requested preservation policy;
new regression passed in CI. Next rerun complete signed workflow, then merge/release.
Corpus implementation remains local/uncommitted in original workspace; no corpus stats fabricated.

## Unhighlighted text check — 2026-11-08
User asks whether plain PDF text can be drag-selected and saved. Existing selection
callback and manual action do not require dictionary matches. No duplicate app feature
needed. Added RECALL_TEST_UNHIGHLIGHTED mode to personal_vocabulary_smoke.cjs.
PASS against current local release: no dictionary match, plain text drag, exact prefill,
save original selected text/manual meaning/note/source, same page and reload persistence.
Harness fixes: restarted stopped local server; focus Flutter semantics input before
reading inputValue (unfocused semantics node returns empty). No app source changed.
UI follow-up committed as 973a036; no public deployment performed.

## Active UI follow-up — 2026-11-08
User authorized UI improvements and commit. Scope: personal_vocabulary_dialog.dart,
focused widget/browser tests and development records. Add field spacing/borders, required vs
optional sections, readable source block, contextual duplicate confirmation and
scrollable keyboard-safe layout. Storage unchanged. 8 focused tests PASS, including
390x844 viewport with 300px simulated keyboard inset. Full analyze, release web build,
browser drag/save/reload PASS. Desktop/mobile screenshots inspected. Browser smoke
uses named fields and real key input because Flutter editable semantics rebuild on
focus; fixed test harness failures, confirmed saved explanation_ko. Ready for task-only
commit; no push/deploy. Android device/actual mobile keyboard NOT TESTED.

## Active task — manual PDF vocabulary (2026-11-08)
User authorized implementation and commit. Inspecting existing pdfrx selection,
RecallCard meanings/examples/sources and SharedPreferences v3. Reuse existing
dictionary edit/delete and flashcards. Add a manual selection dialog, conservative
offset-based context extraction and separate personal identities; no AI or DB migration.
Expected files: vocabulary.dart, recall_store.dart, main.dart, reader/pdf_reader_page.dart,
new personal vocabulary dialog/context helper, focused tests and development records.
Implemented: manual dialog, conservative selected-offset context, distinct personal
entries, existing dictionary editing/deletion and flashcard back content reused.
PASS: 49 isolated tests (same app source and locked compatible dependencies),
full analyze, release web build and actual browser PDF-selection/save/reload smoke.
FAIL (environment): full native test invocation stops at pdfium C++ build hook;
Windows C++ compiler is not configured. Android device/build NOT TESTED; adb has no devices.
Final same-source release web build and existing full Reader learning/source browser
regression PASS. Verified source hashes match the tested full-project copy.
Ready for task-only commit on codex/pdf-personal-vocabulary; next validation requires
Android hardware and a configured native C++ toolchain. No push/merge/deploy authorized.
Unrelated staged copies and collaboration changes remain untouched.
See PERSONAL_VOCABULARY_VERIFICATION.md for scope, commands and limitations.

Updated: 2026-11-04 (Asia/Seoul). Branch main.
Latest runtime: 3afdd04efdd3522ed8c848bed0787a5941a85a12 (v1.0.5+6).
Earlier milestones: P0 4887541, P1 1c2f113, P2/hover 826ed80, P3 feecf59,
P3a 97443f1. History is preserved in JOURNAL.md.

## Latest completed module — S3 tap and click lookup

Use the viewer's confirmed single tap and existing matched PDF rectangles to
select the exact dictionary occurrence. Reuse the selection popup and source
saving. Keep scroll, zoom, native selection and PDF link handling.
Implemented in pdf_reader_page.dart and pdf_term_hover.dart. PASS: analyze, release web build, browser click and emulated touch, exact source save, zoom, touch drag, and existing selection and source consistency smoke. The smoke selectors were corrected after early harness failures. Android device verification NOT TESTED. Reported deployed app still required drag because S3 was local. Release v1.0.5+6 includes S3. Pages 41802098782 and public mouse/touch smoke PASS. Signed build 41802098954 PASS. v1.0.5 published with package io.github.peter7004.recall, version code 6, and the v1.0.4 certificate. Next product module: Reader backup and restore.


## Latest completed module — S2 definition and source consistency

Authorized continuation 2026-11-03. Scope: learning list shows all current primary
meaning/definition/explanation fields together when dictionary entry exists; otherwise
show explicitly labeled saved snapshot. Preserve stored snapshots and dictionary keys.
Share managed-file availability checks between Reader list and card sources; recheck
before source navigation. Missing bytes/damaged metadata disable links; no full-PDF
validation/performance claim. No backup feature in this module.
Expected files: reader_learning_view.dart, pdf_reader_page.dart,
reader_card_sources_page.dart, library/document_repository.dart, reader_learning_store.dart; focused tests/docs.
Implementation complete; 29 isolated tests PASS, analyze and release web build PASS.
Existing full PDF learning/source regression PASS. Focused browser consistency smoke PASS: persisted dictionary edits/deletion and
missing-byte navigation race; no JS errors, raw Reader snapshot unchanged.
Initial test harness failures fixed: ASCII TEMP/TMP needed for Windows tester; grouped
source scenarios avoid cross-test fake-clock/common-queue interference; use IconButton
predicate rather than RawTooltip cast. Windows full native hook still lacks C++.
Final source: retry repository creation after failure; one-pass source document IDs.
29 tests re-PASS. Final analyze/release web build PASS (session 61410).
Final same-source consistency browser smoke PASS (including snapshot fallback).
Source committed/pushed b3da5c2a32173b899d526504fb76f1431fbe6b7d.
S2 CI PASS: web 41658314912 and Android test APK 41658314699. Public consistency smoke PASS.
Production APK requested 2026-11-04. Source e752e34 bumped version to 1.0.4+5. Signed build 41791432029 PASS and v1.0.4 published. APK package io.github.peter7004.recall, versionCode 5 and previous certificate match verified. Public latest download and release SHA-256 verified. Android on-device install NOT TESTED.
After S2, first unfinished product module is Reader export/restore (not started).
See CONSISTENCY_VERIFICATION.md.
For isolated tests set TEMP/TMP=C:/Users/Public/Recall-reader-test-temp. Native
Android device testing needs connected hardware. Preserve unrelated staged copies.

## Previous completed module — S1 storage collision safety (2026-11-03)

User authorized prioritization of proposed/screenshot learning features and starting
highest priority. P0 is preventing Reader record loss/resurrection across independently
loaded stores and browser tabs. Keep existing storage keys/data; no server/dependency.
Plan: per-process serialized mutation, reload latest snapshot inside exclusive guard,
Web Locks for cooperative cross-tab writers, explicit refusal when safe locking is
unavailable, and refresh other instances/tabs. Preserve deletion semantics: no blind
merging stale snapshots. Validate two-store concurrent saves, deletion resurrection,
write failure, corrupt snapshot, real two-tab browser scenarios and existing workflows.
Priority review complete in LEARNING_FEATURE_PRIORITIES.md.
Guard/coordinator + read-latest mutation and cross-instance refresh implemented.
Existing key/schema retained. Web unsupported-lock writes explicitly refused.
Reader auto-bookmark link also refuses stale dictionary snapshots, avoiding v3
clobbering during simultaneous Reader saves. This does NOT serialize every legacy
manual dictionary edit across tabs; that remains outside this scoped repair.
45 isolated regression tests PASS; analyze/release web build PASS. Real two-tab test PASS for held-lock serialized
writes, suppression-resistant deletion handling and unsupported lock refusal.
An already open learning list also receives storage-event removal/addition live.
Final two-tab + existing learning/source-return flow PASS on localhost:5206.
See STORAGE_SAFETY_VERIFICATION.md for guarantees and limits.
Source committed/pushed as bd3ee40ae63f4a3916ac64e48dfea90fa14093f4.
Exact-SHA CI: web 41653024597 SUCCESS (full tests/analyze/build/deploy).
Android 41653024525 SUCCESS: full tests/analyze/build and test APK artifact.
Temporary test signer only; permanent production download APK unchanged.
Public two-tab safety smoke PASS: held lock, live removal/addition, stale-tab
delete preservation, retry bookmark and unsupported-lock refusal. No JS errors.
adb devices reports no device; native device behavior NOT TESTED.
Next concrete action: inspect ReaderLearningView definition resolution and
ReaderCardSourcesPage document availability checks, then implement P1 definition/
snapshot and source-availability consistency as a separate module. Not started.
No unfinished S1 source changes remain. Reload ALL old app tabs before using the new protocol.
Old code ignoring the lock cannot be coordinated.
Historical P4/P5 verification below is preserved separately from S1 results.

## Current state — COMPLETE through P4/P5

- Damaged native/web PDF metadata is isolated and reported. Healthy documents
  remain usable; damaged records are never automatically deleted or overwritten.
  Reimport of a damaged record is explicitly refused.
- Preview star refresh retains scroll and mounted thumbnails.
- Highlight state distinguishes loading, successful zero matches, unavailable
  text/geometry and errors with explicit retry. Copy restrictions are respected.
- Known-term saving separates a card snapshot from exact occurrences: document
  hash/title, page, actual text/context, char offsets and normalized fragment
  rectangles. Duplicate saves deduplicate; different same-text locations remain.
- Saved fragments remain green after reopening. Reader lists, dictionary detail
  and flashcard pages link to source geometry. One-step source return history is
  current-session-only; saved terms/occurrences and document progress persist.
- PDF deletion retains learning/context and disables missing links. Original card
  deletion still leaves a readable saved snapshot. English definitions are shown;
  highlight/default view settings persist. Existing-word bookmarking is idempotent
  with failure rollback. Reader/dictionary writes are separate; partial failure is reported.

## Final verification

Exact runtime 55937793390517cfef02f410a8b65260e45e6633:
- PASS: web 41595274901 full Linux tests/analyze/build/deployment.
- PASS: Android test APK 41595274985 full Linux tests/analyze/build/artifact.
  Temporary test signer; NOT the permanently signed production download APK.
- PASS: public peter7004.github.io/Recall2 learning/library smokes: selection/save,
  duplicate prevention, SECOND same-page occurrence, cross-document source/back,
  restart/settings, dictionary card source route, damaged IDB isolation/reimport
  refusal, image-only guidance, deletion-retained records/disabled links and
  injected write rollback. No JS runtime errors.
- PASS: local 38 isolated tests, analyze/web build. PDF adapter tests passed in
  both full Linux jobs. Existing navigation/search and preview/bookmark smokes PASS.
- PASS: public/local hover pixels 0/1137/0/1137/0; selection with always-on works.
  Dictionary checks 16/startup 8 PASS. CSV unchanged:
  2a3a7a6ea639ecc7a9ac600e7c6666f5bf4a159e90c90aa72457e4802209ec0e.
- NOT TESTED: Android device/backup (ADB had no devices), large/rotated/encrypted/
  copy-restricted native PDFs and Windows native build. Prior narrow-web semantics
  pointer issue remains unresolved/unverified.
- NOT TESTED: browser-only Flutter corruption unit (loading interrupted). Actual
  application IndexedDB injection passed separately.
- Existing Windows full Flutter tests fail BEFORE cases: missing C++ compiler for
  pdfium_dart. Linux tests/builds do not prove device behavior.
See P4_P5_VERIFICATION.md for scope and limitations.

## Historical P4/P5 follow-up

1. Inspect git status, actual code and latest complete checkpoint hashes. Do not
   redo P4/P5. No deployment or build remains pending.
2. P6: Galaxy S25 Ultra verification; obtain representative large/scanned/encrypted/
   restricted PDFs, profile import/render/search/highlights/memory. No real
   500-page/100MB result exists. Virtual widget tests are not PDF performance tests.
   Keep Android 10+ target; do not change minSdk without compatibility checks.
3. Subsequent product work: manual unknown-term creation, Reader export/restore,
   native managed-file path opening. These are NOT implemented. Existing vocabulary
   backup does NOT include Reader records. No AI/OCR/accounts/cloud/server/FSRS.

## Data and environment

- Preserve recall.data.v3 dictionary/bookmarks/flashcards. Only explicit user save
  activates the corresponding word bookmark. No dictionary migration.
- Reader keys: recall.reader.progress.v1.<hash>, recall.reader.pageBookmarks.v1.<hash>,
  recall.reader.learning.v1, recall.reader.settings.v1.
- Managed PDFs: Android noBackupFilesDir/recall_reader; web IndexedDB
  recall.reader.library.v1. Original PDFs are never modified.
- SDK C:/Users/Public/Recall-flutter-sdk (3.47.6); cache
  C:/Users/Public/Recall-reader-pub-cache; Android SDK
  C:/Users/Public/BeforeAfterAndroidToolchain/sdk. No Windows platform scaffold.
- Current full audit C:/Users/Public/Recall-reader-safety-20261103; isolated no-pdfrx
  harness C:/Users/Public/Recall-p3-unit-20261103 is not a whole-app build.
- Local localhost:5206/Recall2 server was stopped. Recreate from audit/serve;
  Recall2 junction points to audit/build/web. Exclude Korean copy files when syncing.
- Scripts: reader_learning_smoke.cjs, reader_library_smoke.cjs,
  reader_navigation_smoke.cjs, reader_document_navigator_smoke.cjs,
  check_reader_hover.py. External Playwright via RECALL_PLAYWRIGHT_MODULE;
  RECALL_READER_TEST_URL selects local/public URL. Run picker smokes sequentially;
  appbar import is more reliable for semantics automation.
- Fixtures: original two 5-page manuals under output/pdf (never modify). Synthetic
  5-page source-a/source-b, 1-page image-only via make_reader_learning_fixture.py;
  outline/plain via make_reader_outline_fixture.py. Generated PDFs stay ignored.

## Safety and recovery

Unrelated staged Korean copies and untracked automation/output/tmp are user work.
Never commit/reset/clean them. Commit only explicit owned paths.
Update HANDOFF/JOURNAL and run tool/checkpoint-reader.ps1 -Note 'implemented / next'
before long verification and after meaningful fixes.
Snapshots: ignored build/reader-checkpoints/<timestamp>/source and manifest.json.
Choose the latest COMPLETE manifest and verify every hash; ignore partial/invalid
snapshots. Compare base commit and diffs; never overwrite newer files blindly.
No keys/PDF/user content in handoffs. Checkpoints do not stage/restore automatically.
Quota reset does not auto-resume development.

Resume: **“개발 인계 기록을 읽고 마지막 미완료 작업부터 계속해 줘.”**
