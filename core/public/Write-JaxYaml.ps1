function Write-JaxYaml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [object] $InputObject
    )
    Initialize-JaxYamlProvider
    $yamlContent = $InputObject | ConvertTo-Yaml
    if ($null -eq $yamlContent) { $yamlContent = '' }

    # powershell-yaml/YamlDotNet escapes non-BMP Unicode as \UXXXXXXXX even
    # when the output file is UTF-8. Keep printable characters such as emoji
    # readable in repository-owned YAML while preserving control escapes.
    $yamlContent = [regex]::Replace(
        [string] $yamlContent,
        '\\U(?<code>[0-9A-Fa-f]{8})',
        {
            param($match)
            $codePoint = [Convert]::ToInt32($match.Groups['code'].Value, 16)
            if ($codePoint -lt 0xA0 -or $codePoint -gt 0x10FFFF) {
                return $match.Value
            }
            return [char]::ConvertFromUtf32($codePoint)
        }
    )

    # UTF-8 (no BOM) via .NET: consistent on PS 5.1/7+ and matches typical editor defaults for YAML.
    # (Set-Content -Encoding utf8 is BOM in Windows PowerShell 5.1, which is awkward for some tools.)
    # Note: any YAML comment lines (# ...) in the file are not round-tripped when we rewrite from
    # a parsed object—only values we serialize survive. Keep emoji in real fields if you need them.
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($resolvedPath, $yamlContent, $utf8NoBom)
}
