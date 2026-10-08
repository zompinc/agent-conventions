# Bootstrap Zomp agent-conventions on Windows.
#
# Everything under home\ mirrors your home directory: home\AGENTS.md becomes
# $HOME\AGENTS.md, home\.claude\skills\<name>\ becomes $HOME\.claude\skills\<name>\,
# and anything added there later lands in the matching place with no change to
# this script.
#
# Files are linked individually rather than whole directories, so linking
# .claude\skills never replaces a directory holding skills from other sources.
# New files appear on the next bootstrap run, which the updater does after
# every pull.
#
# Also enables this repo's git hooks and registers a daily update task.
#
# Everything of value stays in the repo; this machine holds only links.
# Falls back to copying if symlink creation fails (e.g. Developer Mode off
# and not running as admin).
#
# Idempotent: safe to re-run.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$HomeSource = Join-Path $RepoRoot 'home'

if (-not (Test-Path $HomeSource)) {
    Write-Error "Source not found: $HomeSource"
    exit 1
}

# Drop links that point into this repo but no longer resolve - a file renamed
# or moved upstream leaves one behind. This runs before linking, because a
# dangling directory link would break creating files beneath it.
function Remove-StaleLinks([string]$Root, [switch]$TopLevelOnly) {
    if (-not (Test-Path $Root)) { return }
    $items = if ($TopLevelOnly) {
        Get-ChildItem $Root -Force -ErrorAction SilentlyContinue
    } else {
        Get-ChildItem $Root -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($item in $items) {
        if ($item.LinkType -ne 'SymbolicLink') { continue }
        if ($item.Target -notlike "$RepoRoot*") { continue }
        if (-not (Test-Path $item.Target)) {
            Remove-Item $item.FullName -Force
            Write-Host "Removed stale link: $($item.FullName)"
        }
    }
}

Remove-StaleLinks (Join-Path $HOME '.claude\skills')
Remove-StaleLinks $HOME -TopLevelOnly

$linked = 0
$kept = 0

foreach ($file in Get-ChildItem $HomeSource -Recurse -File -Force) {
    $rel = $file.FullName.Substring($HomeSource.Length).TrimStart('\', '/')
    $dest = Join-Path $HOME $rel

    if (Test-Path $dest) {
        $existing = Get-Item $dest -Force
        if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $file.FullName) {
            $kept++
            continue
        }
        Remove-Item $dest -Force -Recurse
    }

    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $file.FullName | Out-Null
        Write-Host "Linked: $dest"
    } catch {
        Write-Warning "Symlink failed ($($_.Exception.Message))."
        Write-Warning "Falling back to copy. Re-run this script after 'git pull' to refresh."
        Write-Warning "To enable symlinks: Settings -> Privacy & Security -> For developers -> Developer Mode."
        Copy-Item $file.FullName $dest -Force
        Write-Host "Copied: $dest"
    }
    $linked++
}

Write-Host "Links: $linked new, $kept already correct."

# Hooks live in the repo so a clone gets them; git needs telling where.
if (Test-Path (Join-Path $RepoRoot '.githooks')) {
    git -C $RepoRoot config core.hooksPath .githooks
    Write-Host "Hooks enabled: core.hooksPath=.githooks"
}

# Global gitignore. Git reads only one excludes file, so never replace one
# already in use - its patterns would silently stop applying.
$current = git config --global core.excludesfile
$xdgHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
$xdgIgnore = Join-Path $xdgHome 'git\ignore'
if (-not $current -and -not (Test-Path $xdgIgnore)) {
    git config --global core.excludesfile '~/.gitignore'
    Write-Host "Configured: core.excludesfile=~/.gitignore"
} elseif ($current -ne '~/.gitignore' -and $current -ne (Join-Path $HOME '.gitignore')) {
    Write-Host "Skipped core.excludesfile: already using $(if ($current) { $current } else { $xdgIgnore }). Merge ~/.gitignore into it by hand."
}

# Daily update, for machines where a Claude session may not start for a while.
# Set ZOMP_NO_SCHEDULE=1 to opt out.
if ($env:ZOMP_NO_SCHEDULE -ne '1') {
    $taskName = 'Zomp agent-conventions update'
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Update task already registered."
    } else {
        $script = Join-Path $RepoRoot 'scripts\update-conventions.ps1'
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
        $trigger = New-ScheduledTaskTrigger -Daily -At 9am
        try {
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                -Description 'Fast-forward the Zomp agent conventions and refresh the home-directory links.' | Out-Null
            Write-Host "Scheduled: daily update at 09:00."
        } catch {
            Write-Warning "Could not register the update task: $($_.Exception.Message)"
        }
    }
}

Write-Host "Conventions update with: cd $RepoRoot; git pull"
