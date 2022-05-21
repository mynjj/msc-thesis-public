param (
    [Parameter(Mandatory=$true)][string] $DataDir
)

$Script:ExecutionModelPath = "$DataDir\execution-model.xml"
$Script:JobMetadataPath = "$DataDir\jobmetadata.csv"
$Script:JobTasksPath = "$DataDir\jobtasks.csv"
$Script:TestRunsDirPath = "$DataDir\TestRuns-Codeunit"

function SetJobMetadataFailedOnAppTest {
    param ([bool] $Value)
    $Metadata = Import-Csv -Path $Script:JobMetadataPath 
    $Metadata | Add-Member -MemberType NoteProperty -Name 'FailedAppTest' -Value $Value
    $Metadata | Export-Csv -Path $Script:JobMetadataPath -Force -NoTypeInformation
}

if(
    (-not (Test-Path -Path $script:ExecutionModelPath)) -or 
    (-not (Test-Path -Path $script:JobMetadataPath)) -or 
    (-not (Test-Path -Path $script:TestRunsDirPath)) -or 
    (-not (Test-Path -Path $script:JobTasksPath))){
    if(Test-Path -Path $script:JobMetadataPath){
        SetJobMetadataFailedOnAppTest -Value $false
    }
    exit
}
$AppTestTasks = ([xml](Get-Content -Path $script:ExecutionModelPath) | 
                    Get-XMLTaskNodes |
                    ?(FilterTasksByCategory -Category "AppTest")).Name

$FailedTasksAppTestTasks = @((Import-Csv -Path $script:JobTasksPath | ?{$_.Status -eq "Failed"}).TaskName) |
                            ?{$AppTestTasks -contains $_}

if($FailedTasksAppTestTasks.Count -eq 0){
    SetJobMetadataFailedOnAppTest -Value $false
    exit
}

foreach($Task in $FailedTasksAppTestTasks){
    if(Test-Path -Path "$script:TestRunsDirPath\$Task.csv"){
        SetJobMetadataFailedOnAppTest -Value $true
        exit
    }
}
SetJobMetadataFailedOnAppTest -Value $false
