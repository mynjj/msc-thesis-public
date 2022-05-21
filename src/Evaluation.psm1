$ScoreFileFilter = "score*.dat"
$ValidationMetadataFilename = "validation-metadata.dat"
$RankedValidationMetadataFilter = "score*with_metadata.dat"
$EvaluationDataDir = "evaluation"
$InvalidDatasetTok = "INVALID DATASET"
$ComparingConfigurationsPath = "$MSCDATA_DIR\$EvaluationDataDir\comparing-ranking-configurations"

function New-RankedValidationSetFileContents
{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][string] $RanklibDataset,
        [Parameter(Mandatory=$true)][string] $ScoreFilePath
    )
    $RDir = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    $ValidationFilePath =  "$RDir\$ValidationMetadataFilename"
    if(-not (Test-Path -Path $ScoreFilePath)) {
        throw "Score file not found"
    }
    if(-not (Test-Path -Path $ValidationFilePath)) {
        throw "Validation metadata file not found"
    }
    $ScoreStreamReader = New-Object IO.StreamReader $ScoreFilePath
    $ValidationStreamReader = New-Object IO.StreamReader $ValidationFilePath
    $ValidScore = $true
    while((-not $ScoreStreamReader.EndOfStream) -or (-not $ValidationStreamReader.EndOfStream)){
        $ScoreLine = $ScoreStreamReader.ReadLine()
        $ValidationLine = $ValidationStreamReader.ReadLine()
        $Priority = $ScoreLine -split "`t"|Select-Object -Last 1
        if($Priority -eq "NaN"){
            $ValidScore = $false
            break
        }
        "$ValidationLine,Priority:$Priority"
    }
    $ScoreStreamReader.Close()
    $ValidationStreamReader.Close()
    if(-not $ValidScore){
        $InvalidDatasetTok
    }
}

function New-RankedValidationSetFiles
{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][string] $RanklibDataset
    )
    $RDir = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    foreach($ScoreFile in Get-ChildItem -Path $RDir -Filter $ScoreFileFilter -File){
        if($ScoreFile.BaseName -match "_with_metadata$"){
            continue
        }
        $OutputFilePath = "$RDir\$($ScoreFile.BaseName)_with_metadata.dat"
        if(Test-Path -Path $OutputFilePath){
            Write-Host "Validation set metadata with score values was already found for $($ScoreFile.BaseName). Skipping..."
            continue
        }
        $ShouldDeleteFile = $false
        New-RankedValidationSetFileContents -RanklibDataset $RanklibDataset -ScoreFilePath $($ScoreFile.FullName) |
            %{
                if($_ -eq $InvalidDatasetTok){
                    $ShouldDeleteFile = $true
                }
                $_
            } | Add-Content -Path $OutputFilePath
        if($ShouldDeleteFile){
            Write-Host "Invalid score found for $($ScoreFile.BaseName). Skipping..."
            Remove-Item -Path $OutputFilePath
        }
    }
}

function New-EvaluationFileContents {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][string] $RanklibDataset,
        [Parameter(Mandatory=$true)][string] $RankedValidationFilename
    )
    $RDir = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    $RankedValidationFilePath = "$RDir\$RankedValidationFilename"
    if(-not (Test-Path -Path $RankedValidationFilePath)){
        throw "Ranked validation file not found"
    }
    $Header = @((Get-Content $RankedValidationFilePath | Select-Object -First 1) -split "," | %{$_ -split ":"|Select-Object -First 1})
    if(-not ($Header -contains "JobId")){
        throw "Ranked validation file doesn't have the JobId property"
    }
    $RankedDataset = Import-CSV -Path $RankedValidationFilePath -Header $Header
    $JobTasks = $RankedDataset | Group-Object -Property JobId
    foreach($JobTaskGroup in $JobTasks){
        $TestRunResults = $JobTaskGroup.Group | %{
            $Data = @{}
            foreach($HeaderKey in $Header){
                $Value = ($_|Select-Object -ExpandProperty $HeaderKey) -split ':' | Select-Object -Last 1
                if(($HeaderKey -eq "Duration") -or ($HeaderKey -eq "Priority")){
                    $Value = [float] $Value
                }
                $Data[$HeaderKey] = $Value
            }
            New-Object PSObject -Property $Data
        }
        ComputeEvaluationMetrics -TestRunEvaluationDataset $TestRunResults
    }
}

function New-EvaluationFiles {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][string] $RanklibDataset
    )
    $RDir = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    foreach($RankedValidationFile in Get-ChildItem -Path $RDir -Filter $RankedValidationMetadataFilter){
        $EvaluationFilePath = "$RDir/evaluation-$($RankedValidationFile.Name)"
        if(Test-Path -Path $EvaluationFilePath){
            Write-Host "Evaluation file already file for $($RankedValidationFile.Name). Skipping..."
            continue
        }
        New-EvaluationFileContents -RanklibDataset $RanklibDataset -RankedValidationFilename $($RankedValidationFile.Name) | Export-CSV -Path $EvaluationFilePath -NoTypeInformation
    }
}

function ComputeEvaluationMetrics {
    param (
        [Parameter(Mandatory=$true)] $TestRunEvaluationDataset
    )
    if($null -eq $TestRunEvaluationDataset.Priority){
        throw "Priority property not found on ranked validation file"
    }
    if($null -eq $TestRunEvaluationDataset.Duration){
        throw "Duration property not found on ranked validation file"
    }
    if($null -eq $TestRunEvaluationDataset.Result){
        throw "Result property not found on ranked validation file"
    }
    $CultureInvariant = New-Object System.Globalization.CultureInfo("")
    $NTests = $TestRunEvaluationDataset.Count
    $Sorted = $TestRunEvaluationDataset | Sort-Object -Property "Priority" -Descending
    $TotalTime = ($TestRunEvaluationDataset.Duration | Measure-Object -Sum).Sum
    $NFailures = ($TestRunEvaluationDataset.Result | ?{$_ -eq "Failed"}).Count
    $Metrics = @{}
    $SelectionSize = [int] $NTests/10
    $Accumulated = @(0)*10 | %{New-Object PSObject -Property @{ExecutionTime = 0; NFailures = 0; FailedRanksSum = 0; SelectionSize = 0;}}
    $Index = 0
    $TimeToFirstFailure = $null
    foreach($TestRun in $Sorted){
        $AccIndex = [Math]::floor($Index/$SelectionSize)
        for ($i = $AccIndex; $i -lt $Accumulated.Count; $i++){
            $Accumulated[$i].ExecutionTime += $TestRun.Duration
            $Accumulated[$i].SelectionSize++
            if($TestRun.Result -eq "Failed"){
                if($null -eq $TimeToFirstFailure){
                    $TimeToFirstFailure = $Accumulated[$i].ExecutionTime
                }
                $Accumulated[$i].NFailures++
                $Accumulated[$i].FailedRanksSum += $Index
            }
        }
        $Index++
    }
    foreach($Index in @(0..9)){
        $Percentage = ($Index+1)*10
        $SelectionMetrics = $Accumulated[$Index]
        if($NFailures -eq 0){
            $Inclusiveness = "inf"
        }
        else {
            $Inclusiveness = $SelectionMetrics.NFailures/$NFailures
        }
        if($NFailures -eq 0){
            $NAPFD = "inf"
        }
        else {
            $DetectedFaultsP = $SelectionMetrics.NFailures/$NFailures
            $NAPFD = $DetectedFaultsP - $SelectionMetrics.FailedRanksSum/($NFailures*$SelectionMetrics.SelectionSize) + $DetectedFaultsP/(2*$SelectionMetrics.SelectionSize)
        }
        $SelectionExecutionTime = $SelectionMetrics.ExecutionTime/$TotalTime
        $Metrics["Selection-$Percentage-NAPFD"] = $NAPFD.ToString($CultureInvariant)
        $Metrics["Selection-$Percentage-Inclusiveness"] = $Inclusiveness.ToString($CultureInvariant)
        $Metrics["Selection-$Percentage-SelectionExecutionTime"] = $SelectionExecutionTime.ToString($CultureInvariant)
    }
    if($null -eq $TimeToFirstFailure){
        $Metrics.TimeToFirstFailure = 'inf'
    }
    else{
        $Metrics.TimeToFirstFailure = ($TimeToFirstFailure/$TotalTime).ToString($CultureInvariant)
    }
    New-Object PSObject -Property $Metrics
}

function Update-RanklibDatasetsWithEvaluation{
    (Get-ChildItem -Directory -Path $(Get-RanklibDataPath)).Name |
        %{
            New-RankedValidationSetFiles -RanklibDataset $_
            New-EvaluationFiles -RanklibDataset $_
        }
}

function Get-RankingEvaluationDatasetPath {
    param(
        [Parameter(Mandatory=$true)][string] $Dataset
    )
    "$MSCDATA_DIR\$EvaluationDataDir\per-ranking-configuration\$Dataset"
}

function ComputeMedian {
    param([Parameter(Mandatory=$true)] $Values)
    if(($Values.Count % 2) -eq 1){
        $Values[($Values.Count-1)/2]
    }
    else {
        ($Values[$Values.Count/2] + $Values[$Values.Count/2 - 1])/2
    }
}

function Generate-EvaluationDistributionMetrics {
    param (
        [Parameter(Mandatory=$true)][string] $Dataset
    )
    $CultureInvariant = New-Object System.Globalization.CultureInfo("")
    $DatasetDir = Get-RankingEvaluationDatasetPath -Dataset $Dataset
    $AlgDistributionMetrics = Get-ChildItem -Path $DatasetDir -Filter "*_jobs-metrics.csv" -File |%{
        $JobsMetrics = Import-CSV -Path $_.FullName
        $Metrics = ($JobsMetrics[0]|Get-Member -MemberType NoteProperty).Name
        if($_.BaseName -match "(?<algorithm>.+)_jobs-metrics"){
            $Algorithm = $Matches.algorithm
        }
        $PerMetric = @{}
        foreach($Metric in $Metrics){
            $DistributionValues = $JobsMetrics | Select-Object -ExpandProperty $Metric |%{[float]$_}| Sort-Object
            $Aggregate = $DistributionValues | Measure-Object -Average -Maximum -Minimum -Sum
            $Median = ComputeMedian -Values $DistributionValues
            $Q1 = ComputeMedian -Values $($DistributionValues | ?{$_ -le $Median})
            $Q3 = ComputeMedian -Values $($DistributionValues | ?{$_ -ge $Median})
            $SumDiffSq = 0
            foreach($Value in $DistributionValues){
                $SumDiffSq += ($Value - $Aggregate.Average)*($Value - $Aggregate.Average)
            }
            $SampleVariance = $SumDiffSq/($DistributionValues.Count - 1)
            $PerMetric[$Metric] = New-Object PSObject -Property $([ordered]@{
                Algorithm = $Algorithm;
                Average = $Aggregate.Average.ToString($CultureInvariant);
                SampleVariance = $SampleVariance.ToString($CultureInvariant);
                Maximum = $Aggregate.Maximum.ToString($CultureInvariant);
                Minimum = $Aggregate.Minimum.ToString($CultureInvariant);
                Sum = $Aggregate.Sum.ToString($CultureInvariant);
                Q1 = $Q1.ToString($CultureInvariant);
                Median = $Median.ToString($CultureInvariant);
                Q3 = $Q3.ToString($CultureInvariant);
                DistributionValues = $DistributionValues
            })
        }
        New-Object PSObject -Property $PerMetric
    }
    $Hyperparams = @{}
    foreach($Hyperparam in Import-Csv -Path "$MSCDATA_DIR\$EvaluationDataDir\hyperparams.csv"){
        $Hyperparams[$Hyperparam.Name] = $Hyperparam | Select-Object -Property * -ExcludeProperty Name
    }
    $HyperparamsHeader = ($Hyperparams.Values | Select-Object -First 1 | Get-Member -MemberType NoteProperty).Name
    foreach($Metric in ($AlgDistributionMetrics[0] | Get-Member -MemberType NoteProperty).Name){
        $AlgDistributionMetrics | Select-Object -ExpandProperty $Metric |
            Sort-Object -Property Average -Descending|
            %{
                foreach($HH in $HyperparamsHeader){
                    $_ | Add-Member -MemberType NoteProperty -Name $HH -Value $($Hyperparams[$_.Algorithm]|Select-Object -ExpandProperty $HH)
                }
                $_|Select-Object -Property * -ExcludeProperty DistributionValues
            }| Export-Csv -NoTypeInformation -Path "$DatasetDir\algorithm-comparison-$Metric.csv"
        $PerJobMetricValues = $null
        foreach($AlgorithmData in $AlgDistributionMetrics | Select-Object -ExpandProperty $Metric) {
            if($null -eq $PerJobMetricValues){
                $PerJobMetricValues = $AlgorithmData.DistributionValues | %{
                    @{$($AlgorithmData.Algorithm)=$_.ToString($CultureInvariant)}}
            }
            else {
                for($i = 0; $i -lt $PerJobMetricValues.Count; $i++){
                    $PerJobMetricValues[$i][$AlgorithmData.Algorithm] = $AlgorithmData.DistributionValues[$i].ToString($CultureInvariant)
                }
            }
        }
        $PerJobMetricValues | %{New-Object PSObject -Property $_} | Export-CSV -Path "$DatasetDir\distribution-comparison-$Metric.csv" -NoTypeInformation
    }
}


function Add-RanklibDatasetToEvaluationDataset {
    param(
        [Parameter(Mandatory=$true)][string] $RanklibDataset
    )
    $EvaluationDirPath = "$MSCDATA_DIR\$EvaluationDataDir"
    $EDir = "$EvaluationDirPath\per-ranking-configuration" 
    if(-not (Test-Path -Path $EvaluationDirPath)){
        $null = New-Item -Path $EvaluationDirPath -ItemType Directory
        $null = New-Item -Path $EDir -ItemType Directory
    }
    $EvaluationDatasetDirPath = Get-RankingEvaluationDatasetPath -Dataset $RanklibDataset
    if(Test-Path -Path $EvaluationDatasetDirPath){
        Write-host $EvaluationDatasetDirPath
        throw "Evaluation dataset for $RanklibDataset already exists"
    }
    $null = New-Item -Path $EvaluationDatasetDirPath -ItemType Directory
    $RDir = Get-RanklibDatasetPath -RanklibDataset $RanklibDataset
    Get-ChildItem -Path $RDir -Filter "evaluation-*" | %{
        $EvaluationNameString = $_.BaseName
        if(-not ($EvaluationNameString -match "evaluation-score_model_(?<algorithm>.+)_with_metadata")){
            throw "Invalid evaluation file: $EvaluationNameString"
        }
        $Alg = $Matches.algorithm
        Import-CSV -Path $_.FullName | 
            ?{$_."Selection-100-Inclusiveness" -ne "inf"} |
            Export-Csv -Path "$EvaluationDatasetDirPath\$($Alg)_jobs-metrics.csv" -NoTypeInformation
    }
    Generate-EvaluationDistributionMetrics -Dataset $RanklibDataset
    if(Test-Path -Path "$RDir\meta.xml"){
        [xml]$Metadata = Get-Content -Path "$RDir\meta.xml"
        $Name = $Metadata.root.name
        if($null -ne $Name){
            $Name | Set-Content -Path "$EvaluationDatasetDirPath\name"
        }
    }
}

function Generate-ComparisonEvaluationFiles {
    param(
        [switch] $ForceRegenerate
    )
    $EDir = "$MSCDATA_DIR\$EvaluationDataDir\comparing-ranking-configurations"
    if(-not (Test-Path -Path "$MSCDATA_DIR\$EvaluationDataDir")){
        throw "No evaluation datasets found"
    }
    if((Get-ChildItem -Path "$MSCDATA_DIR\$EvaluationDataDir\per-ranking-configuration" -Directory).Count -eq 0){
        throw "No evaluation datasets found"
    }
    if(Test-Path -Path $EDir){
        if($ForceRegenerate){
            Remove-Item -Path $EDir -Recurse
        }
        else{
            Remove-Item -Path $EDir -Recurse -Confirm
        }
    }
    $null = New-Item -Path $EDir -ItemType Directory
    Get-ChildItem -Path "$MSCDATA_DIR\$EvaluationDataDir\per-ranking-configuration" | %{
        $RankingConfiguration = $_
        $Name = $RankingConfiguration.BaseName
        if(Test-Path -Path "$($RankingConfiguration.FullName)\name"){
            $Name = Get-Content "$($RankingConfiguration.FullName)\name" | Select-Object -First 1
        }
        Get-ChildItem -Path $RankingConfiguration.FullName -File -Filter "algorithm-comparison-*" | %{
            $Vs = Import-CSV -Path $_.FullName
            if($_.BaseName -match "algorithm-comparison-(?<metric>.+)"){
                $Metric = $Matches.metric
            }
            $Vs | Add-Member -MemberType NoteProperty -Name Metric -Value $Metric
            $Vs | Add-Member -MemberType NoteProperty -Name Configuration -Value $Name
            $Vs
        }
    } | Group-Object -Property Algorithm | %{
        $AlgorithmDir = "$EDir\$($_.Name)" 
        $null = New-Item -Path $AlgorithmDir -ItemType Directory
        $_.Group | Group-Object -Property Metric | %{
            $_.Group | Export-CSV -NoTypeInformation -Path "$AlgorithmDir\$($_.Name).csv"
        }
    }
    Get-ChildItem -Path "$MSCDATA_DIR\$EvaluationDataDir\per-ranking-configuration" | %{
        $RankingConfiguration = $_
        $Name = $RankingConfiguration.BaseName
        if(Test-Path -Path "$($RankingConfiguration.FullName)\name"){
            $Name = Get-Content "$($RankingConfiguration.FullName)\name" | Select-Object -First 1
        }
        Get-ChildItem -Path $RankingConfiguration.FullName -File -Filter "distribution-comparison-*.csv" | %{
            $Vs = Import-CSV -Path $_.FullName
            if($_.BaseName -match "distribution-comparison-(?<metric>.+)"){
                $Metric = $Matches.metric
            }
            $Vs | Add-Member -MemberType NoteProperty -Name Metric -Value $Metric
            $Vs | Add-Member -MemberType NoteProperty -Name Configuration -Value $Name
            $Vs
        }
    } | Group-Object -Property Metric | %{
        $TSPMetricValues = $_.Group
        $Algs = ($TSPMetricValues | Select-Object -First 1 | Get-Member -MemberType NoteProperty).Name | ?{($_ -ne "Metric") -and ($_ -ne "Configuration")}
        foreach($Alg in $Algs){
            $FilePath = "$EDir\$Alg\distribution-comparison-$($_.Name).csv"
            $DistributionAcrossConfigurations = $null
            foreach($Configuration in $TSPMetricValues | Group-Object -Property Configuration){
                $ConfigId = $Configuration.Name
                if($null -eq $DistributionAcrossConfigurations){
                    $DistributionAcrossConfigurations = $Configuration.Group | Select-Object -ExpandProperty $Alg | %{@{$ConfigId=$_}}
                }
                else {
                    for($i=0; $i -lt $DistributionAcrossConfigurations.Count; $i++){
                        $DistributionAcrossConfigurations[$i][$ConfigId] = $Configuration.Group[$i] | Select-Object -ExpandProperty $Alg
                    }
                }
            }
            $DistributionAcrossConfigurations | %{New-Object PSObject -Property $_} |Export-CSV -Path $FilePath -NoTypeInformation
        }
    }
}

function Generate-DistributionBoxPlots {
    $EDir = "$MSCDATA_DIR\$EvaluationDataDir\per-ranking-configuration"    
    foreach($EvaluationDataset in Get-ChildItem -Path $EDir -Directory){
        foreach($MetricDistributionComparison in Get-ChildItem -Path $EvaluationDataset.FullName -Filter "distribution-comparison-*.csv"){
            if($MetricDistributionComparison.BaseName -match "distribution-comparison-(?<metric>.+)"){
                $Metric = $Matches.metric
            }
            $OutputFilePath = $MetricDistributionComparison.FullName -replace "csv","png"
            $Title = $Metric -replace '-',' '
            gnuplot -e "inputfilename='$($MetricDistributionComparison.FullName)';outputfilename='$OutputFilePath';plottitle='$Title';width=6500" "$SRCROOT\distribution-boxplots.plt"
        }
    }
    $EDir = "$MSCDATA_DIR\$EvaluationDataDir\comparing-ranking-configurations"
    foreach($Alg in Get-ChildItem -Path $EDir -Directory){
        foreach($MetricDistributionComparison in Get-ChildItem -Path $Alg.FullName -Filter "distribution-comparison-*.csv"){
            if($MetricDistributionComparison.BaseName -match "distribution-comparison-(?<metric>.+)"){
                $Metric = $Matches.metric
            }
            $OutputFilePath = $MetricDistributionComparison.FullName -replace "csv","png"
            $Title = $Metric -replace '-',' '
            gnuplot -e "inputfilename='$($MetricDistributionComparison.FullName)';outputfilename='$OutputFilePath';plottitle='$Title';width=550" "$SRCROOT\distribution-boxplots.plt"
        }
    }
}

function ComparisonSummaryContents {
    param(
        [Parameter(Mandatory=$true)][string] $TSPMetric
    )
    $CultureInvariant = New-Object System.Globalization.CultureInfo("")
    foreach($Alg in Get-ChildItem -Path $ComparingConfigurationsPath -Directory){
        "# $($Alg.Name)"
        $NAPFDAggregates = Import-CSV -Path "$($Alg.FullName)\$TSPMetric.csv"
        $InducedSelections = Import-CSV -Path "$($Alg.FullName)\Induced-Selections.csv"
        $SelectionsHeader = ($InducedSelections[0] | Get-Member -MemberType NoteProperty).Name | ?{$_ -ne "Dataset"}
        $SelectionsByDataset = @{}
        foreach($Selection in $InducedSelections){
            $SelectionsByDataset[$Selection.Dataset] = $Selection
        }
        $First = $NAPFDAggregates | Select-Object -First 1
        "**Training metric**: $($First.TrainingMetric)"
        ""
        if($First.Trees -ne ''){
            "**# of Trees**:$($First.Trees)"
        }
        ""
        "![comparison-$($Alg.Name)](./comparing-ranking-configurations/$($Alg.Name)/distribution-comparison-$TSPMetric.png)"
        ""
        "[Distribution values](./comparing-ranking-configurations/$($Alg.Name)/distribution-comparison-$TSPMetric.csv)"
        ""
        "| Dataset | Average | Sample variance | Min | Max |$(($SelectionsHeader|%{"Size $_ / Execution Time|"}) -join '')"
        "|-|-|-|-|-|$(($SelectionsHeader|%{"-|"}) -join '')"
        foreach($Aggregate in $NAPFDAggregates){
            $Config = $Aggregate.Configuration
            $SelectionsTableString = $SelectionsHeader | %{
                $Size = $SelectionsByDataset[$Config] | Select-Object -ExpandProperty $_
                $ExecutionTime = (Import-CSV -Path "$($Alg.FullName)\Selection-$Size-SelectionExecutionTime.csv" | ?{$_.Configuration -eq $Config}).Average
                "$Size / $ExecutionTime | "
            }
            "| $Config | $($Aggregate.Average) | $($Aggregate.SampleVariance) | $($Aggregate.Minimum) | $($Aggregate.Maximum) | $SelectionsTableString"
        }
        $AverageAverage = ($NAPFDAggregates | %{[float]$_.Average} | Measure-Object -Average).Average.ToString($CultureInvariant)
        $AverageVariance = ($NAPFDAggregates | %{[float]$_.SampleVariance} | Measure-Object -Average).Average.ToString($CultureInvariant)
        ""
        "**Average:** $AverageAverage"
        ""
        "**Average variance:** $AverageVariance"
    }
}

function Generate-ComparisonSummary {
    ComparisonSummaryContents -TSPMetric "Selection-100-NAPFD" | Set-Content -Path  "$MSCDATA_DIR\$EvaluationDataDir\comparison-summary-napfd.md"
    ComparisonSummaryContents -TSPMetric "TimeToFirstFailure" | Set-Content -Path  "$MSCDATA_DIR\$EvaluationDataDir\comparison-summary-timefirstfailure.md"
}

function Get-InducedSelectionsForRanking {
    param (
        [Parameter(Mandatory = $true)] $RankingAlgorithm
    )
    $AlgDirPath = "$ComparingConfigurationsPath\$RankingAlgorithm"
    $Increments = @(1..10)
    $PerDatasetSelectionSizes = @{}
    foreach($Increment in $Increments){
        $Percentage = $Increment*10
        $Filename = "Selection-$Percentage-Inclusiveness.csv"
        Import-CSV -Path "$AlgDirPath\$Filename" | %{
            $Dataset = $_.Configuration
            [int]$Max = $_.Maximum
            [int]$Min = $_.Minimum
            [float]$Av = $_.Average
            if(-not $PerDatasetSelectionSizes.Contains($Dataset)){
                $PerDatasetSelectionSizes[$Dataset] = [ordered]@{
                    "S-SEL" = $null;
                    "80-SEL" = $null;
                    "50-SEL" = $null;
                    Dataset = $Dataset;
                }
            }
            if($null -eq $PerDatasetSelectionSizes[$Dataset]."50-SEL"){
                if($Av -ge 0.5){
                    $PerDatasetSelectionSizes[$Dataset]."50-SEL" = $Percentage
                }
            }
            if($null -eq $PerDatasetSelectionSizes[$Dataset]."80-SEL"){
                if($Av -ge 0.8){
                    $PerDatasetSelectionSizes[$Dataset]."80-SEL" = $Percentage
                }
            }
            if($null -eq $PerDatasetSelectionSizes[$Dataset]."S-SEL"){
                if(($Min -eq $Max) -and ($Min -eq 1)){
                    $PerDatasetSelectionSizes[$Dataset]."S-SEL" = $Percentage
                }
            }
        }
    }
    $OutFilePath = "$AlgDirPath\Induced-Selections.csv" 
    if(Test-Path -Path $OutFilePath){
        Remove-Item $OutFilePath
    }
    $PerDatasetSelectionSizes.Values | 
        %{New-Object PSObject -Property $_} | 
        Export-CSV -Path $OutFilePath -NoTypeInformation
}

function Get-InducedSelections {
    foreach($AlgDir in Get-ChildItem -Path $ComparingConfigurationsPath -Directory){
        Get-InducedSelectionsForRanking -RankingAlgorithm $($AlgDir.Name)
    }
}