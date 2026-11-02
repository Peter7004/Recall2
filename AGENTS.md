# Recall development handoff

Before continuing Reader work, read `docs/development/HANDOFF.md` and
`docs/development/READER_ROADMAP.md`, then inspect git status and the actual code.
The handoff is a checkpoint, not proof that unverified work passed.

- Keep the active task, next concrete action, changed files, tests and blockers
  current in HANDOFF.md before starting a module and after each meaningful step.
- Append completed milestones to `docs/development/JOURNAL.md`.
- Run `tool/checkpoint-reader.ps1 -Note 'what is implemented / next action'`
  before lengthy verification and after a meaningful fix. It snapshots source
  into ignored build/reader-checkpoints without staging or restoring anything.
- Commit coherent, verified work using explicit file paths. The working tree
  contains unrelated staged Korean copy files; never commit/reset/clean them.
- Preserve vocabulary, bookmarks, flashcards and existing storage keys. Reader
  data must stay separate. No AI, OCR, accounts or server dependency in this phase.
- Record PASS, FAIL and NOT TESTED separately. Web tests and successful APK builds
  do not prove Android device behavior. Never claim quota-reset auto-resumption.
- If interrupted, inspect differences from the recorded commit and local snapshot,
  continue the first unfinished step, and do not blindly overwrite newer files.
  Choose the latest complete manifest with verified hashes; ignore partial
  snapshot folders that have no final manifest.json or fail verification.

User instructions take precedence. This file does not require extra approvals
for the already authorized roadmap or routine reversible implementation work.
