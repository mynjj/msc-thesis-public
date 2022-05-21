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

function Generate-EvaluationTables {
    $ComparisonConfigsDirPath = "$MSCDATA_DIR\evaluation\comparing-ranking-configurations"
    #...
#Results for Coordinate Ascent

#Comparison per dataset configs
#Dataset | Training Metric | NAPFD                     | Time to First Failure | 50-SEL          | ...
#                          | Av | Variance | Min | Max | ...                   | Size | ExecTime |

# Comparison across datasets
# Training metric | NAPFD | TFF   |
#                 | Av|Var| Av|Var|
}