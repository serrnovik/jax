function Set-JaxVaultTokenPermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TokenDirectory,

        [Parameter(Mandatory = $true)]
        [string] $TokenPath
    )

    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User

        $directoryAcl = [Security.AccessControl.DirectorySecurity]::new()
        $directoryAcl.SetAccessRuleProtection($true, $false)
        $directoryAcl.SetOwner($identity)
        $directoryAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
            $identity,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow
        ))
        [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($TokenDirectory), $directoryAcl)

        $fileAcl = [Security.AccessControl.FileSecurity]::new()
        $fileAcl.SetAccessRuleProtection($true, $false)
        $fileAcl.SetOwner($identity)
        $fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
            $identity,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow
        ))
        [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($TokenPath), $fileAcl)
        return
    }

    $directoryMode = [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute
    $fileMode = [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite
    [IO.File]::SetUnixFileMode($TokenDirectory, $directoryMode)
    [IO.File]::SetUnixFileMode($TokenPath, $fileMode)
}
