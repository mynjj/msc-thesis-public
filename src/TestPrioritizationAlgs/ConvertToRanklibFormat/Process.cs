using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using TestPrioritizationAlgs;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    enum LearningDatasetType
    {
        Training,
        Validation
    }
    class RanklibRowWithMetadata
    {
        public RanklibRow RanklibRow { get; set; }
        public LearningDatasetType LearningDatasetType { get; set;  }
    }
    public class Process
    {
        private Configuration _configuration;
        private DataRepository _dataRepository;
        public void Start()
        {
            // Retrieve configuration
            _configuration = Configuration.GetConfiguration();
            _dataRepository = DataRepository.GetDataRepository(_configuration);
            // Get jobs to consider
            List<JobMetadata> jobs = _dataRepository.LoadJobs();
            // Generate ranklib output files for those jobs 
            GenerateRanklibOutput(jobs);
        }
        private void GenerateRanklibOutput(List<JobMetadata> jobs)
        {
            string outputDirName = DateTime.Now.ToString("yyMMddHHmmss");
            string outputDirPath = Path.Combine(_configuration.GetOutputFolder(), outputDirName);
            string outputMetaFilePath = Path.Combine(outputDirPath, "meta.xml");
            string fullRanklibFilePath = Path.Combine(outputDirPath, "full.dat");
            string trainingRanklibFilePath = Path.Combine(outputDirPath, "training.dat");
            string validationRankingFilePath = Path.Combine(outputDirPath, "validation.dat");
            string validationMetadataFilePath = Path.Combine(outputDirPath, "validation-metadata.dat");

            Directory.CreateDirectory(outputDirPath);
            _configuration.WriteConfig(outputMetaFilePath, jobs);

            using (var fullRanklibFileWriter = new StreamWriter(fullRanklibFilePath))
            using (var trainingRanklibFileWriter = new StreamWriter(trainingRanklibFilePath))
            using (var validationRankingFileWriter = new StreamWriter(validationRankingFilePath))
            using (var validationMetadataFileWriter = new StreamWriter(validationMetadataFilePath))
            {
                foreach (var ranklibRowWithMetadata in GetRanklibRows(jobs))
                {
                    var row = ranklibRowWithMetadata.RanklibRow.ToString();
                    fullRanklibFileWriter.WriteLine(row);
                    if (ranklibRowWithMetadata.LearningDatasetType == LearningDatasetType.Training)
                        trainingRanklibFileWriter.WriteLine(row);
                    else 
                    {
                        validationRankingFileWriter.WriteLine(row);
                        validationMetadataFileWriter.WriteLine(ranklibRowWithMetadata.RanklibRow.ValidationMetadata());
                    }
                }
            }
        }

        private IEnumerable<RanklibRowWithMetadata> GetRanklibRows(List<JobMetadata> jobs)
        {
            jobs.Sort((j1, j2)=>j1.Id.CompareTo(j2.Id));
            double tvRatio = _configuration.TrainingValidationRatio();

            int nFailedInTrainingSet = (int) Math.Ceiling(jobs.Where(j=>j.FailedAppTest).Count()*tvRatio);
            int failedCount = 0;
            string lastCoveragePath = "";
            Coverage coverage = new Coverage(lastCoveragePath);
            long timestamp;
            var nJobs = jobs.Count();
            for(int i=0; i < nJobs; i++)
            {
                var job = jobs[i];
                var testRuns = _dataRepository.GetJobAppTestRunResults(job).ToList();
                timestamp = new DateTimeOffset(DateTime.UtcNow).ToUnixTimeSeconds();
                Console.WriteLine($"{timestamp}: Starting loading coverage for job{job.Id} ({i+1}/{nJobs})");
                if (job.CoverageDirPath != lastCoveragePath)
                {
                    Console.WriteLine($"Flushing coverage: {job.CoverageDirPath}");
                    coverage = new Coverage(job.CoverageDirPath);
                }
                lastCoveragePath = job.CoverageDirPath;
                coverage.LoadLinesCovered(testRuns);
                timestamp = new DateTimeOffset(DateTime.UtcNow).ToUnixTimeSeconds();
                Console.WriteLine($"{timestamp}: Finished loading coverage");
                SortByPriority(testRuns);
                LearningDatasetType datasetType = LearningDatasetType.Training;
                if(job.FailedAppTest){
                    failedCount++;
                    if(failedCount > nFailedInTrainingSet){
                        datasetType = LearningDatasetType.Validation;
                    }
                }
                for(int j=0; j < testRuns.Count(); j++)
                {
                    var testRun = testRuns[j];
                    int priority = _configuration.GetPriority(testRun, j, testRuns.Count(), coverage, job);
                    var ranklibRow = new RanklibRow(testRun, priority);
                    ComputeRanklibRowFeatures(
                        ranklibRow, 
                        job,
                        testRun,
                        coverage
                    );
                    var r = new RanklibRowWithMetadata();
                    r.RanklibRow = ranklibRow;
                    r.LearningDatasetType = datasetType;
                    yield return r;
                }
            }
        }

        private void ComputeRanklibRowFeatures(RanklibRow ranklibRow, JobMetadata job, TestRun testRun, Coverage coverage)
        {
            var features = _configuration.GetTestRunFeatures();

            foreach(var feature in features)
                ranklibRow.Features.AddRange(feature.Compute(job, testRun, coverage));
        }

        public void SortByPriority(List<TestRun> testRuns)
        {
            testRuns.Sort((tr1, tr2)=>{
                if(tr1.TestRunResult == tr2.TestRunResult)
                    return (int)(tr2.TestProcedureDuration-tr1.TestProcedureDuration);
                if(tr1.TestRunResult == TestRunResult.Succeeded)
                    return -1;
                return 1;
            });
        }

    }
}