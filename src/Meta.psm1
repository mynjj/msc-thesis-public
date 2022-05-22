function Git-Switch {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("public","private")]
        [string] $Visibility
    )
    (Get-Item -Path .\.git).Delete()
    (Get-Item -Path .\.gitignore).Delete()
    New-Item -ItemType SymbolicLink -Path .\.git -Target ..\repos-metadata\.git-$Visibility
    New-Item -ItemType SymbolicLink -Path .\.gitignore -Target ..\repos-metadata\.gitignore.$Visibility
}