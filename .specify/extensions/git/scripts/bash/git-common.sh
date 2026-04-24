#!/usr/bin/env bash
# Git-specific common functions for the git extension.
# Extracted from scripts/bash/common.sh — contains only git-specific
# branch validation and detection logic.

# Check if we have git available at the repo root
has_git() {
    local repo_root="${1:-$(pwd)}"
    { [ -d "$repo_root/.git" ] || [ -f "$repo_root/.git" ]; } && \
        command -v git >/dev/null 2>&1 && \
        git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Trello-style project mandate: v<n>/<type>/<CODE>-<NNNN>-<slug>
# Mirrors the regex documented in .claude/skills/speckit-git-feature/SKILL.md.
SPEC_KIT_TRELLO_BRANCH_RE='^v[0-9]+/(feat|fix|chore|refactor|docs|test|perf|build|ci)/[A-Z]+-[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$'

# Strip a single optional path segment (e.g. gitflow "feat/004-name" -> "004-name").
# Only when the full name is exactly two slash-free segments; otherwise returns the raw name.
spec_kit_effective_branch_name() {
    local raw="$1"
    if [[ "$raw" =~ ^([^/]+)/([^/]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[2]}"
    else
        printf '%s\n' "$raw"
    fi
}

# Extract the spec prefix used to look up specs/<prefix>-* directories.
# Trello-style branches return the ticket segment (e.g. STAFF-0003);
# legacy sequential/timestamp branches return their numeric/timestamp prefix.
spec_kit_branch_prefix() {
    local raw="$1"
    if [[ "$raw" =~ ^v[0-9]+/(feat|fix|chore|refactor|docs|test|perf|build|ci)/([A-Z]+-[0-9]{4})- ]]; then
        printf '%s\n' "${BASH_REMATCH[2]}"
        return 0
    fi
    local branch
    branch=$(spec_kit_effective_branch_name "$raw")
    if [[ "$branch" =~ ^([0-9]{8}-[0-9]{6})- ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    if [[ "$branch" =~ ^([0-9]{3,})- ]] && [[ ! "$branch" =~ ^[0-9]{7}-[0-9]{6}- ]] && [[ ! "$branch" =~ ^[0-9]{7,8}-[0-9]{6}$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Validate that a branch name matches an expected feature branch pattern.
# Accepts: Trello-style (project mandate), legacy sequential (###-*), or legacy timestamp (YYYYMMDD-HHMMSS-*).
check_feature_branch() {
    local raw="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    # Trello-style first — project mandate per task.md
    if [[ "$raw" =~ $SPEC_KIT_TRELLO_BRANCH_RE ]]; then
        return 0
    fi

    local branch
    branch=$(spec_kit_effective_branch_name "$raw")

    # Accept sequential prefix (3+ digits) but exclude malformed timestamps
    # Malformed: 7-or-8 digit date + 6-digit time with no trailing slug (e.g. "2026031-143022" or "20260319-143022")
    local is_sequential=false
    if [[ "$branch" =~ ^[0-9]{3,}- ]] && [[ ! "$branch" =~ ^[0-9]{7}-[0-9]{6}- ]] && [[ ! "$branch" =~ ^[0-9]{7,8}-[0-9]{6}$ ]]; then
        is_sequential=true
    fi
    if [[ "$is_sequential" != "true" ]] && [[ ! "$branch" =~ ^[0-9]{8}-[0-9]{6}- ]]; then
        echo "ERROR: Not on a feature branch. Current branch: $raw" >&2
        echo "Feature branches should be named like: v1/feat/STAFF-0003-feature-name (project mandate), 001-feature-name, 1234-feature-name, or 20260319-143022-feature-name" >&2
        return 1
    fi

    return 0
}
