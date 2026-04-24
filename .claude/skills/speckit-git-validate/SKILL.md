---
name: speckit-git-validate
description: Validate current branch follows feature branch naming conventions
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: git:commands/speckit.git.validate.md
---

# Validate Feature Branch

Validate that the current Git branch follows the expected feature branch naming conventions.

## Prerequisites

- Check if Git is available by running `git rev-parse --is-inside-work-tree 2>/dev/null`
- If Git is not available, output a warning and skip validation:
  ```text
  [specify] Warning: Git repository not detected; skipped branch validation
  ```

## Validation Rules

Get the current branch name:

```bash
git rev-parse --abbrev-ref HEAD
```

The branch name must match one of these patterns:

1. **Trello (project mandate)**: `^v[0-9]+/(feat|fix|chore|refactor|docs|test|perf|build|ci)/[A-Z]+-[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$` (e.g., `v1/feat/STAFF-0003-create-employee-cqrs-commands`). This is the convention required by `task.md` for this repo.
2. **Sequential (legacy)**: `^[0-9]{3,}-` (e.g., `001-feature-name`, `042-fix-bug`, `1000-big-feature`)
3. **Timestamp (legacy)**: `^[0-9]{8}-[0-9]{6}-` (e.g., `20260319-143022-feature-name`)

## Execution

If on a feature branch (matches any pattern):
- Output: `✓ On feature branch: <branch-name>`
- Check if the corresponding spec directory exists under `specs/`:
  - For Trello branches, extract the ticket segment (`<PROJECTCODE>-<TASK_NUMBER>`, e.g. `STAFF-0003`) and look for `specs/<prefix>-*`
  - For sequential branches, look for `specs/<prefix>-*` where prefix matches the numeric portion
  - For timestamp branches, look for `specs/<prefix>-*` where prefix matches the `YYYYMMDD-HHMMSS` portion
- If spec directory exists: `✓ Spec directory found: <path>`
- If spec directory missing: `⚠ No spec directory found for prefix <prefix>`

If NOT on a feature branch:
- Output: `✗ Not on a feature branch. Current branch: <branch-name>`
- Output: `Feature branches should be named like: v1/feat/STAFF-0003-feature-name (project mandate), 001-feature-name, or 20260319-143022-feature-name`

## Graceful Degradation

If Git is not installed or the directory is not a Git repository:
- Check the `SPECIFY_FEATURE` environment variable as a fallback
- If set, validate that value against the naming patterns
- If not set, skip validation with a warning