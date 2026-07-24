function Resolve-JaxVaultSecrets {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object] $Data, # Hashtable, Array, or String

        [Parameter(Mandatory = $false)]
        [hashtable] $Cache = @{} # Simple session cache for secrets
    )

    if ($null -eq $Data) {
        return $null
    }

    # Check if disabled
    if (Test-Path Env:\JAX_NO_CONFIG_SECRETS) {
        return $Data
    }

    if ($Data -is [string]) {
        # Pattern: << kv2|ENGINE/mount:PATH:KEY >>
        # Regex to capture content between << and >>
        if ($Data -match '<<\s*kv2\|(?<path>[^>]+)\s*>>') {
            # Extract content: "demo/data/secret:key"
            # Note: User example: "<< kv2|{{ secrets.default_engine }}:infra/...:key >>"
            # We assume variable expansion happened BEFORE this call.

            # Simple replacement loop to handle multiple secrets in one string?
            # User example shows one whole string replacement, but let's support robust regex replace.

            $resolvedString = $Data
            $matches = [regex]::Matches($Data, '<<\s*kv2\|(?<content>[^>]+)\s*>>')
            foreach ($m in $matches) {
                $raw = $m.Groups['content'].Value.Trim()
                # Split by ':'
                # Format: MOUNT:PATH:KEY
                # Example: kv:ci/robot:user
                # In Vault KV2, path often includes 'data' or not depending on mount, but usually user provides full path.
                # Three-part example: "kv:ci/robot:user" -> mount "kv", path "ci/robot", key "user".
                # Or just Path:Key?


                $parts = $raw -split ':'
                if ($parts.Count -lt 2) {
                    Write-Warning "Invalid secret format '$raw'. Expected 'ENGINE:PATH:KEY' or 'PATH:KEY'."
                    continue
                }

                $mount = $parts[0]
                $path = $parts[1]
                $key = if ($parts.Count -gt 2) { $parts[2] } else { $null }

                # If only 2 parts, maybe default mount? Or Path:Key?
                # Let's assume 3 parts for safety as per user example.

                # Lookup secret
                $cacheKey = "{0}:{1}" -f $mount, $path
                $secretData = $null

                if ($Cache.ContainsKey($cacheKey)) {
                    Write-Debug "Cache hit for secret '$cacheKey'"
                    $secretData = $Cache[$cacheKey]
                } else {
                    Write-Debug "Cache miss for secret '$cacheKey'"
                    try {
                        # Use Vault CLI. Prefer the "mount/path" form since it matches common manual usage:
                        #   vault kv get secret/external-services/open-ai
                        # and avoids subtle -mount parsing differences across vault versions.
                        $secretRef = ('{0}/{1}' -f $mount, $path).TrimEnd('/')
                        Write-Debug "Fetching vault secret '$secretRef' (key '$key')"

                        function Invoke-JaxVaultCliCapture {
                            param(
                                [Parameter(Mandatory = $true)] [string[]] $Args
                            )
                            $errFile = New-TemporaryFile
                            try {
                                $stdout = (& vault @Args 2> $errFile) | Out-String
                                $exitCode = $LASTEXITCODE
                                $stderr = ''
                                try {
                                    $stderr = Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue
                                } catch {
                                    $stderr = ''
                                }
                                return @{
                                    ExitCode = $exitCode
                                    StdOut   = $stdout
                                    StdErr   = $stderr
                                }
                            } finally {
                                Remove-Item -Path $errFile -Force -ErrorAction SilentlyContinue
                            }
                        }

                        # 1) Try JSON output (preferred, supports caching all keys)
                        $result = Invoke-JaxVaultCliCapture -Args @('kv', 'get', '-format=json', $secretRef)
                        if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.StdOut)) {
                            Write-Debug ("Vault JSON fetch failed for '{0}'. ExitCode={1}. StdErr={2}" -f $secretRef, $result.ExitCode, ($result.StdErr.Trim() -replace '\s+', ' '))

                            # 1b) Fallback: explicit mount flag
                            $result = Invoke-JaxVaultCliCapture -Args @('kv', 'get', '-mount', $mount, '-format=json', $path)
                        }

                        if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.StdOut)) {
                            $obj = $result.StdOut | ConvertFrom-Json
                            $secretData = $obj.data.data # KV2 structure
                            $Cache[$cacheKey] = $secretData
                        } else {
                            # 2) Last resort: field fetch (older vault CLIs / kv behaviors)
                            if (-not [string]::IsNullOrWhiteSpace($key)) {
                                $fieldResult = Invoke-JaxVaultCliCapture -Args @('kv', 'get', ('-field={0}' -f $key), $secretRef)
                                if ($fieldResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($fieldResult.StdOut)) {
                                    $fieldResult = Invoke-JaxVaultCliCapture -Args @('kv', 'get', '-mount', $mount, ('-field={0}' -f $key), $path)
                                }

                                if ($fieldResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($fieldResult.StdOut)) {
                                    $secretData = @{ $key = ($fieldResult.StdOut.TrimEnd()) }
                                    $Cache[$cacheKey] = $secretData
                                } else {
                                    Write-Warning "Failed to fetch secret '$secretRef'. ExitCode=$($fieldResult.ExitCode)"
                                }
                            } else {
                                Write-Warning "Failed to fetch secret '$secretRef'. ExitCode=$($result.ExitCode)"
                            }
                        }
                    } catch {
                        Write-Warning "Error fetching secret '$mount/$path': $($_.Exception.Message)"
                    }
                }


                if ($secretData -and $key) {
                    $found = $false
                    $val = $null

                    if ($secretData -is [System.Collections.IDictionary]) {
                        $hasKey = $false
                        if ($secretData.PSObject.Methods.Name -contains 'ContainsKey') {
                            try { $hasKey = [bool]$secretData.ContainsKey($key) } catch { $hasKey = $false }
                        } else {
                            try { $hasKey = [bool]$secretData.Contains($key) } catch { $hasKey = $false }
                        }
                        if ($hasKey) {
                            $val = $secretData[$key]
                            $found = $true
                        }
                    }
                    if (-not $found -and $secretData -and $secretData.PSObject.Properties[$key]) {
                        $val = $secretData.$key
                        $found = $true
                    }

                    if ($found) {
                        $resolvedString = $resolvedString.Replace($m.Value, $val)
                    } else {
                        Write-Warning "Secret '$mount/$path' found but key '$key' missing."
                    }
                }
            }
            return $resolvedString
        }
        return $Data
    } elseif ($Data -is [System.Collections.IDictionary]) {
        # Recurse keys (copy to avoid modification during iteration if needed, but we modify values)
        # Use a copy to be safe if it's a generic dictionary, or modify in place if it's hashtable?
        # Better return a new structure or modify in place if explicitly allowed.
        # Let's return a copy to avoid side effects on cached configs.
        $newDict = if ($Data -is [System.Collections.Specialized.OrderedDictionary]) { [ordered]@{} } else { @{} }
        foreach ($k in $Data.Keys) {
            $newDict[$k] = Resolve-JaxVaultSecrets -Data $Data[$k] -Cache $Cache
        }
        return $newDict
    } elseif ($Data -is [System.Collections.IEnumerable]) {
        $newList = @()
        foreach ($item in $Data) {
            $newList += Resolve-JaxVaultSecrets -Data $item -Cache $Cache
        }
        return $newList
    }

    return $Data
}
