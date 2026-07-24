function Invoke-JaxBeep {
    [CmdletBinding()]
    param ()

    try {
        [console]::Beep()
        return
    } catch {
        Write-Host "`a" -NoNewline
    }
}
