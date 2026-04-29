# Git Workflow

## Branch policy

Use small branches with a clear prefix and scope. For Codex-created branches, prefer the `codex/` prefix unless a human task prompt says otherwise.

Recommended setup branch:

- `setup/project-root`

Recommended future task branch pattern:

- `codex/<task-id>`

## Remote policy

Keep the fork and upstream distinct:

- `origin` should point to the project fork.
- `upstream` should point to the original toPSAil repository.

Do not pull upstream changes into a validation branch without a task that allows dependency or baseline movement.

## Commit policy

Keep commits scoped to one task:

- documentation/control setup,
- one case scaffold,
- one parameter transcription,
- one test tier,
- one validation report.

Do not combine solver changes, parameter changes, metrics, plotting, and threshold updates in one commit.

## Baseline policy

The unmodified toPSAil baseline should be preserved by tag or branch before model work begins.

Suggested tag:

- `baseline-topsail-unmodified`

## Dirty worktree policy

Before editing, inspect `git status --short`.

Do not revert user changes unless explicitly asked. If unrelated files are dirty, leave them alone and report that they were present.

## Large/generated files

Generated `.mat`, `.csv`, figure, and report outputs should not be committed unless a task explicitly asks for a small validation artifact. Large source PDFs may live locally under `sources/`, but `.gitignore` excludes PDFs by default.
