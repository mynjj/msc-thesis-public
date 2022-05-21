$RegisteredDatasets = @(
    "ci-history",
    "ci-stats",
    "ranklib-datasets",
    "line-coverage"
)
$MIG_METADATA_FILE = "mig-meta.csv"
$SRC_MIGRATIONS_DIR_PATH = "data-migrations"

function Apply-Migrations {
    param(
        [Parameter(Mandatory=$true)] [string] $Dataset
    )
    if(-not ($RegisteredDatasets -contains $Dataset)){
        throw "Unregistered dataset $Dataset"
    }
    InitializeDatasetMetadata -RegisteredDataset $Dataset
    $DatasetPath = "$MSCDATA_DIR\$Dataset"
    $DatasetMigrationScripts = (Get-ChildItem -Path "$MSCROOT\src\$SRC_MIGRATIONS_DIR_PATH\$Dataset" -Filter *.ps1) | Sort-Object -Property Name
    foreach($DataInstancePath in (Get-ChildItem -Path $DatasetPath -Directory).FullName) {
        $MetadataPath = "$DataInstancePath\$MIG_METADATA_FILE"
        $CurrentMetadata = Import-Csv -Path $MetadataPath
        if($null -eq $CurrentMetadata){
            $CurrentMetadata = @()
        }
        $CurrentMetadata = @($CurrentMetadata)
        foreach($MigrationScript in $DatasetMigrationScripts){
            if($CurrentMetadata.Script -contains $MigrationScript.Name){
                continue
            }
            Write-Host "Executing $MigrationScript for $DataInstancePath..."
            . $MigrationScript.FullName -DataDir $DataInstancePath
            $CurrentMetadata += New-Object PSObject -Property @{
                Script = $MigrationScript.Name;
            }
        }
        $CurrentMetadata | Export-Csv -Path $MetadataPath -NoTypeInformation -Force
    }
}

function InitializeDatasetMetadata {
    param(
        [Parameter(Mandatory=$true)] [string] $RegisteredDataset
    )
    $DatasetPath = "$MSCDATA_DIR\$RegisteredDataset"
    $DataPaths = (Get-ChildItem -Path $DatasetPath -Directory).FullName
    $null = $DataPaths |
        %{ 
            $MetaFilePath = "$($_)\$MIG_METADATA_FILE" 
            if (Test-Path -Path $MetaFilePath -PathType Leaf) {
                return
            }
            New-Item -ItemType File -Path $MetaFilePath
        }
}

function Initialize-DataMigrationsMetadata {
    foreach($RegisteredDataset in $RegisteredDatasets){
        InitializeDatasetMetadata -RegisteredDataset $RegisteredDataset
    }
}