# Repository guidance

This is the canonical instruction file for this repository. Claude Code loads it through
`CLAUDE.md`.

## Start here

- Inspect branch, upstream divergence, status, and diff before editing.
- Preserve pre-existing changes and keep unrelated work out of the patch.
- Use the repository's existing runtime, package manager, framework, and deployment model.
- Do not refactor an existing project into the preferred new-project stack unless explicitly requested.
- Verify current documentation before changing version-dependent dependencies or hosting behavior.

## Project

This shell utility batch archives or unarchives GitHub repositories.

It is a Bash workflow using GitHub CLI, with optional fzf.

## Project rules

- Repository archive state is destructive operational scope. Resolve exact targets before applying changes.
- Keep dry-run and interactive review behavior working.
- Check `gh auth status` before GitHub operations.
- Read back every archive or unarchive mutation.
- Avoid dependencies that would break the one-line installation path.

## Commands

- `bash -n gh-batch-archive.sh`: syntax validation
- `shellcheck gh-batch-archive.sh`: lint when ShellCheck is available
- Exercise dry-run mode before any live GitHub mutation

## Verification

Run the relevant checks and exercise the affected workflow, endpoint, or generated artifact.
State clearly when authenticated, database, deployment, or live verification was not possible.

## Maintaining instructions

Update `AGENTS.md` when verified, durable repository behavior changes. Keep it concise and
move detailed explanations into `docs/`. Keep `CLAUDE.md` as the compatibility import
unless Claude-specific guidance is genuinely required.
