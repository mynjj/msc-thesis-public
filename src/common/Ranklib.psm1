$RanklibDatasetDir = "ranklib-datasets"

function Get-RanklibDataPath {
    "$MSCDATA_DIR\$RanklibDatasetDir"
}

function Get-RanklibDatasetPath {
    param(
        [Parameter(Mandatory=$true)][string] $RanklibDataset
    )
    "$(Get-RanklibDataPath)\$RanklibDataset"
}

function Get-RanklibDatasetNames {
    (Get-ChildItem -Path $(Get-RanklibDataPath) -Directory).Name
}