function Git-Switch {
    param (
        [Parameter(Mandatory=$true)][string] $Visibility
    )
    Remove-Item -Path .\.git
    Remove-Item -Path .\.gitignore
    New-Item -ItemType SymbolicLink -Path .\.git -Target ..\repos-metadata\.gitignore.$Visibility
    New-Item -ItemType SymbolicLink -Path .\.gitignore -Target ..\repos-metadata\.git-$Visibility
}