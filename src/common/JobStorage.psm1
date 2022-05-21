function Get-JobFolderPath {
    param (
        [Parameter(Mandatory=$true)][int] $JobId,
        [Parameter(Mandatory=$true)][string] $Dataset
    )
    "$MSCDATA_DIR\$Dataset\job$JobId"
}
function Initialize-JobFolder {
    param (
        [Parameter(Mandatory=$true)][int] $JobId,
        [Parameter(Mandatory=$true)][string] $Dataset
    )
    $DataDir = "$MSCDATA_DIR\$Dataset"
    if(-not(Test-Path -Path $DataDir -PathType Container)){
        $null = New-Item -Path $DataDir -ItemType Directory
    }
    $JobFolder = Get-JobFolderPath -JobId $JobId -Dataset $Dataset
    if(Test-Path -Path $JobFolder -PathType Container){
        throw "Job output folder already exists"
    }
    $null = New-Item -Path $JobFolder -ItemType Directory
    $JobFolder
}

function Get-JobTmpPath {
    param ([int] $JobId)
    if (-not(Test-Path -Path $Global:TMPDIR -PathType Container)) {
        $null = New-Item -Path $Global:TMPDIR -ItemType Directory
    }
    "$Global:TMPDIR\job$JobId"
}
function Initialize-JobTmpFolder {
    param([int] $JobId)
    $JobTmpPath = Get-JobTmpPath -JobId $JobId
    if (Test-Path -Path $JobTmpPath -PathType Container) {
        Remove-Item -Path $JobTmpPath -Recurse
    }
    $folder = New-Item -Path $JobTmpPath -ItemType Directory
    $folder
}

function Get-AzureJobOutputContents {
    param (
        [Parameter(Mandatory=$true)] [string] $Storage,
        [Parameter(Mandatory=$true)] [string] $Pattern,
        [Parameter(Mandatory=$true)] [string] $Container
    )
    # Similar to `Test-AzureJobOutputFileExists`, however the result there is casted into boolean, so the contents are lost
    $StContext, $StInfo = GetThisStorageContextAndStorageInfo -StorageAccount $Storage
    Get-AzureStorageBlob -Blob $Pattern -Context $StContext -ErrorAction Ignore -Container $Container
}