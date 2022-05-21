$HPCUser = "diem"
$HPCHostName = "hpc.itu.dk"
$ModelFileFilter = "model*.xml"
$TrainingFilename = "training.dat"
$ValidationFilename = "validation.dat"
$RanklibJarFilename = "RankLib-2.17.jar"

function Get-RanklibJarPath {
    return "$RESOURCES_DIR\$RanklibJarFilename"
}
function Get-IsRanklibDatasetTrained {
    param (
        [Parameter(Mandatory=$true)][string] $RanklibDataset
    )
    @(Get-ChildItem -Path $(Get-RanklibDatasetPath -RanklibDataset $RanklibDataset) -Filter $ModelFileFilter).Length -ne 0
}

function Train-RanklibDataset {
    param (
        [Parameter(Mandatory=$true)][string] $RanklibDataset
    )
    Write-Host "Training $RanklibDataset"
    if(Get-IsRanklibDatasetTrained -RanklibDataset $RanklibDataset){
        throw "Model files already found on dataset $RanklibDataset"
    }
    if(-not (Test-Connection -ComputerName $HPCHostName -Quiet -Count 1 -ErrorAction SilentlyContinue)){
        throw "HPC unreachable"
    }
    ssh $HPCUser@$HPCHostName "mkdir ~/$RanklibDataset"
    if($LASTEXITCODE -eq 1){
        throw "Ranklib dataset $RanklibDataset already found on the HPC"
    }
    $RP = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    scp "$RP\*.job" $HPCUser@$($HPCHostName):~/$RanklibDataset/
    scp "$RP\$TrainingFilename" $HPCUser@$($HPCHostName):~/$RanklibDataset/
    #ssh $HPCUser@$HPCHostName "for f in $RanklibDataset/*.job; do sbatch $f; done"
}


function Download-TrainedModels {
    param(
        [Parameter(Mandatory=$true)][string] $RanklibDataset
    )
    if(-not (Test-Connection -ComputerName $HPCHostName -Quiet -Count 1 -ErrorAction SilentlyContinue)){
        throw "HPC unreachable"
    }
    $RP = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    $ToDownload = ssh $HPCUser@$($HPCHostName) "ls $RanklibDataset/$ModelFileFilter"  |
        ?{ 
            $ModelFilename = $_ -split "/" | Select-Object -Last 1
            if(Test-Path -Path $(Join-Path $RP $ModelFilename)){
                Write-Host "$ModelFilename already found. Skipping..."
                return $false
            }
            return $true
        }

    foreach($FileToDownload in $ToDownload){
        scp $HPCUser@$($HPCHostName):~/$FileToDownload "$RP"
    }
}

function Rank-ValidationDataset {
    param (
        [Parameter(Mandatory=$true)][string] $RanklibDataset
    )
    $JarPath = Get-RanklibJarPath
    $RPath = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    $VPath = "$RPath\$ValidationFilename"
    foreach($ModelFile in (Get-ChildItem -Path $RPath -File -Filter $ModelFileFilter)){
        $ValidationScoreFilename = "$RPath\score_$($ModelFile.BaseName).dat"
        if(Test-Path -Path $ValidationScoreFilename){
            Write-Host "$($ModelFile.BaseName) score file already found. Skipping..."
            continue
        }
        java -jar $JarPath -load $($ModelFile.FullName) -rank $VPath -score $ValidationScoreFilename
    }
}