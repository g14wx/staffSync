#!/usr/bin/env pwsh
# Git-specific common functions for the git extension.
# Extracted from scripts/powershell/common.ps1 — contains only git-specific
# branch validation and detection logic.

function Test-HasGit {
    param([string]$RepoRoot = (Get-Location))
    try {
        if (-not (Test-Path (Join-Path $RepoRoot '.git'))) { return $false }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
        git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# Trello-style project mandate: v<n>/<type>/<CODE>-<NNNN>-<slug>
# Mirrors the regex documented in .claude/skills/speckit-git-feature/SKILL.md.
$script:SpecKitTrelloBranchRegex = '^v[0-9]+/(feat|fix|chore|refactor|docs|test|perf|build|ci)/[A-Z]+-[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$'

function Get-SpecKitEffectiveBranchName {
    param([string]$Branch)
    if ($Branch -match '^([^/]+)/([^/]+)$') {
        return $Matches[2]
    }
    return $Branch
}

# Extract the spec prefix used to look up specs/<prefix>-* directories.
# Trello-style branches return the ticket segment (e.g. STAFF-0003);
# legacy sequential/timestamp branches return their numeric/timestamp prefix.
function Get-SpecKitBranchPrefix {
    param([string]$Branch)
    if ($Branch -match '^v[0-9]+/(?:feat|fix|chore|refactor|docs|test|perf|build|ci)/([A-Z]+-[0-9]{4})-') {
        return $Matches[1]
    }
    $effective = Get-SpecKitEffectiveBranchName $Branch
    if ($effective -match '^(\d{8}-\d{6})-') {
        return $Matches[1]
    }
    $hasMalformedTimestamp = ($effective -match '^[0-9]{7}-[0-9]{6}-') -or ($effective -match '^(?:\d{7}|\d{8})-\d{6}$')
    if (($effective -match '^([0-9]{3,})-') -and (-not $hasMalformedTimestamp)) {
        return $Matches[1]
    }
    return $null
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )

    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }

    $raw = $Branch

    # Trello-style first — project mandate per task.md
    if ($raw -match $script:SpecKitTrelloBranchRegex) {
        return $true
    }

    $Branch = Get-SpecKitEffectiveBranchName $raw

    # Accept sequential prefix (3+ digits) but exclude malformed timestamps
    # Malformed: 7-or-8 digit date + 6-digit time with no trailing slug (e.g. "2026031-143022" or "20260319-143022")
    $hasMalformedTimestamp = ($Branch -match '^[0-9]{7}-[0-9]{6}-') -or ($Branch -match '^(?:\d{7}|\d{8})-\d{6}$')
    $isSequential = ($Branch -match '^[0-9]{3,}-') -and (-not $hasMalformedTimestamp)
    if (-not $isSequential -and $Branch -notmatch '^\d{8}-\d{6}-') {
        [Console]::Error.WriteLine("ERROR: Not on a feature branch. Current branch: $raw")
        [Console]::Error.WriteLine("Feature branches should be named like: v1/feat/STAFF-0003-feature-name (project mandate), 001-feature-name, 1234-feature-name, or 20260319-143022-feature-name")
        return $false
    }
    return $true
}
