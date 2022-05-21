$script:QUEUE_NAME = "NAV.master_BuddyBuild"
$script:DatasetDir = "ci-history"
function Get-TestResultsForJobsInRange {
    param (
        [Parameter(Mandatory=$true)][DateTime] $StartTime,
        [Parameter(Mandatory=$true)][DateTime] $EndTime
    )
    Push-Location -Path $global:NAV
    git fetch --quiet
    Pop-Location
    $global:dmecontext | Get-DMEJob -StartTime $StartTime -EndTime $EndTime -QueueName $script:QUEUE_NAME |
        ?{ 
            $JobPath = Get-JobFolderPath -Dataset $DatasetDir -JobId $_.Id
            -not (Test-Path -Path $JobPath)
         } |
        %{ 
            try {
                $null = Get-TestResultsFromJobOutput -Job $_ -SkipGitFetch
            }
            catch {
                Write-Host "Failure for job $($_.Id). Skipping..."
                $JobFolderPath = Get-JobFolderPath -JobId $_.Id -Dataset $DatasetDir
                if(Test-Path -Path $JobFolderPath -PathType Container){
                    Remove-Item -Path $JobFolderPath -Recurse
                }
            }
        }
}

function Get-TestResultsFromJobOutput {
    [CmdletBinding()]
    param (
        [Parameter()][int] $JobId,
        [Parameter()] $Job,
        [switch] $SkipGitFetch
    )
    if($null -eq $Job){
        if($null -eq $JobId){
            throw "One of either Job or JobId parameters must be given."
        }
        $Job = $global:dmecontext | Get-DMEJob -JobId $JobId 
    }
    $QueueRegex = "^NAV\.(.+)_BuddyBuild$"
    if(-not ($Job.QueueName -match $QueueRegex)){
        throw "Only NAV BuddyBuild jobs supported."
    }
    # Retrieving execution model for this job
    [xml] $Model = Get-JobInputData -JobInputFolder $Job.CheckinFolder -FileName *.model.xml
    # Getting job data
    [xml] $JobData = Get-JobInputData -JobInputFolder $Job.CheckinFolder -FileName jobdata.xml
    # Getting AppTest tasks
    $AppTestTasks = @(Get-XMLTaskNodes -Xml $Model |
        ? (FilterTasksByCategory -Category 'AppTest')).Name
    $JobTasks = $Job | Get-DMEJobTask
    $JobAppTestTasks = $JobTasks | ?{$AppTestTasks -contains $_.TaskName}

    $Storage = Find-AzureJobStorageNameForJobId -JobId $Job.Id
    $Container = "job$($Job.Id)"
    $TracesInJobFolder = @(Get-AzureJobOutputContents -Storage $Storage -Container $Container -Pattern "*.traces.zip").Name

    $JobTmpPath = (Initialize-JobTmpFolder -JobId $Job.Id).FullName
    $JobPath = Initialize-JobFolder -JobId $Job.Id -Dataset $DatasetDir
    $TestRunsOutputPath = (New-Item -Path "$JobPath\TestRuns" -ItemType Directory).FullName
    Get-NAVMasterGitDiffs -CommitId $JobData.root.CommitId -SkipGitFetch:$SkipGitFetch -DirPath $JobPath
    $Model.Save("$JobPath\execution-model.xml")
    $JobData.Save("$JobPath\jobdata.xml")
    $FailedTracesTmpFolder = "$JobTmpPath\failed-traces"
    $null = New-Item -Path $FailedTracesTmpFolder -ItemType Directory
    $null = AzureLogs_DownloadFileSet -FileFilter "*.zip" -LogFolder $Job.LogFolder -Destination $FailedTracesTmpFolder

    $JobTasks | Select-Object -Property TaskName,Status,StartTime,EndTime,Duration | Export-Csv -Path "$JobPath\jobtasks.csv" -NoTypeInformation
    $Job | Select-Object -Property Id,Status,SubmitTime,ExecutionTime | Export-Csv -Path "$JobPath\jobmetadata.csv" -NoTypeInformation

    $TestResults = @{}
    foreach($JobAppTestTask in $JobAppTestTasks){
        $TaskFailed = ($JobAppTestTask.TaskStatus -eq 'Aborted') -or ($JobAppTestTask.TaskStatus -eq 'Failed')
        $Country = CountryForTaskName -TaskName $JobAppTestTask.TaskName
        $TaskName = $JobAppTestTask.TaskName.ToLower()
        $TmpOutputFolderPath = "$JobTmpPath\$TaskName"
        $TestOutputFolderPath = "$TmpOutputFolderPath\TestResults"
        if($TaskFailed){
            # Traces should be in job log folder
            $ZipPath = (Get-ChildItem -Path $FailedTracesTmpFolder -Filter "$TaskName*" | Select-Object -First 1).FullName
            if($null -eq $ZipPath){
                # This can happen with aborted tasks that didn't get to run twice before aborting
                continue
            }
            $null = Expand-Archive -Path $ZipPath -DestinationPath $TmpOutputFolderPath
        }
        else{
            # Traces should be in job output folder
            $TraceName = "$TaskName.traces.zip"
            if(-not ($TracesInJobFolder -contains $TraceName)){
                # This can happen when no test is executed because of churn selection
                continue
            }
            $null = Get-AzureJobOutput -FileName $TraceName -DestinationFolder $JobTmpPath -JobId $Job.Id -StorageAccount $Storage
            $ZipPath = "$JobTmpPath\$TraceName"
            $null = Expand-Archive -Path $ZipPath -DestinationPath $TmpOutputFolderPath
        }
        if(-not (Test-Path -Path $TestOutputFolderPath -PathType Container)){
            Write-Host "$TestOutputFolderPath not found in traces"
            Remove-Item -Path $ZipPath
            Remove-Item -Path $TmpOutputFolderPath -Recurse
            continue
        }
        $XmlFiles = Get-ChildItem -Path $TestOutputFolderPath -Filter "*.xml"
        $TrxFiles = Get-ChildItem -Path $TestOutputFolderPath -Filter "*.trx"
        if($XmlFiles.Count -ne 0) {
            $Output = $XmlFiles | % {ProcessXmlTestResults -File $_ -JobId $JobId -Country $Country}
        }
        elseif ($TrxFiles.Count -ne 0) {
            $Output = $TrxFiles | % {ProcessTrxTestResults -File $_ -JobId $JobId -Country $Country}
        }
        else {
            Write-Host "No XML or TRX files found on TestResults for $JobId-$TaskName"
            Remove-Item -Path $ZipPath
            Remove-Item -Path $TmpOutputFolderPath -Recurse
            continue
        }
        Remove-Item -Path $ZipPath
        Remove-Item -Path $TmpOutputFolderPath -Recurse
        $TestResults[$JobAppTestTask.TaskName] = $Output
        $Output | Export-Csv -Path "$TestRunsOutputPath\$($JobAppTestTask.TaskName).csv" -NoTypeInformation
    }
    $TestResults
}

function Get-NAVMasterGitDiffs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string] $CommitId,
        [Parameter(Mandatory=$true)][string] $DirPath,
        [switch] $SkipGitFetch
    )
    Push-Location -Path $Global:NAV
    if (-not $SkipGitFetch) {
        git fetch --quiet
    }
    $BranchCommits = git rev-list ^origin/master $CommitId
    if($LASTEXITCODE -ne 0){
        Pop-Location
        throw "Can't find git diff data"
    }
    $RecentMergeCommit = git rev-list ^origin/master $CommitId --merges -n 1
    if($RecentMergeCommit.Count -ne 0){
        $ChildCommit = $RecentMergeCommit
    }
    else {
        $ChildCommit = $BranchCommits | Select-Object -Last 1
    }
    $ParentCommits = $(git rev-list --parents -n 1 $ChildCommit) -split ' '
    $CommitToCompare = $ParentCommits |
        ?{-not ($BranchCommits -contains $_)} |
        Select-Object -First 1
    git diff --output "$DirPath\gitdiff-default.log" $CommitToCompare $CommitId 
    git diff --output "$DirPath\gitdiff-U0.log" -U0 --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId 
    git diff --output "$DirPath\gitdiff-raw.log" --raw --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId 
    git diff --output "$DirPath\gitdiff-numstat.log" --numstat --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId 
    git diff --output "$DirPath\gitdiff-dirstat.log" --dirstat --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId 
    git diff --output "$DirPath\gitdiff-namestatus.log" --name-status --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId 

    $FilesToCopyAfter = $(git diff --diff-filter=AM --name-only --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId) | ?{$_ -like "*.al"}
    $FilesToCopyBefore = $(git diff --diff-filter=MD --name-only --ignore-space-change --ignore-blank-lines $CommitToCompare $CommitId) | ?{$_ -like "*.al"}
    $ChangedFilesDirPath = "$DirPath\NAV-after"
    if(Test-Path -Path $ChangedFilesDirPath -PathType Container){
        Remove-Item -Path $ChangedFilesDirPath -Recurse
    }
    $FilesBeforeDirPath = "$DirPath\NAV-before"
    if(Test-Path -Path $FilesBeforeDirPath -PathType Container){
        Remove-Item -Path $FilesBeforeDirPath -Recurse
    }

    git checkout $CommitId --quiet
    CopyFilesFromNAVRepo -FilesToCopy $FilesToCopyAfter -DestDirPath $ChangedFilesDirPath

    git checkout $CommitToCompare --quiet
    CopyFilesFromNAVRepo -FilesToCopy $FilesToCopyBefore -DestDirPath $FilesBeforeDirPath

    foreach($FileToCopy in $FilesToCopy){
        $DirStructure = Split-Path -Path $FileToCopy
        $Filename = Split-Path -Path $FileToCopy -Leaf
        $NewFile = "$ChangedFilesDirPath\$DirStructure\$Filename" 
        $null = New-Item -Path $NewFile -ItemType File -Force
        $null = Copy-Item $FileToCopy $NewFile -Force
    }
    Pop-Location
}

function CopyFilesFromNAVRepo {
    param(
        $FilesToCopy,
        $DestDirPath
    )
    foreach($FileToCopy in $FilesToCopy){
        $DirStructure = Split-Path -Path $FileToCopy
        $Filename = Split-Path -Path $FileToCopy -Leaf
        $NewFile = "$DestDirPath\$DirStructure\$Filename" 
        $null = New-Item -Path $NewFile -ItemType File -Force
        $null = Copy-Item $FileToCopy $NewFile -Force
    }
}

function TestResultTextToStatus {
    param([string] $Result)
    switch ($Result) {
        "Pass" { 1 }
        "Passed" { 1 }
        "Inconclusive" { 2 }
        Default { 0 }
    }
}

function TimeStringToSeconds {
    param(
        [string] $TimeString
    )
    $h, $m, $s = ($TimeString -split ':') | %{ [float]$_ }
    $h*3600 + $m*60 + $s
}

function ProcessTrxTestResults {
    param (
        [System.IO.FileInfo] $File,
        [int] $JobId,
        [string] $Country
    )
    [xml] $TestResultsContents = Get-Content -Path $File.FullName
    $OutputContents = @()
    try {
        $TestResultsContents.TestRun.Results.UnitTestResult | % {
            $TestLastRun = $_.startTime
            $_.InnerResults.UnitTestResult | % {
                $Details = $_.Output.StdOut -split '\n'
                $TestCodeunitId, $ProcedureName, $TestProcedureDuration, $Result = $null, $null, $null, $null
                $Details | %{
                    $key, $value = ($_ -split ':') | % {$_.Trim()}
                    $key = $key.ToLower()
                    $value = $value -join ':'
                    switch ($key){
                        "result" { $Result = TestResultTextToStatus -Result $($value.ToLower())}
                        "cuid" { $TestCodeunitId = [int]$value}
                        "fname" { $ProcedureName = $value }
                        "execution time"{ $TestProcedureDuration = TimeStringToSeconds -TimeString $value}
                    }
                }
                if(($null -eq $TestCodeunitId) -or ($null -eq $ProcedureName) -or ($null -eq $Result) -or ($null -eq $TestProcedureDuration)){
                    return
                }
                $OutputContents += New-Object PSObject -Property @{
                    Country = $Country;
                    TestCodeunitId = $TestCodeunitId;
                    ProcedureName = $ProcedureName;
                    TestLastRun = $TestLastRun;
                    TestProcedureDuration = $TestProcedureDuration;
                    Result = $Result;
                }
            }
        }
    } 
    catch {
        Write-Host "Unable to process TRX test results of job $JobId. Error: $_"
    }
    return $OutputContents
}

function ProcessXmlTestResults {
    param (
        [System.IO.FileInfo] $File,
        [int] $JobId,
        [string] $Country
    )
    [xml] $TestResultsContents = Get-Content -Path $File.FullName
    $OutputContents = @()
    try{
        $TestResultsContents.assemblies.assembly | % {
            [int] $TestCodeunitId = $_."x-code-unit"
            [string] $TestLastRun = "$($_."run-date")T$($_."run-time").0000000"
            if($_.collection.test.Count -eq 0){
                return
            }
            $_.collection.test | % {
                [float] $TestProcedureDuration = $_.time
                $ProcedureName = $_.method
                $Result = TestResultTextToStatus -Result $_.result
                $OutputContents += New-Object PSObject -Property @{
                    Country = $Country;
                    TestCodeunitId = $TestCodeunitId;
                    ProcedureName = $ProcedureName;
                    TestLastRun = $TestLastRun;
                    TestProcedureDuration = $TestProcedureDuration;
                    Result = $Result;
                }
            }
        }
    }
    catch {
        Write-Host "Unable to process XML test results of job $JobId. Error: $_"
    }
    $OutputContents
}

function TaskMatchRegex {
    param (
        [string] $TaskName
    )
    "^$($TaskName -replace '{[^}]*}', '(.*)')$"
}

function Move-InvalidCIHistoryJobs {
    if ($null -eq $Env:POLLUTED_CIHISTORY_DIR){
            throw "Set environment variable POLLUTED_CIHISTORY_DIR"
    }
    if ($null -eq $Env:NO_TESTS_CIHISTORY_DIR){
            throw "Set environment variable NO_TESTS_CIHISTORY_DIR"
    }

    Get-ChildItem -Path "$Env:MSC_DATA_PATH\$DatasetDir" |
        ?{-not (Test-Path -Path "$($_.FullName)\jobmetadata.csv")}|
        %{Move-Item -Path "$($_.FullName)" -Destination $Env:POLLUTED_CIHISTORY_DIR }

    Get-ChildItem -Path "$Env:MSC_DATA_PATH\$DatasetDir" |
        ?{Test-Path -Path  "$($_.FullName)\TestRuns" -PathType Container} |
        ?{(Get-ChildItem -Path "$($_.FullName)\TestRuns").Count -eq 0} |
        %{Move-Item -Path "$($_.FullName)" -Destination $Env:NO_TESTS_CIHISTORY_DIR }
}

<#
function DependenciesExplorer {
    $Tasks = @{}
    $null = Get-MetaModel |
        Get-XmlTaskNodes |
        ? (FilterTasksByCategory -Category "AppTest") |
        % {
            $TaskNode = $_
            $TasksToVisit = $TaskNode.Dependency.Name
            $Visited = @()
            $OpEdges = @{}
            while($TasksToVisit.Count -ne 0){
                $NextToVisit,$TasksToVisit = $TasksToVisit
                $ToVisit = Get-MetaModel | Get-XmlTaskNodes | ?{$_.Name -eq $NextToVisit} | Select-Object -First 1
                if($Visited -contains $ToVisit.Name){
                    continue
                }
                
                if($null -ne $ToVisit.Dependency.Name){
                    $TasksToVisit += $ToVisit.Dependency.Name | %{
                        $Dep = $_
                        if($OpEdges.Contains($Dep)){
                            $OpEdges[$Dep] += $ToVisit.Name
                        }
                        else{
                            $OpEdges.add($Dep, @(,$ToVisit.Name))
                        }
                        $Dep
                    }
                }
                $Visited += $ToVisit.Name
            }
            $Visited
            $Tasks[$TaskNode.Name] = $Visited
        }
    return $Tasks
}
#>

