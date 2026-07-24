[CmdletBinding()]
param (
    [string] $Path = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$textExtensions = @(
    '.cmd', '.csv', '.html', '.json', '.md', '.old', '.ps1', '.psd1',
    '.psm1', '.sh', '.txt', '.xml', '.yaml', '.yml'
)
$selfPath = [IO.Path]::GetFullPath($PSCommandPath)
$rules = [ordered]@{
    'absolute macOS user path' = '/Users/'
    'absolute Windows user path' = 'C:\\Users\\'
    'absolute Linux user path' = '/home/[A-Za-z0-9._-]+/'
    'internal company domain' = ('logi' + 'ficiel\.com')
    'personal domain' = ('no' + 'vik\.fr')
    'source monorepo name' = ('snow' + 'main')
    'consumer product name 1' = ('nobody' + 'tobrand')
    'consumer product name 2' = ('rip' + 'icts')
    'consumer product name 3' = ('pronounce' + 'fit')
    'personal shorthand comment' = '\[' + 'sno\]'
    'personal author name' = ('Sergey' + '\s+Novikov')
    'repository-only customization' = ('snow' + '[- ]customizations')
    'legacy personal codename' = '\b' + ('b' + 'en') + '\b|' + ('bob' + 'oss')
    'internal build topology' = '/opt/buildagent|teamcity-hel-|MainVcs|SecondaryVcs'
    'private IPv4 address' = '(?<![0-9])(?:10\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}|192\.168\.(?:[0-9]{1,3}\.)[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.(?:[0-9]{1,3}\.)[0-9]{1,3})(?![0-9])'
    'GitHub classic token' = 'gh[pousr]_[A-Za-z0-9_]{30,}'
    'AWS access key' = 'AKIA[0-9A-Z]{16}'
    'Google API key' = 'AIza[0-9A-Za-z_-]{30,}'
    'Slack token' = 'xox[baprs]-[A-Za-z0-9-]{10,}'
    'Stripe secret key' = 'sk_(?:live|test)_[A-Za-z0-9]{16,}'
    'JWT token' = 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    'credential in URI' = '[A-Za-z][A-Za-z0-9+.-]*://[^/\s:@]+:[^/\s@]+@'
    'private key material' = 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
}

$findings = New-Object 'System.Collections.Generic.List[string]'
$files = Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and
    $_.FullName -ne $selfPath -and
    (
        $textExtensions -contains $_.Extension.ToLowerInvariant() -or
        $_.Name -in @('psake')
    )
}

foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($Path, $file.FullName)
    foreach ($rule in $rules.GetEnumerator()) {
        if ($relative -match $rule.Value) {
            $findings.Add(('{0}: path contains {1}' -f $relative, $rule.Key))
        }
    }

    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        # This exact address is the deliberately public project/security
        # contact. Other references to the personal domain remain findings.
        $auditedLine = $line -replace [regex]::Escape('sergey@novik.fr'), '<public-security-contact>'
        foreach ($rule in $rules.GetEnumerator()) {
            if ($auditedLine -match $rule.Value) {
                $findings.Add(('{0}:{1}: {2}' -f $relative, $lineNumber, $rule.Key))
            }
        }
    }
}

if ($findings.Count -gt 0) {
    $findings | Sort-Object -Unique | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw "Public-source audit found $($findings.Count) potential disclosure(s)."
}

Write-Host "Public-source audit passed for $($files.Count) text files." -ForegroundColor Green
