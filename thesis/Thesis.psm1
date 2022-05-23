function Build-Thesis{
    param (
        [switch] $Clean
    )
    $OutDir = "$THESIS_SRC\out"
    $AuxDir = $OutDir
    if($Clean){
        Remove-Item -Path "$OutDir\*"
    }
    bibtex $OutDir\thesis
    pdflatex $THESIS_SRC\thesis.tex -output-directory $OutDir -aux-directory $AuxDir -shell-escape
}

function LongTable {
    param(
        [Parameter(Mandatory=$true)][int] $Cols,
        [string] $Caption = '',
        $Contents
    )
    "\begin{landscape}"
    "\begin{longtable}{|*{$Cols}{l|}}"
    "\caption{$Caption}"
    "\hline\endhead"
    "\hline\endfoot"
    Invoke-Command -ScriptBlock $Contents
    "\end{longtable}"
    "\end{landscape}"
}

function ShowFloat {
    param(
        [Parameter(Mandatory=$true, Position=0)][string] $Value
    )
    $CultureInvariant = New-Object System.Globalization.CultureInfo("")
    [math]::round(([float]$Value),2).ToString($CultureInvariant)
}
function ComparingRankingConfigurationTableContents {
    param (
        [Parameter(Mandatory=$true)][string] $FileName,
        [string] $Name = '',
        [string] $Caption
    )
    LongTable -Cols 8 -Caption $Caption -Contents {
        "\multirow{2}{*}{Dataset}&"
        "\multirow{2}{*}{Algorithm}&"
        "\multirow{2}{*}{Training metric}&"
        "\multirow{2}{*}{\# of trees}&"
        "\multicolumn{4}{c|}{$Name}\\"
        "&&&& Average & Variance & Minimum & Maximum \\\hline"
        $ComparisonConfigsDirPath = "$MSCDATA_DIR\evaluation\comparing-ranking-configurations"
        foreach($AlgComparison in Get-ChildItem -Path $ComparisonConfigsDirPath){
            $AlgName = $AlgComparison.BaseName -split "-" | Select-Object -First 1
            Import-CSV -Path "$($AlgComparison.FullName)\$FileName.csv" | %{
                "$($_.Configuration)&$AlgName&$($_.TrainingMetric)&$($_.Trees)&$(ShowFloat $_.Average)&$(ShowFloat $_.SampleVariance)&$(ShowFloat $_.Minimum)&$(ShowFloat $_.Maximum)\\"
            }
            "\hline"
        }
        "\hline"
    }
}

function InducedSelectionsTableContents {
    LongTable -Cols 10 -Caption "Selections induced by each configuration" -Contents {
        "\multirow{2}{*}{Dataset}&"
        "\multirow{2}{*}{Algorithm}&"
        "\multirow{2}{*}{Training metric}&"
        "\multirow{2}{*}{\# of trees}&"
        "\multicolumn{2}{c|}{\texttt{50-SEL}}&"
        "\multicolumn{2}{c|}{\texttt{80-SEL}}&"
        "\multicolumn{2}{c|}{\texttt{S-SEL}}\\"
        "&&&&Size&Execution Time&Size&Execution Time&Size&Execution Time\\"
         $ComparisonConfigsDirPath = "$MSCDATA_DIR\evaluation\comparing-ranking-configurations"
        foreach($AlgComparison in Get-ChildItem -Path $ComparisonConfigsDirPath){
            $AlgName = $AlgComparison.BaseName -split "-" | Select-Object -First 1
            $Details = Import-Csv -Path "$($AlgComparison.FullName)\TimeToFirstFailure.csv"|Select-Object -First 1
            Import-CSV -Path "$($AlgComparison.FullName)\Induced-Selections.csv" | %{
                $Config = $_.Dataset
                $SelectionSizes = $_
                $Row = "$Config&$AlgName&$($Details.TrainingMetric)&$($Details.Trees)"
                foreach($Selection in @("50-SEL", "80-SEL", "S-SEL")){
                    $Size = $SelectionSizes | Select-Object -ExpandProperty $Selection
                    $ExecutionTime = (Import-CSV -Path "$($AlgComparison.FullName)\Selection-$Size-SelectionExecutionTime.csv" | ?{$_.Configuration -eq $Config}).Average
                    $Row += "&$Size&$(ShowFloat $ExecutionTime)"
                }
                "$Row\\"
            }
            "\hline"
        }
        "\hline"
    }
}

function Generate-EvaluationTables {
    $OutDirPath = "$THESIS_SRC\figures\evaluation-tables"
    ComparingRankingConfigurationTableContents -Name "`$NAPFD`$" -FileName "Selection-100-NAPFD" -Caption "`$NAPFD`$ per dataset, algorithm and configuration" | Set-Content -Path "$OutDirPath\napfd-comparison.tex"
    ComparingRankingConfigurationTableContents -Name "`$t_{ff}`$" -FileName "TimeToFirstFailure" -Caption "`$t_{ff}`$ per dataset, algorithm and configuration" | Set-Content -Path "$OutDirPath\tff-comparison.tex"
    InducedSelectionsTableContents | Set-Content -Path "$OutDirPath\induced-selections.tex"
}