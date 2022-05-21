param (
    [Parameter(Mandatory=$true)][string] $DataDir
)

$CoverageDir = $DataDir

function SameLines {
    param(
        [Parameter(Mandatory = $true)] $Lines1,
        [Parameter(Mandatory = $true)] $Lines2
    )
    for($i = 0; $i -lt $Lines1.Count; $i++){
        if($Lines1[$i] -ne $Lines2[$i]){
            return $false
        }
    }
    return $true
}

function Get-AreFilesDuplicates {
    param(
        [Parameter(Mandatory = $true)][string] $File1,
        [Parameter(Mandatory = $true)][string] $File2
    )
    $NLines1 = 0
    $NLines2 = 0
    Get-Content -Path $File1 -read 1000 | %{$NLines1 += $_.Length}
    Get-Content -Path $File2 -read 1000 | %{$NLines2 += $_.Length}
    if($NLines1 -ne $NLines2){
        return $false
    }
    $LinesFile1 = Get-Content -Path $File1 | Select-Object -First 100
    $LinesFile2 = Get-Content -Path $File2 | Select-Object -First 100
    if(-not (SameLines -Lines1 $LinesFile1 -Lines2 $LinesFile2)){
        return $false
    }
    $LinesFile1 = Get-Content -Path $File1 | Select-Object -Last 100
    $LinesFile2 = Get-Content -Path $File2 | Select-Object -Last 100
    if(-not (SameLines -Lines1 $LinesFile1 -Lines2 $LinesFile2)){
        return $false
    }
    return $true
}

function Get-Duplicates {
    param (
        [Parameter(Mandatory=$true)][string] $LineCoverageFilePath
    )
    if(-not (Test-Path -Path $LineCoverageFilePath -PathType Leaf -Filter "*.csv")){
        throw "File $LineCoverageFilePath not found"
    }
    $TestCodeunitDetails = ((Get-Item -Path $LineCoverageFilePath).BaseName -split "\." | Select-Object -First 1) -split "_"
    $Country = $TestCodeunitDetails[0]
    $TestCodeunitId = $TestCodeunitDetails[1]
    $Filter = "$($Country)_$($TestCodeunitId).*"
    foreach($LineCoverageFile in (Get-ChildItem -Path $CoverageDir -Filter $Filter -File)){
        if($LineCoverageFilePath -eq $LineCoverageFile.FullName){
            continue
        }
        if(Get-AreFilesDuplicates -File1 $($LineCoverageFilePath) -File2 $($LineCoverageFile.FullName)){
            $LineCoverageFile
        }
    }
}
function Get-LineCoverageFilesToDelete {
    $LineCoverageFiles = Get-ChildItem -Path $CoverageDir -Filter "*.csv" -File
    while(-not ($LineCoverageFiles.Count -eq 0)){
        $FileToUnduplicate = $LineCoverageFiles | Select-Object -First 1
        $Duplicates = Get-Duplicates -LineCoverageFilePath $($FileToUnduplicate.FullName)
        $Duplicates
        $LineCoverageFiles = $LineCoverageFiles |
            ?{ ($_.FullName -ne $FileToUnduplicate.FullName) -and (-not ($Duplicates.FullName -contains $_.FullName)) }
    }
}

Get-LineCoverageFilesToDelete | %{Remove-Item -Path $($_.FullName)}