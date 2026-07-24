function New-JaxFlowConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnvName,
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $ConfigFile
    )

    $textInfo = (Get-Culture).TextInfo
    $fileName = [IO.Path]::GetFileNameWithoutExtension($ConfigFile.Name).Replace("\", "/")
    $fullName = "$EnvName/$fileName"
    $prettyName = $textInfo.ToTitleCase($fullName).Replace("/", " ").Replace("\\", " ").Replace("_", " ").Replace("-", " ")

    $flowDir = Split-Path -Parent $ConfigFile.FullName
    $envDir = Split-Path -Parent $flowDir

    return [pscustomobject]@{
        Name          = $fullName
        BaseName      = $EnvName
        Configuration = $fileName
        PrettyName    = $prettyName
        ConfigPath    = [IO.Path]::GetFullPath($ConfigFile.FullName)
        EnvDirPath    = [IO.Path]::GetFullPath($envDir)
        FlowDirPath   = [IO.Path]::GetFullPath($flowDir)
    }
}
