$script:Dataset = "line-coverage"


function Get-CoveragePerCodeunitForJob
{
    param (
        [Parameter(Mandatory=$true)][int] $JobId
    )
    $Storage = Find-AzureJobStorageNameForJobId -JobId $JobId
    $JobTmpPath = (Initialize-JobTmpFolder -JobId $JobId).FullName
    $JobPath = Initialize-JobFolder -JobId $JobId -Dataset $Dataset

    $null = Get-AzureJobOutput -FileName codecoveragedetailed*.zip -DestinationFolder $JobTmpPath -JobId $JobId -StorageAccount $Storage
    $CovZipFiles = Get-ChildItem -Path $JobTmpPath -File -Filter *.zip
    foreach($CovZipFile in $CovZipFiles)
    {
        $NameInfo = $CovZipFile.BaseName.Substring("codecoveragedetailed".Length)
        if($NameInfo -match "_ALTR_(.+)_[a-z]+$"){
            # Naming convention of files produced by modified AL Test Runner.
            $Country = CountryForTaskName -TaskName $Matches[1]
        }
        else{
            $Country = $CovZipFile.BaseName.Substring("codecoveragedetailed".Length) -split '_' | Select-Object -First 1
        }
        $ZipDestinationPath = "$JobTmpPath\$($CovZipFile.BaseName)"
        $null = Expand-Archive -Path $CovZipFile.FullName -DestinationPath $ZipDestinationPath
        $CodeunitCoverageFiles = Get-ChildItem -Path $ZipDestinationPath -File
        foreach($CodeunitCoverageFile in $CodeunitCoverageFiles)
        {
            $CodeunitId = $CodeunitCoverageFile.BaseName -split '_' | Select-Object -Last 1
            $DestName = "$($Country)_$CodeunitId.$($NameInfo).$($CodeunitCoverageFile.BaseName).csv"
            $null = Move-Item -Path $CodeunitCoverageFile.FullName -Destination "$JobPath\$DestName"
        }
    }
}
