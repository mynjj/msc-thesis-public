# Optimizing the CI pipeline of Business Central with Test Selection and Prioritization techniques

Accompanying repository for the [thesis](./thesis/out/thesis.pdf). It contains the code for the different stages described in the written report; namely: collection of CI job data, collection of coverage information, extracting change features and prioritizing training datasets, execution of training of the different ranking algorithms, scoring the validation dataset, and extraction of evaluation metrics.

It also contains other metainformation of the project.

The folder `data` is the workspace of the different stages executed in the project. The complete collected dataset of raw CI jobs and coverage jobs is too large to store, instead just excerpts of this folders are included. The `data/evaluation` dataset is included fully. The `data/ranklib-datasets` is included zipped. If you want to run and define your own `data` folders, set the environment variable `$Env:MSC_DATA_PATH` and follow the remaining instructions in this README.

## Setting up

See `env.dist.ps1` for an example of environment variables that should be defined prior to running the `init.ps1` script. You can copy this file into a gitignored `env.ps1` file for your configurations.

```
.\env.ps1
.\init.ps1
```

If you are not running anything related to the NAV repository (for example CI collection of jobs), you can use:
```
.\init.ps1 -SkipNAVEnlistment
```

The initialization script will provide a set of Cmdlets for the different stages of the project.

## Project stages

### Collecting CI data and line coverage
This stage should be run on a DevVM or on the CorpVPN.

#### Collecting CI Jobs data
To collect a specific job with id `$JobId`:
```
Get-TestResultsFromJobOutput -JobId $JobId
```

To collect all jobs in a given date range:
```
$StartTime = (Get-Date).AddDays(-1.5)
$EndTime = (Get-Date).AddHours(-3)
Get-TestResultsForJobsInRange -StartTime $StartTime -EndTime $EndTime
```

See examples of collected jobs in `data/ci-history`

*Note*: The script gets the contents of files changed by switching to the corresponding commit. So the branch corresponding to the job must exist, which may not be the case for old jobs (as old jobs may already be merged and had their source branch deleted). It's best to collect recent jobs

#### Collecting line coverage
Currently the remote branch in the NAV repository: `private/t-dimartinez/msc-thesis` has the required changes on the `ALTestRunner` to collect per codeunit coverage information for all tasks.

To collect line coverage information per codeunit at a given time it's first recommended to update all changes from `master`:
```
git checkout private/t-dimartinez/msc-thesis
git pull origin master
git push
```

Afterwards, schedule a DME job that runs all tests:
```
Submit-NavChangeSet -DisableIncremental
```

After the job is finished (around 80 minutes), run the following to collect per codeunit line coverage in the `data` folder:
```
Get-CoveragePerCodeunitForJob -JobId $JobId
```
Where `$JobId` is the scheduled job with modifications. See `data/line-coverage` for examples.

### Transformations and additions to collected data

When collecting, some jobs can't be used for later stages. Use the following command to move them to other directories:
```
Move-InvalidCIHistoryJobs
```

After information is collected, use:
```
Apply-Migrations -Dataset "ci-history"
```

This will add information on the collected data (where it hasn't been run before), for benefit of later stages. Currently it:
- Adds `TestRuns-Codeunit` which has test information with less granularity.
- Adds a property to `jobmetadata.csv` to determine whether or not this job failed on a test, whose result was collected.

Also run:
```
Apply-Migrations -Dataset "line-coverage"
```
To remove downloaded duplicates.

### Generate Ranklib training and validation file

Currently this is done by running the `TestPrioritizationAlgs` solution in Visual Studio, and configuring the different features computed in `Configuration.cs`. It was meant for it to be a PS Cmdlet, but it's currently not a priority.

This stage generates a new folder with:
- `meta.xml`: Information about how the files where computed (which jobs were considered, which features where used, method to assign priorities, among others).
- `full.dat`: LETOR file format with all runs considered.
- `train.dat`: Subset of `full.dat` to be used for training the ranking algorithms.
- `validation.dat`: Subset of `full.dat` for validation of the ranking algorithms.
- `validation-metadata.dat`: CSV-like file with information to identify each row on `validation.dat` and information to be used for evaluation.

Using the `Release` configuration, this stage takes around 1.5 hours (an i7(7th gen), non SSD) and 11GB of RAM.

See the dataset used for the project zipped in `data/ranklib-datasets`

### Add information to the Ranklib dataset

Add information on each of the generated ranklib datasets:
```
Apply-Migrations -Dataset "ranklib-datasets"
```
Currently it:
- Generates job scripts to be used for submitting the training job to the HPC

### Train the ranker
Training is done on ITU's HPC. Be sure to use ITU's VPN.

To upload training data and submit training jobs to the HPC, for a specific dataset, you can use:
```
Train-RanklibDataset -RanklibDataset $RanklibDataset
```

After the job on the HPC is done, you can use:
```
Download-TrainedModels -RanklibDataset $RanklibDataset
```
To download the model files which can be used to rank the validation dataset.

This stage outputs `model*.xml` files for each ranklib dataset

### Use the trained model to rank the validation set

```
Rank-ValidationDataset -RanklibDataset $RanklibDataset
```
Ranks the validations datasets with the downloaded models.

This stage outputs `score_*.dat` files with the result of ranking the validation set.

### Get evaluation metrics for the result

Given a `ranklib-dataset` with a score file, you can produce evaluation metrics with:
```
New-RankedValidationSetFiles -RanklibDataset $RanklibDataset
New-EvaluationFiles -RanklibDataset $RanklibDataset
```
The first command creates validation files with the ranking of the different models from the previous stage and metadata taken from `validation-metadata`. The second one uses this file to output evaluation metrics

Where `$RanklibDataset` is the desired ranklib dataset in this stage. To do it to every job for which this is applicable you can run:
```
Update-RanklibDatasetsWithEvaluation
```

This produces `evaluation-*.csv` files with the different Test Selection and Prioritization metrics.

See `data/ranklib-datasets` for examples.

```
Add-RanklibDatasetToEvaluationDataset -RanklibDataset $RanklibDataset
```
Moves evaluation files to the `evaluation` data folder, collecting distribution measures (mean, median, etc.)

To generate comparison between the different ranking configurations use:
```
Generate-ComparisonEvaluationFiles
```
See the output in `data/evaluation/comparing-ranking-configurations`

To generate plots, and other files to use the evaluation results, use:
```
Generate-DistributionBoxPlots
Get-InducedSelections
Generate-ComparisonSummary
```