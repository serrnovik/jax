function Read-JaxVaultSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [ValidateRange(1, 10)]
        [int] $MaxAttempts = 3
    )

    # Read-Host -AsSecureString piped to ConvertFrom-SecureString throws "The value of
    # argument SecureString is not valid" when the input is empty (an Enter on its own,
    # or a paste the terminal did not deliver). -MaskInput returns plain text, so empty
    # input can be retried. With redirected stdin, -MaskInput ends the process on
    # Linux, so read the line directly instead.
    $inputRedirected = Test-JaxVaultInputRedirected
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $value = if ($inputRedirected) {
            [Console]::In.ReadLine()
        } else {
            Read-Host -Prompt $Prompt -MaskInput
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        if ($inputRedirected -and $null -eq $value) {
            break
        }

        if ($attempt -lt $MaxAttempts) {
            Write-Host "Nothing was entered. Paste the value and press Enter." -ForegroundColor Yellow
        }
    }

    return ''
}
