param (
    [Parameter(Mandatory=$true)][string] $DataDir
)

$TestRunsDirPath = "$DataDir\TestRuns"
if(-not (Test-Path -Path $TestRunsDirPath -PathType Container)){
    exit
}

$NewTestRunsDirPath = "$DataDir\TestRuns-Codeunit"
if(Test-Path -Path $NewTestRunsDirPath){
    Remove-Item -Path $NewTestRunsDirPath -Recurse
}

$null = New-Item -Path $NewTestRunsDirPath -ItemType Directory
foreach($CsvFile in $(Get-ChildItem -Path $TestRunsDirPath -Filter *.csv)){
    $NewCsvFilePath = "$NewTestRunsDirPath\$($CsvFile.Name)"
    $PerProcedureResults = Import-Csv -Path $CsvFile.FullName
    $PerProcedureResults | Group-Object -Property TestCodeunitId | %{
        [int] $TestCodeunitId = $_.Name
        [float]$TestProcedureDuration = ($_.Group.TestProcedureDuration | %{[float]($_ -replace ',','.')} | Measure-Object -Sum).Sum
        $Result = 1
        foreach($Run in $_.Group){
            if(([int]$Run.Result) -eq 0){
                $Result = 0
            }
        }
        $TestLastRun = ($_.Group | Select-Object -First 1).TestLastRun
        $Country = ($_.Group | Select-Object -First 1).Country
        New-Object PSObject -Property @{
            TestCodeunitId = $TestCodeunitId;
            TestProcedureDuration = $TestProcedureDuration;
            Result = $Result;
            TestLastRun = $TestLastRun;
            Country = $Country
        }
    } | Export-Csv -NoTypeInformation -Path $NewCsvFilePath
}
