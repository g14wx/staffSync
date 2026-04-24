---
name: speckit-git-feature
description: Create a feature branch with sequential or timestamp numbering
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: git:commands/speckit.git.feature.md
---

# Create Feature Branch

Create and switch to a new git feature branch for the given specification. This command handles **branch creation only** — the spec directory and files are created by the core `/speckit.specify` workflow.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Mandatory Branch Naming (project rule)

Per `task.md` → "Branch Naming Context", every task branch **MUST** follow:

```text
<version>/<type>/<PROJECTCODE>-<task-number>-<kebab-case-description>
```

Example:

```text
v1/feat/STAFF-0003-create-employee-cqrs-commands
```

Components:

- `<version>`: semantic major, lowercase `v` + digit (e.g. `v1`). Default `v1` unless user/Trello specifies otherwise.
- `<type>`: conventional-commit type (`feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `build`, `ci`).
- `<PROJECTCODE>`: uppercase project code from Trello (default `STAFF` for this repo).
- `<task-number>`: 4-digit zero-padded Trello task number (e.g. `0003`).
- `<kebab-case-description>`: 2–5 meaningful words, lowercase, hyphen-separated, stop-words removed, acronyms preserved.

**Sequential/timestamp numbering, `--short-name`, and auto-generated prefixes are disabled for this project.** The branch is always constructed explicitly and passed via `GIT_BRANCH_NAME`.

## Trello-Aware Inputs (required)

Before building the branch name, resolve these values. Prefer Trello MCP as source of truth:

1. `PROJECTCODE` — from Trello board/card label or user input. Default `STAFF`.
2. `TASK_NUMBER` — from Trello card ID/number. Zero-pad to 4 digits.
3. `TYPE` — infer from feature description (`feat` for new capability, `fix` for bug, `chore` for scaffolding/config, etc.). When ambiguous, ask.
4. `VERSION` — default `v1`. Bump only when user/Trello explicitly targets a new major.
5. `DESCRIPTION_SLUG` — kebab-case summary of feature description (2–5 words).

If Trello MCP is unavailable and `PROJECTCODE` / `TASK_NUMBER` cannot be inferred safely, **ask the user** before creating the branch. Do not invent Trello data.

## Prerequisites

- Verify Git is available by running `git rev-parse --is-inside-work-tree 2>/dev/null`
- If Git is not available, warn the user and skip branch creation

## Execution

1. Resolve `VERSION`, `TYPE`, `PROJECTCODE`, `TASK_NUMBER`, `DESCRIPTION_SLUG` per rules above.
2. Compose the exact branch name:

   ```text
   <VERSION>/<TYPE>/<PROJECTCODE>-<TASK_NUMBER>-<DESCRIPTION_SLUG>
   ```

3. Export it as `GIT_BRANCH_NAME` and invoke the script. Do **not** pass `--short-name`, `--number`, or `--timestamp`.

- **Bash**:

  ```bash
  GIT_BRANCH_NAME="v1/feat/STAFF-0003-create-employee-cqrs-commands" \
    .specify/extensions/git/scripts/bash/create-new-feature.sh --json "<feature description>"
  ```

- **PowerShell**:

  ```powershell
  $env:GIT_BRANCH_NAME = "v1/feat/STAFF-0003-create-employee-cqrs-commands"
  .specify/extensions/git/scripts/powershell/create-new-feature.ps1 -Json "<feature description>"
  ```

**IMPORTANT**:
- `GIT_BRANCH_NAME` bypasses all prefix/suffix generation — the script uses the exact value.
- Always include the JSON flag (`--json` / `-Json`) so the output can be parsed reliably.
- Run this script only once per feature.
- JSON output contains `BRANCH_NAME` and `FEATURE_NUM`. For this naming scheme `FEATURE_NUM` equals the full branch name (no numeric prefix); downstream consumers must treat the Trello `TASK_NUMBER` as the authoritative feature identifier.

## Validation

After branch creation, assert the current branch matches the regex:

```text
^v[0-9]+/(feat|fix|chore|refactor|docs|test|perf|build|ci)/[A-Z]+-[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$
```

If it does not match, abort and report the mismatch — do not continue to spec generation.

## Graceful Degradation

If Git is not installed or the current directory is not a Git repository:
- Branch creation is skipped with a warning: `[specify] Warning: Git repository not detected; skipped branch creation`
- The script still outputs `BRANCH_NAME` and `FEATURE_NUM` so the caller can reference them

## Output

The script outputs JSON with:
- `BRANCH_NAME`: The branch name (e.g., `003-user-auth` or `20260319-143022-user-auth`)
- `FEATURE_NUM`: The numeric or timestamp prefix used