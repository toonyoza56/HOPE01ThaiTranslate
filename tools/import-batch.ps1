<#
.SYNOPSIS
    Converts a translation batch "translations/src/<name>.txt" into "translations/<name>.csv".

.DESCRIPTION
    Batch format (one line per string, UTF-8):
        id|thai text
    Lines starting with # are comments. "\n" in the Thai text stays as the two characters \n
    (the build turns it into a newline). English text and category are looked up from
    work/strings.csv by id, and each row is checked:
      - unknown id                         -> error
      - keep_terms missing from the Thai   -> warning (terms ending in ? are optional)
      - different number of \n than the English -> warning
#>
param([Parameter(Mandatory)] [string]$Name)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$src  = Join-Path $root "translations\src\$Name.txt"
$dst  = Join-Path $root "translations\$Name.csv"

$strings = @{}
Import-Csv (Join-Path $root "work\strings.csv") -Encoding UTF8 | ForEach-Object { $strings[$_.id] = $_ }

$q = { param($s) '"' + ($s -replace '"', '""') + '"' }
$out = New-Object System.Collections.Generic.List[string]
$out.Add("id,category,english,thai,note")
$warn = 0; $n = 0
foreach ($line in [IO.File]::ReadAllLines($src, [Text.Encoding]::UTF8)) {
    if (-not $line.Trim() -or $line.StartsWith("#")) { continue }
    $i = $line.IndexOf("|")
    if ($i -lt 0) { throw "bad line (no |): $line" }
    $id = $line.Substring(0, $i).Trim()
    $s = $strings[$id]
    if (-not $s) { throw "unknown id $id" }
    # Script fragments are joined with key names at runtime (" OR TAB[/color]"), so their edge
    # spaces matter: keep the English leading/trailing whitespace, trim everything else.
    $thai = $line.Substring($i + 1).Trim()
    $lead = [regex]::Match($s.english, '^\s*').Value; $trail = [regex]::Match($s.english, '\s*$').Value
    $thai = $lead + $thai + $trail
    foreach ($t in ($s.keep_terms -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.EndsWith("?") }) {
        if (-not $thai.Contains($t)) { Write-Warning "$id keep term '$t' missing"; $warn++ }
    }
    $nlE = ([regex]::Matches($s.english, '\\n')).Count; $nlT = ([regex]::Matches($thai, '\\n')).Count
    if ($nlE -ne $nlT) { Write-Warning "$id line breaks: english $nlE, thai $nlT"; $warn++ }
    $out.Add(($id, $s.category, (& $q $s.english), (& $q $thai), '""') -join ",")
    $n++
}
[IO.File]::WriteAllLines($dst, $out, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "$Name : $n rows -> $dst ($warn warnings)"
