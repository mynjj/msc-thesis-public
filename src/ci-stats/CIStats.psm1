$script:QueueName = "NAV.master_BuddyBuild"
$script:CIStatsPath = "$MSCROOT\data\ci-stats"


function JobFailedTaskNames {
    param(
        [Parameter(Mandatory=$true)] $Job
    )
    $Job | 
        Get-DMEJobTask -TaskStatus Failed |
        % {$_.TaskName} |
        Select-Object -Unique;
}
function JobStatsRawData {
    param (
        [Parameter(Mandatory=$true)] $Job
    )
    $Failed = $Job.Status -eq 'Failed'
    $FailedTasks = @()
    if($Failed){
        $FailedTasks = JobFailedTaskNames -Job $Job
    }
    New-Object PSObject -Property @{
        JobId = $Job.Id;
        Failed = $Failed;
        FailedTasks = $FailedTasks;
    }
}

function Get-CIStatsRawData {
    param (
        [Parameter(Mandatory=$true)][DateTime] $StartTime,
        [Parameter(Mandatory=$true)][DateTime] $EndTime
    )
    $global:dmecontext |
        Get-DMEJob -QueueName $QueueName -StartTime $StartTime -EndTime $EndTime |
        % {JobStatsRawData -Job $_}
}

function AppTestCategoryRegex {
    param(
        [Parameter(Mandatory=$true)][string]$Definition
    )
    "^$Definition$" -replace "{}",".+"
}

function AppTestCategory {
    param(
        [Parameter(Mandatory=$true)] $TaskName
    )
    $Category = $global:UNKNOWN_APPTESTCATEGORY
    foreach($Definition in $global:AppTestTasksCategories.Keys){
        if($TaskName -match $(AppTestCategoryRegex -Definition $Definition)){
            $Category = $global:AppTestTasksCategories[$Definition]
            break
        }
    }
    $Category
}

function JobStatsData {
    param (
        [Parameter(Mandatory=$true)] $JobRawData
    )
    $Failed = $JobRawData.Failed;
    $AppTestTasksFailed = @()
    if($Failed){
        $AppTestTasksFailed = @($JobRawData.FailedTasks | 
            ?{$script:AppTestTaskNames -contains $_} |
            %{New-Object PSObject -Property @{
                TaskName = $_;
                AppTestCategory = AppTestCategory -TaskName $_;
            }})
    }
    New-Object PSObject -Property @{
        JobId = $JobRawData.JobId;
        Failed = $Failed;
        AppTestTasksFailed = $AppTestTasksFailed;
    } 
}

function Convert-CIStatsRawData {
    param (
        [Parameter(Mandatory=$true)] $RawData
    )
    $JobsStatsData = $RawData | %{JobStatsData -JobRawData $_}
    $NTotal = $JobsStatsData.Count
    $NFailed = @($JobsStatsData | ?{$_.Failed -eq $true}).Count
    $NAppTestFailed = @($JobsStatsData | ?{$_.AppTestTasksFailed.Count -ne 0}).Count
    $AppTestCategoriesDistribution = $JobsStatsData | 
        %{
            $JobId = $_.JobId
            $_.AppTestTasksFailed|%{New-Object PSObject -Property @{
                JobId = $JobId;
                TaskName = $_.TaskName;
                AppTestCategory = $_.AppTestCategory;
            }
        }}
    $AppTestCategoriesCount = @($AppTestCategoriesDistribution | Group-Object -Property AppTestCategory -NoElement)
    $AppTestCategoryNames = $AppTestCategoriesCount.Name
    $AppTestTasksCountPerCategory = @{}
    foreach($CategoryName in $AppTestCategoryNames){
        $AppTestTasksCountPerCategory[$CategoryName] = $AppTestCategoriesDistribution | ?{$_.AppTestCategory -eq $CategoryName} | Group-Object -Property TaskName -NoElement
    }
    $AppTestTasksCount = $AppTestCategoriesDistribution | Group-Object -Property TaskName -NoElement

    New-Object PSObject -Property @{
        NTotal = $NTotal;
        NFailed = $NFailed;
        NAppTestFailed = $NAppTestFailed;
        FailedVsTotal = $NFailed/$NTotal;
        AppTestFailedVsFailed = $NAppTestFailed/$NFailed;
        AppTestCategoriesDistribution = $AppTestCategoriesDistribution;
        AppTestCategoriesCount = $AppTestCategoriesCount 
        AppTestTasksCount = $AppTestTasksCount
        AppTestTasksCountPerCategory = $AppTestTasksCountPerCategory
    }
}

function GetGNUPlotStub {
    param (
        [Parameter(Mandatory=$true)][string] $Stub,
        $Vars = @{}
    )
    $GNUPlotStubsDir = "$global:CISTATS_SRC\gnuplot-stubs"
    $Contents = Get-Content "$GNUPlotStubsDir\$stub"
    foreach($VarName in $Vars.Keys){
        $Contents = $Contents -replace "{$VarName}","$($Vars[$VarName])"
    }
    $Contents
}
function Save-CIStats {
    param(
        [Parameter(Mandatory=$true)] $StartTime,
        [Parameter(Mandatory=$true)] $EndTime,
        [Parameter(Mandatory=$true)] $StatsData,
        [Parameter(Mandatory=$true)] $RawData
    )
    $Id = Get-Date -UFormat %Y%m%d%H%M
    if(-not (Test-Path -Path $script:CIStatsPath -PathType Container)){
        New-Item -ItemType Directory -Path $script:CIStatsPath
    }
    $StatsOutputPath = "$script:CIStatsPath\$Id"
    New-Item -ItemType Directory -Path $StatsOutputPath
    # Metadata
    @"
StartTime,$StartTime
EndTime,$EndTime
"@ | Add-Content -Path "$StatsOutputPath\metadata.csv"
    # Raw data
    $RawData | 
        %{ New-Object PSObject -Property @{
            JobId = $_.JobId;
            Failed = $_.Failed;
            FailedTasks = $_.FailedTasks -join ","
        }}| Export-Csv -Path "$StatsOutputPath\rawdata.csv" -NoTypeInformation
    # Stats
    @"
NTotal,$($StatsData.NTotal)
NFailed,$($StatsData.NFailed)
NAppTestFailed,$($StatsData.NAppTestFailed)
FailedVsTotal,$($StatsData.FailedVsTotal)
AppTestFailedVsFailed,$($StatsData.AppTestFailedVsFailed)
"@ | Add-Content -Path "$StatsOutputPath\ci-failures-classif.csv"
    $StatsData.AppTestCategoriesDistribution | Export-Csv -Path "$StatsOutputPath\apptesttask-categories-distribution.csv" -NoTypeInformation
    $StatsData.AppTestCategoriesCount | Select-Object -Property Count,Name |Export-Csv -Path "$StatsOutputPath\apptesttask-categories-count.csv" -NoTypeInformation
    $StatsData.AppTestTasksCount | Select-Object -Property Count,Name | Export-Csv -Path "$StatsOutputPath\apptesttask-count.csv" -NoTypeInformation
    $StatsData.AppTestTasksCountPerCategory.Keys | 
        %{
            $CategoryName = $_
            $StatsForCategory = $StatsData.AppTestTasksCountPerCategory[$CategoryName]
            $StatsForCategory | %{
                New-Object PSObject -Property @{
                    CategoryName = $CategoryName;
                    TaskName = $_.Name;
                    Count = $_.Count;
                }
            }
        } | Export-Csv -Path "$StatsOutputPath\categories-apptesttask-distribution.csv" -NoTypeInformation
    # Plots
    ## CI Failures Classification
    $YHeight = $StatsData.NTotal * 1.2
    $Plot = "ci-failures-classif"
    $PlotFilename = "$Plot.plt" 
    GetGNUPlotStub -Vars @{"Y_HEIGHT" = $YHeight} -Stub $PlotFilename| Add-Content -Path "$StatsOutputPath\$PlotFilename"
    $DataFilename = "$Plot.dat"
    "$($StatsData.NTotal) $($StatsData.NFailed) $($StatsData.NAppTestFailed)" | Add-Content -Path "$StatsOutputPath\$DataFilename"
}
function Start-CIStatsCollection {
    param(
        [Parameter(Mandatory=$true)][DateTime] $StartTime,
        [Parameter(Mandatory=$true)][DateTime] $EndTime
    )
    $RawData = Get-CIStatsRawData -StartTime $StartTime -EndTime $EndTime
    $StatsData = Convert-CIStatsRawData -RawData $RawData
    try{
        Save-CIStats -StartTime $StartTime -EndTime $EndTime -StatsData $StatsData -RawData $RawData
    }
    catch {
        Write-Host "Error saving CI Stats: $_"
    }
    $StatsData
}


$script:AppTestTaskNames = Get-AppTestTasks

function Get-ModelNetworkData {
    param([Parameter(Mandatory=$true, ValueFromPipeline)][xml]$Xml)
    return New-Object PSObject -Property @{
        InitialNode = $Xml.root.Metadata.InitializeTask;
        FinalNode = $Xml.root.Metadata.FinalizeTask;
        Edges = Get-XMLTaskNodes -Xml $Xml |
            %{
                $To = $_.Name
                function Edge{
                    param($From)
                    return New-Object PSObject -Property @{
                        From = $From;
                        To = $To;
                    }
                }
                if($null -eq $_.Dependency){
                    return (Edge -From 'NONE')
                }
                $_.Dependency | 
                    %{Edge -From $_.Name}
            }|?{$_.From -ne 'NONE'}
    }
}

function Convert-NetworkDataToDotLang {
    param([Parameter(Mandatory=$true, ValueFromPipeline=$true)]$NetworkData)
    "digraph {"
    "    $($NetworkData.InitialNode) [shape=box];"
    "    $($NetworkData.FinalNode) [shape=box];"
    foreach($Edge in $NetworkData.Edges){
        $From = $Edge.From -replace "{|}",""
        $To = $Edge.To -replace "{|}",""
        "    $From -> $To;";
    }
    "}"
}