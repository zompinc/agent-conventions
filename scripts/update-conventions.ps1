# Pull the latest conventions and relink them. Safe to run from a scheduled
# task: it never touches local work and never blocks on anything interactive.
#
# It gives up quietly when the working tree is dirty, the branch is ahead of
# its remote, the branch is not master, it ran recently (default 6 hours), or
# the network is unavailable.
#
# Force a check with -Now. Log: .git\zomp-update.log, which can never be
# committed because .git is not part of the work tree.

param(
    [switch]$Now,
    [int]$MaxAgeHours = 6
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if (-not (Test-Path (Join-Path $RepoRoot '.git'))) { exit 0 }

$logFile = Join-Path $RepoRoot '.git\zomp-update.log'
$stampFile = Join-Path $RepoRoot '.git\zomp-update.stamp'

function Write-Log([string]$Message) {
    "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message | Add-Content -Path $logFile
}

if (-not $Now -and (Test-Path $stampFile)) {
    $last = Get-Item $stampFile
    if (((Get-Date) - $last.LastWriteTime).TotalHours -lt $MaxAgeHours) { exit 0 }
}

$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
if ($branch -ne 'master') {
    Write-Log "skipped: on branch $branch"
    exit 0
}

if (git status --porcelain) {
    Write-Log 'skipped: working tree has local changes'
    exit 0
}

git fetch --quiet origin master 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Log 'skipped: fetch failed (offline?)'
    exit 0
}

# Record the attempt even when nothing changes, so an unreachable remote does
# not cause a fetch on every session.
Set-Content -Path $stampFile -Value (Get-Date -Format 'o')

$ahead = (git rev-list --count origin/master..HEAD) -as [int]
if ($ahead -gt 0) {
    Write-Log "skipped: $ahead local commit(s) not pushed"
    exit 0
}

$behind = (git rev-list --count HEAD..origin/master) -as [int]
if ($behind -eq 0) { exit 0 }

git merge --ff-only --quiet origin/master 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Log "updated: fast-forwarded $behind commit(s)"
    # Relink, so a new file or skill added upstream exists on this machine.
    $env:ZOMP_NO_SCHEDULE = '1'
    & (Join-Path $RepoRoot 'bootstrap.ps1') *>> $logFile
} else {
    Write-Log 'skipped: cannot fast-forward'
}
