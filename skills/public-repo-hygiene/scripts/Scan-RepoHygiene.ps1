<#
.SYNOPSIS
    Scans a git repo for infrastructure and personal details before they are published.

.DESCRIPTION
    Looks for private IP addresses, MAC addresses, internal hostnames, personal
    file paths, email addresses, Wi-Fi settings, private keys, and any terms in your
    private sensitive-terms file (hostnames, domains, names -- one per line).

    Public repos (or repos whose visibility can't be determined) fail with exit 1.
    Private repos only warn, unless -Strict is given.

    Matches are printed masked so the report can be shown to an AI agent
    without repeating the sensitive value.

    A line containing "hygiene: allow" is skipped (use it only after review).

.PARAMETER Scope
    Tracked (default): every tracked file as it is now.
    Staged:  lines added in the staged changes (use before committing).
    History: every line ever added in any commit (use before making a repo public).

.EXAMPLE
    & "$env:USERPROFILE\.claude\skills\public-repo-hygiene\scripts\Scan-RepoHygiene.ps1" -Scope Staged
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [ValidateSet('Tracked', 'Staged', 'History')][string]$Scope = 'Tracked',
    [string]$TermsFile = (Join-Path $env:USERPROFILE '.config\ai-skills\sensitive-terms.txt'),
    [switch]$Strict
)

# Native git/gh write to stderr on normal "not found" cases; exit codes decide.
$ErrorActionPreference = 'Continue'

$top = git -C $Path rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $top) { Write-Error "Not a git repository: $Path"; exit 2 }
$top = "$top".Trim()

# --- Visibility -------------------------------------------------------------
$visibility = 'UNKNOWN'
$remote = git -C $top remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $remote -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    $v = gh repo view "$remote".Trim() --json visibility --jq .visibility 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) { $visibility = "$v".Trim().ToUpperInvariant() }
}

# --- Rules ------------------------------------------------------------------
$ignoreCase = [Text.RegularExpressions.RegexOptions]::IgnoreCase
$rules = New-Object System.Collections.Generic.List[object]
function Add-Rule([string]$Name, [string]$Pattern, [string]$Exclude) {
    $ex = $null
    if ($Exclude) { $ex = New-Object regex($Exclude, $ignoreCase) }
    $rules.Add([pscustomobject]@{ Name = $Name; Regex = (New-Object regex($Pattern, $ignoreCase)); Exclude = $ex })
}

$octet = '\d{1,3}'
Add-Rule 'Private IPv4 address' "(?<![\d.])(?:10(?:\.$octet){3}|192\.168(?:\.$octet){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.$octet){2}|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])(?:\.$octet){2}|169\.254(?:\.$octet){2})(?![\d.]*\d)"
Add-Rule 'Private IPv6 address' '(?<![0-9a-f:])fd[0-9a-f]{2}:[0-9a-f]{0,4}:[0-9a-f:]+'
Add-Rule 'MAC address' '(?<![0-9a-f:-])[0-9a-f]{2}(?:[:-][0-9a-f]{2}){5}(?![0-9a-f:-])'
Add-Rule 'Internal hostname' '\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:lan|local|internal|intranet|localdomain|home\.arpa|corp)\b(?!\.[a-z])'
Add-Rule 'Personal Windows path' '[a-z]:\\{1,2}Users\\{1,2}(?!(?:Public|Default|All Users)\b)[^\\\s"''<>$%{}]+' '\\Users\\{1,2}(?:<|\$|%)'
Add-Rule 'Personal home path' '(?<![\w.-])/(?:home|Users)/(?!runner\b|user\b|username\b|you\b)[a-z_][a-z0-9_.-]*'
Add-Rule 'Email address' '\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b' '(?:@example\.(?:com|org|net)|\.invalid$|\.test$|\.example$|noreply|no-reply)'
Add-Rule 'Wi-Fi setting' '\b(?:ssid|psk|wpa_passphrase|wpa-psk)\s*[:=]'
Add-Rule 'Private key' '-----BEGIN [A-Z ]*PRIVATE KEY-----'

$termCount = 0
if (Test-Path -LiteralPath $TermsFile) {
    foreach ($t in Get-Content -LiteralPath $TermsFile) {
        $t = $t.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $termCount++
        if ($t.StartsWith('re:')) { $p = $t.Substring(3) } else { $p = [regex]::Escape($t) }
        Add-Rule "Sensitive term #$termCount" $p
    }
}

# --- Lines to scan ----------------------------------------------------------
function Get-TrackedLine {
    foreach ($rel in (git -C $top -c core.quotepath=false ls-files)) {
        $full = Join-Path $top $rel
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        if ((Get-Item -LiteralPath $full).Length -gt 2MB) { continue }
        $bytes = [IO.File]::ReadAllBytes($full)
        $probe = [Math]::Min($bytes.Length, 8000)
        if ($probe -gt 0 -and [Array]::IndexOf($bytes, [byte]0, 0, $probe) -ge 0) { continue }  # binary
        $n = 0
        foreach ($line in ([Text.Encoding]::UTF8.GetString($bytes) -split "`r?`n")) {
            $n++
            [pscustomobject]@{ File = $rel; Line = $n; Text = $line }
        }
    }
}

function Get-AddedLine([string[]]$GitArgs) {
    $file = $null; $n = 0; $commit = ''
    foreach ($l in (& git -C $top -c core.quotepath=false @GitArgs)) {
        if ($l -match '^commit ([0-9a-f]{40})') { $commit = $Matches[1].Substring(0, 8); continue }
        if ($l -match '^\+\+\+ (?:b/)?(.*)$') { $file = $Matches[1]; continue }
        if ($l -match '^@@ -\d+(?:,\d+)? \+(\d+)') { $n = [int]$Matches[1]; continue }
        if ($l.StartsWith('+') -and $file -and $file -ne '/dev/null') {
            $label = $file
            if ($commit) { $label = "${commit}:$file" }
            [pscustomobject]@{ File = $label; Line = $n; Text = $l.Substring(1) }
            $n++
        }
    }
}

switch ($Scope) {
    'Tracked' { $lines = Get-TrackedLine }
    'Staged'  { $lines = Get-AddedLine @('diff', '--cached', '-U0', '--no-color') }
    'History' { $lines = Get-AddedLine @('log', '-p', '--all', '-U0', '--no-color', '--format=commit %H') }
}

# --- Scan -------------------------------------------------------------------
function Hide-Value([string]$Value) {
    if ($Value.Length -le 4) { return ('*' * $Value.Length) }
    $Value.Substring(0, 2) + ('*' * ($Value.Length - 2))
}

$findings = New-Object System.Collections.Generic.List[object]
foreach ($item in $lines) {
    if (-not $item.Text -or $item.Text -match 'hygiene:\s*allow') { continue }
    foreach ($rule in $rules) {
        foreach ($m in $rule.Regex.Matches($item.Text)) {
            if ($rule.Exclude -and $rule.Exclude.IsMatch($m.Value)) { continue }
            $findings.Add([pscustomobject]@{ File = $item.File; Line = $item.Line; Rule = $rule.Name; Match = (Hide-Value $m.Value) })
            break
        }
    }
}

# --- Report -----------------------------------------------------------------
$termNote = "$termCount private term(s)"
if (-not (Test-Path -LiteralPath $TermsFile)) { $termNote = 'no private terms file' }
Write-Host ("Repo hygiene: {0}  scope={1}  visibility={2}  ({3})" -f $top, $Scope, $visibility, $termNote)

if ($findings.Count -eq 0) {
    Write-Host 'No findings.' -ForegroundColor Green
    exit 0
}

foreach ($f in $findings) {
    Write-Host ('  {0}:{1}  {2}  [{3}]' -f $f.File, $f.Line, $f.Rule, $f.Match)
}

$blocking = $Strict -or ($visibility -ne 'PRIVATE' -and $visibility -ne 'INTERNAL')
if ($blocking) {
    $why = "a $($visibility.ToLowerInvariant()) repo"
    if ($visibility -eq 'UNKNOWN') { $why = 'a repo whose visibility is unknown (treated as public)' }
    if ($Strict -and ($visibility -eq 'PRIVATE' -or $visibility -eq 'INTERNAL')) { $why = "a $($visibility.ToLowerInvariant()) repo (-Strict)" }
    Write-Host ("BLOCKED: {0} finding(s) in {1}. Replace them with placeholders (see the public-repo-hygiene skill)." -f $findings.Count, $why) -ForegroundColor Red
    exit 1
}
Write-Host ("WARNING: {0} finding(s). This repo is private, but private repos get forked, shared, or made public later." -f $findings.Count) -ForegroundColor Yellow
exit 0
