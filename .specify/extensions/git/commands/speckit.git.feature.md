---
description: "Create a feature branch named from the Trello card using the project branch convention"
---

# Create Feature Branch

Create and switch to a new git feature branch for the given specification. This command handles **branch creation only** — the spec directory and files are created by the core `/speckit.specify` workflow.

Branch names **MUST** follow the project convention:

```
<version>/<type>/<PROJECTCODE>-<task-number>-<kebab-case-description>
```

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Branch Segment Rules

`<version>`
- Must come from the Trello card when available (e.g. `v1`, `v2`, `v2.82.1`).
- If the card has no explicit version, default to `v1`.

`<type>` — pick exactly one:
- `feat` — new feature
- `fix` — bug fix
- `hotfix` — urgent production fix
- `chore` — tooling, setup, cleanup
- `docs` — documentation only
- `test` — tests only
- `refactor` — internal restructuring, no behavior change
- `perf` — performance improvement
- `ci` — CI/CD changes

Infer `<type>` from the Trello card labels/title/description (e.g. `Bug` label → `fix`). If ambiguous, ask the user.

`<PROJECTCODE>`
- From Trello when available (e.g. `STAFF`, `USERPRO`, `EMPLOYEE`).
- UPPERCASE, letters/digits only.
- If the Trello card key is already prefixed (e.g. card title starts with `STAFF-012:`), reuse that prefix.

`<task-number>`
- From Trello MCP (`mcp__trello__get_card`, `get_my_cards`, etc.).
- **Never invent it.** If no card is available, ask the user for the card ID/number before creating the branch.

`<kebab-case-description>`
- Short and specific, 2–5 words.
- lowercase, hyphen-separated, no spaces, no underscores.
- Derive from the Trello card title or the user's feature description.

### Examples

```text
v1/chore/STAFF-001-create-solution-structure
v1/feat/STAFF-002-create-employee-domain-model
v1/feat/STAFF-003-create-dapper-repository
v1/feat/STAFF-004-create-employee-api-endpoints
v1/feat/STAFF-005-create-react-employee-ui
v1/docs/STAFF-006-add-readme-and-run-instructions
v1/chore/STAFF-007-add-docker-compose
```

## Trello Lookup

Resolve the Trello card before building the name:

1. If the user input contains a Trello card URL, ID, or short link, resolve it with `mcp__trello__get_card`.
2. Otherwise, call `mcp__trello__get_my_cards` (or `mcp__trello__get_active_board_info` + `mcp__trello__get_cards_by_list_id`) and pick the card that matches the feature description. Confirm with the user if more than one plausible match exists.
3. Extract: `version`, `type` (inferred), `PROJECTCODE`, `task-number`, and a concise description.
4. If any required field cannot be resolved, **stop and ask the user** — do not guess `PROJECTCODE` or `task-number`.

## Environment Variable Override

Once all segments are resolved, assemble the final branch name and pass it through the script via the `GIT_BRANCH_NAME` environment variable. The script uses the exact value verbatim, bypassing all prefix/suffix generation; `--short-name`, `--number`, and `--timestamp` are ignored.

If the user explicitly supplies `GIT_BRANCH_NAME` themselves, honor it as-is (assume they know the convention).

## Prerequisites

- Verify Git is available by running `git rev-parse --is-inside-work-tree 2>/dev/null`.
- If Git is not available, warn the user and skip branch creation.

## Execution

Run the appropriate script based on your platform, passing the constructed branch name via `GIT_BRANCH_NAME`:

- **Bash**:
  `GIT_BRANCH_NAME="<version>/<type>/<PROJECTCODE>-<task-number>-<kebab-case-description>" .specify/extensions/git/scripts/bash/create-new-feature.sh --json "<feature description>"`
- **PowerShell**:
  `$env:GIT_BRANCH_NAME="<version>/<type>/<PROJECTCODE>-<task-number>-<kebab-case-description>"; .specify/extensions/git/scripts/powershell/create-new-feature.ps1 -Json "<feature description>"`

**IMPORTANT**:
- Always include the JSON flag (`--json` / `-Json`) so output can be parsed reliably.
- Do NOT pass `--short-name`, `--number`, or `--timestamp` — `GIT_BRANCH_NAME` supersedes them.
- Run this script only once per feature.
- The JSON output contains `BRANCH_NAME` and `FEATURE_NUM` (when `GIT_BRANCH_NAME` has no numeric prefix, `FEATURE_NUM` equals the full branch name — this is expected).

## Graceful Degradation

If Git is not installed or the current directory is not a Git repository:
- Branch creation is skipped with a warning: `[specify] Warning: Git repository not detected; skipped branch creation`.
- The script still outputs `BRANCH_NAME` and `FEATURE_NUM` so the caller can reference them.

## Output

The script outputs JSON with:
- `BRANCH_NAME`: the exact branch created (e.g. `v1/feat/STAFF-002-create-employee-domain-model`).
- `FEATURE_NUM`: the numeric/timestamp prefix used; with the Trello convention this typically equals the full branch name since there is no leading `NNN-`/timestamp prefix.
