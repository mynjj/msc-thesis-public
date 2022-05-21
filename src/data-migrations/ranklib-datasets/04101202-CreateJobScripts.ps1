param (
    [Parameter(Mandatory=$true)][string] $DataDir
)

function Write-UnixFile {
    param (
        [Parameter(Mandatory=$true)][string] $FilePath,
        [Parameter(Mandatory=$true)][string] $Content
    )
    $Content -replace "`r`n","`n"|Set-Content -Path $FilePath -NoNewLine
}

$DatasetId = Split-Path -Path $DataDir -Leaf

$JobHeader = @"
#!/bin/bash

#SBATCH --cpus-per-task=24
#SBATCH --time=02:00:00
#SBATCH --partition=red,brown
#SBATCH --mem=115G
"@

$RanklibCommand = "java -Xmx110G -jar ranklib.jar"
$ToTrainParameters = @{
    'lambdamart-01' = "-ranker 6 -tree 30 -metric2t ""NDCG@10""";
    'lambdamart-02' = "-ranker 6 -tree 20 -metric2t ""NDCG@10""";
    'lambdamart-03' = "-ranker 6 -tree 10 -metric2t ""NDCG@10""";
    'lambdamart-04' = "-ranker 6 -tree 5 -metric2t ""NDCG@10""";
#    'lambdamart-05' = "-ranker 6 -tree 30";
#    'lambdamart-06' = "-ranker 6 -tree 20";
#    'lambdamart-07' = "-ranker 6 -tree 10";
#    'lambdamart-08' = "-ranker 6 -tree 5";
    'lambdamart-09' = "-ranker 6 -tree 30 -metric2t ""DCG@10""";
    'lambdamart-10' = "-ranker 6 -tree 20 -metric2t ""DCG@10""";
    'lambdamart-11' = "-ranker 6 -tree 10 -metric2t ""DCG@10""";
    'lambdamart-12' = "-ranker 6 -tree 5 -metric2t ""DCG@10""";
    'lambdamart-13' = "-ranker 6 -tree 30 -metric2t ""MAP""";
    'lambdamart-14' = "-ranker 6 -tree 20 -metric2t ""MAP""";
    'lambdamart-15' = "-ranker 6 -tree 10 -metric2t ""MAP""";
    'lambdamart-16' = "-ranker 6 -tree 5 -metric2t ""MAP""";
    'lambdamart-17' = "-ranker 6 -tree 30 -metric2t ""NDCG@20""";
    'lambdamart-18' = "-ranker 6 -tree 20 -metric2t ""NDCG@20""";
    'lambdamart-19' = "-ranker 6 -tree 10 -metric2t ""NDCG@20""";
    'lambdamart-20' = "-ranker 6 -tree 5 -metric2t ""NDCG@20""";
    'lambdamart-21' = "-ranker 6 -tree 30 -metric2t ""NDCG@30""";
    'lambdamart-22' = "-ranker 6 -tree 20 -metric2t ""NDCG@30""";
    'lambdamart-23' = "-ranker 6 -tree 10 -metric2t ""NDCG@30""";
    'lambdamart-24' = "-ranker 6 -tree 5 -metric2t ""NDCG@30""";
#    'rankboost-01' = "-ranker 2 -metric2t ""NDCG@10""";
#    'rankboost-02' = "-ranker 2 -metric2t ""DCG@10""";
#    'rankboost-03' = "-ranker 2 -metric2t ""MAP""";
#    'rankboost-04' = "-ranker 2 -metric2t ""NDCG@20""";
#    'rankboost-05' = "-ranker 2 -metric2t ""NDCG@20""";
#    'rankboost-06' = "-ranker 2 -metric2t ""NDCG@30""";
#    'adarank-01' = "-ranker 3 -metric2t ""NDCG@10""";
#    'adarank-02' = "-ranker 3 -metric2t ""DCG@10""";
#    'adarank-03' = "-ranker 3 -metric2t ""MAP""";
#    'adarank-04' = "-ranker 3 -metric2t ""NDCG@20""";
#    'adarank-05' = "-ranker 3 -metric2t ""NDCG@20""";
#    'adarank-06' = "-ranker 3 -metric2t ""NDCG@30""";
    'coordinateascent-01' = "-ranker 4 -metric2t ""NDCG@10""";
    'coordinateascent-02' = "-ranker 4 -metric2t ""DCG@10""";
    'coordinateascent-03' = "-ranker 4 -metric2t ""MAP""";
    'coordinateascent-04' = "-ranker 4 -metric2t ""NDCG@20""";
    'coordinateascent-05' = "-ranker 4 -metric2t ""NDCG@20""";
    'coordinateascent-06' = "-ranker 4 -metric2t ""NDCG@30""";
    'mart-01' = "-ranker 0 -tree 30 -metric2t ""NDCG@10""";
    'mart-02' = "-ranker 0 -tree 20 -metric2t ""NDCG@10""";
    'mart-03' = "-ranker 0 -tree 10 -metric2t ""NDCG@10""";
    'mart-04' = "-ranker 0 -tree 5 -metric2t ""NDCG@10""";
    'mart-05' = "-ranker 0 -tree 30";
    'mart-06' = "-ranker 0 -tree 20";
    'mart-07' = "-ranker 0 -tree 10";
    'mart-08' = "-ranker 0 -tree 5";
    'mart-09' = "-ranker 0 -tree 30 -metric2t ""DCG@10""";
    'mart-10' = "-ranker 0 -tree 20 -metric2t ""DCG@10""";
    'mart-11' = "-ranker 0 -tree 10 -metric2t ""DCG@10""";
    'mart-12' = "-ranker 0 -tree 5 -metric2t ""DCG@10""";
    'mart-13' = "-ranker 0 -tree 30 -metric2t ""MAP""";
    'mart-14' = "-ranker 0 -tree 20 -metric2t ""MAP""";
    'mart-15' = "-ranker 0 -tree 10 -metric2t ""MAP""";
    'mart-16' = "-ranker 0 -tree 5 -metric2t ""MAP""";
    'mart-17' = "-ranker 0 -tree 30 -metric2t ""NDCG@20""";
    'mart-18' = "-ranker 0 -tree 20 -metric2t ""NDCG@20""";
    'mart-19' = "-ranker 0 -tree 10 -metric2t ""NDCG@20""";
    'mart-20' = "-ranker 0 -tree 5 -metric2t ""NDCG@20""";
    'mart-21' = "-ranker 0 -tree 30 -metric2t ""NDCG@30""";
    'mart-22' = "-ranker 0 -tree 20 -metric2t ""NDCG@30""";
    'mart-23' = "-ranker 0 -tree 10 -metric2t ""NDCG@30""";
    'mart-24' = "-ranker 0 -tree 5 -metric2t ""NDCG@30""";
}

foreach($Algorithm in $ToTrainParameters.Keys){
    Write-UnixFile -FilePath "$DataDir\train_$Algorithm.job" -Content @"
$JobHeader
#SBATCH --job-name=rank-$DatasetId-$Algorithm
#SBATCH --output=$DatasetId/training-$Algorithm.out

$RanklibCommand $($ToTrainParameters[$Algorithm]) -train $DatasetId/training.dat -save $DatasetId/model_$Algorithm.xml
"@
}
