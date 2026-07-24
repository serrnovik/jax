Register-PlaceholderFunction "env" {
    param($thisValue, [string]$name, $fallback)
    $val = [System.Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrEmpty($val)) { return $fallback }
    return $val
}
