$pipeLineGroupName = "pipeline"
$PIPELINE_SUBSTITUTION_REGEX_PART = "(?<$pipeLineGroupName>\|.*?)?\s*"
$PLACEHOLDER_PATH_PATTERN = "[a-zA-Z0-9_]+(\??\.[a-zA-Z0-9_]+)*\??"
$FUNCTION_PATTERN = "[a-zA-Z0-9_]+\s*\((?:[^()]*|\([^()]*\))*\)"
$PLACEHOLDER_REGEX = "\{\{\s*($PLACEHOLDER_PATH_PATTERN)\s*$PIPELINE_SUBSTITUTION_REGEX_PART\}\}"  # https://regex101.com/r/IBFgBT/1
$PLACEHOLDER_SUBTREE_REGEX = "\{\{\{\s*([a-zA-Z0-9_]\??+(\??\.[a-zA-Z0-9_]+)*)\s*$PIPELINE_SUBSTITUTION_REGEX_PART\}\}\}"  # https://regex101.com/r/wF6QKa/1
$PLACEHOLDER_ONLY_REGEX = "^$($PLACEHOLDER_REGEX)$"

$PATH_NOT_FOUND_IN_HASHTABLE = "__PATH_NOT_FOUND_IN_HASHTABLE__"
$PowershellReservedCommonParams = @( # from https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters
    'verbose', 'debug', 'erroraction', 'errorvariable',
    'warningaction', 'warningvariable', 'informationaction',
    'informationvariable', 'outvariable', 'outbuffer',
    'pipelinevariable', 'whatif', 'confirm', 'passthru'
)


#Get public and private function definition files.
$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'public') -Filter '*.ps1')
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'private') -Filter '*.ps1')
foreach ($import in @($public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

# Load custom placeholder pipeline functions from functions directory
$functionsDir = Join-Path -Path $PSScriptRoot -ChildPath 'functions'
if (Test-Path $functionsDir) {
    $customFuncs = Get-ChildItem -Path $functionsDir -Filter '*.ps1'
    foreach ($f in $customFuncs) {
        try {
            . $f.FullName
        } catch {
            throw "Unable to dot source custom function [$($f.FullName)]"
        }
    }
}
