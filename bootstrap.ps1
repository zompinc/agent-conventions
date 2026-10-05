# Bootstrap Zomp agent-conventions on Windows.
#
# Symlinks $HOME\AGENTS.md to this repo's home\AGENTS.md so all AI coding agents
# (Claude Code, Codex, Cursor, Aider) pick it up via directory walk-up, and
# symlinks each skill under skills\ into $HOME\.claude\skills\ so stack- and
# activity-specific conventions load on demand instead of costing context in
# every session.
#
# Also enables this repo's own git hooks, which keep client names and machine
# paths out of a public repository.
#
# Everything of value stays in the repo; this machine holds only links.
# Falls back to copying if symlink creation fails (e.g. Developer Mode off
# and not running as admin).
#
# Idempotent: safe to re-run.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$Source = Join-Path $RepoRoot 'home\AGENTS.md'
$Target = Join-Path $HOME 'AGENTS.md'

if (-not (Test-Path $Source)) {
    Write-Error "Source not found: $Source"
    exit 1
}

function Set-Link {
    param([string]$LinkPath, [string]$TargetPath, [bool]$IsDirectory)

    if (Test-Path $LinkPath) {
        $existing = Get-Item $LinkPath -Force
        if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $TargetPath) {
            Write-Host "Already linked: $LinkPath -> $TargetPath"
            return
        }
        Write-Host "Removing existing $LinkPath"
        Remove-Item $LinkPath -Force -Recurse
    }

    # Try symlink first. Requires Developer Mode or admin.
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
        Write-Host "Linked: $LinkPath -> $TargetPath"
    } catch {
        Write-Warning "Symlink failed ($($_.Exception.Message))."
        Write-Warning "Falling back to copy. Re-run this script after 'git pull' to refresh."
        Write-Warning "To enable symlinks: Settings -> Privacy & Security -> For developers -> Developer Mode."
        if ($IsDirectory) {
            Copy-Item $TargetPath $LinkPath -Recurse -Force
        } else {
            Copy-Item $TargetPath $LinkPath -Force
        }
        Write-Host "Copied: $LinkPath"
    }
}

Set-Link -LinkPath $Target -TargetPath $Source -IsDirectory $false

# Link each skill directory individually rather than the skills\ folder itself,
# so skills from other sources in $HOME\.claude\skills are left alone.
$SkillsSource = Join-Path $RepoRoot 'skills'
$SkillsTarget = Join-Path $HOME '.claude\skills'

if (Test-Path $SkillsSource) {
    if (-not (Test-Path $SkillsTarget)) {
        New-Item -ItemType Directory -Path $SkillsTarget -Force | Out-Null
    }
    foreach ($skill in Get-ChildItem $SkillsSource -Directory) {
        Set-Link -LinkPath (Join-Path $SkillsTarget $skill.Name) -TargetPath $skill.FullName -IsDirectory $true
    }
}

# Hooks live in the repo so a clone gets them; git needs telling where.
if (Test-Path (Join-Path $RepoRoot '.githooks')) {
    git -C $RepoRoot config core.hooksPath .githooks
    Write-Host "Hooks enabled: core.hooksPath=.githooks"
}

Write-Host "Conventions update with: cd $RepoRoot; git pull"
