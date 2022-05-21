[CmdletBinding()]
param (
    [Parameter()]
    [switch]
    $SkipNAVEnlistment = $false
)

# Verify NAV repo enlistment dir is defined
if($null -eq $Env:NAV_REPO_PATH){
    throw "Set the environment variable NAV_REPO_PATH with the absolute path to your NAV repo";
}

# Verify data dir is defined
if($null -eq $Env:MSC_DATA_PATH){
    throw "Set the environment variable MSC_DATA_PATH with the absolute path to your data folder";
}

# To check if enlistment is initialized we check if the command `Start-NavServer` is defined
if(!(Get-Command Start-NavServer -ErrorAction Ignore) -and (-not $SkipNAVEnlistment)){
    try {
        .$Env:NAV_REPO_PATH\Eng\Core\Enlistment\start.ps1
    }
    catch {
        throw "Failed to initialize NAV enlistment: $_"
    }
}

# Import DME helpers if not available
if(!(Get-Command Get-DMEJob -ErrorAction Ignore) -and (-not $SkipNAVEnlistment)){
    try{
        .$Env:NAV_REPO_PATH\Eng\extensions\helpers\importdme.ps1
    }
    catch {
        throw "Failed to import DME utils: $_"
    }
}

if(-not $SkipNAVEnlistment){
    Import-Module $Env:NAV_REPO_PATH\Eng\Core\Scripts\Infrastructure\Azure\AzureLogs.psm1
    Import-Module $Env:PKGMicrosoft_BusinessCentral_InfrastructureDME_DMELibrary\lib\Azure\AzureJobStorage.psm1
    Import-Module $Env:NAV_REPO_PATH\Eng\Core\Helpers\snaphelpers.psm1 -DisableNameChecking
    . $Env:NAV_REPO_PATH\Eng\Core\Lib\Dependencies.ps1
}

$Global:NAV = $Env:NAV_REPO_PATH
$Global:MSCROOT = $PSScriptRoot
$Global:MSCDATA_DIR = $Env:MSC_DATA_PATH
$Global:SRCROOT = "$MSCROOT\src"
$Global:RESOURCES_DIR = "$MSCROOT\resources"
$Global:CISTATS_SRC = "$MSCROOT\src\ci-stats"
$Global:DATACOLLECTION_SRC = "$MSCROOT\src\dataset-collection"
$Global:THESIS_SRC = "$MSCROOT\thesis"
$Global:TMPDIR = "$MSCROOT\tmp"

if (-not (Test-Path -Path $Global:TMPDIR)){
    New-Item -Path $Global:TMPDIR -ItemType Directory
}

# Import modules

## Utils
Import-Module $PSScriptRoot\src\common\JobStorage.psm1 -Force -Scope Global
Import-Module $PSScriptRoot\src\common\MetaModel.psm1 -Force -Scope Global
Import-Module $PSScriptRoot\src\common\Ranklib.psm1 -Force -Scope Global

Import-Module $MSCROOT\src\DataMigrations.psm1 -Force -Scope Global
## CI Stats
. $CISTATS_SRC\config.ps1 
Import-Module $CISTATS_SRC\CIStats.psm1 -Force -Scope Global

## Dataset collection: CI History, coverage
Import-Module $SRCROOT\CIHistory.psm1 -Force -Scope Global
Import-Module $SRCROOT\CoverageCollection.psm1 -Force -Scope Global

## Ranklib training and evaluation
Import-Module $MSCROOT\src\Training.psm1 -Force -Scope Global
Import-Module $MSCROOT\src\Evaluation.psm1 -Force -Scope Global

## Thesis writing
Import-Module $THESIS_SRC\Thesis.psm1 -Force -Scope Global

Import-Module $PSScriptRoot\src\Meta.psm1 -Force -Scope Global

Set-Location -Path $MSCROOT