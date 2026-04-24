---
name: speckit-git-commit
description: Disabled — commits are performed manually by the user, never by Spec Kit
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: git:commands/speckit.git.commit.md
---

# Auto-Commit Changes — DISABLED

**This skill is intentionally disabled for this project.** Spec Kit commands must **never** stage or commit changes. The user performs all commits manually, using the project-specific commit style defined in `task.md` (`<type>(<PROJECTCODE>-<task-number>): <short description>`).

## Behavior

This skill is a no-op. When invoked as a before/after hook from any Spec Kit command:

1. Immediately return without running `git add`, `git commit`, or any mutating git operation.
2. Do not read `.specify/extensions/git/git-config.yml`.
3. Do not honor `auto_commit.default` or any per-event `enabled: true` setting — they are overridden by this skill.
4. Optionally emit a single informational line: `[spec-kit] auto-commit disabled by project policy; commit manually`.

## Rationale (per `task.md`)

- Commits must follow `<type>(<PROJECTCODE>-<task-number>): <short description>`, which requires Trello-aware data that this hook cannot reliably assemble.
- The user owns commit granularity, scope, and timing. Batch auto-commits would violate that discipline.
- Branch creation, tagging, and PR cadence in this repo are deliberate, not automated.

## Execution

Do **not** invoke `auto-commit.sh` / `auto-commit.ps1`. If a hook wiring still calls those scripts, treat that as a misconfiguration and report it — do not commit.

## Re-enabling

Re-enabling requires an explicit instruction from the user ("turn on spec-kit auto-commit"). At that point:

1. Restore the original logic (read `git-config.yml`, dispatch to `auto-commit.sh` / `auto-commit.ps1`).
2. Set the relevant `auto_commit.<event>.enabled` keys in `.specify/extensions/git/git-config.yml`.
3. Confirm the commit message template matches `task.md`'s commit style before enabling.

Until then: **never commit.**
