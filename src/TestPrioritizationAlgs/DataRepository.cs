using System;
using System.Text.RegularExpressions;
using System.IO;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using TestPrioritizationAlgs.CSVReaders;
using CsvHelper;

namespace TestPrioritizationAlgs {
    public class DataRepository
    {
        static private DataRepository _dataRepository;
        private Configuration _configuration;
        private List<JobMetadata> _jobs;
        private List<int> _coverageJobIds;

        private DataRepository(Configuration configuration)
        {
            _configuration = configuration;
        }

        public static DataRepository GetDataRepository(Configuration configuration)
        {
            if(_dataRepository==null)
            {
                _dataRepository = new DataRepository(configuration);
            }
            return _dataRepository;
        }

        private void loadCoverageJobIds(){
            _coverageJobIds = Directory
                        .EnumerateDirectories(_configuration.GetCoverageDirPath(), "job*")
                        .Select(coverageDir => GetJobIdFromPath(coverageDir))
                        .ToList();
            _coverageJobIds.Sort((v1, v2)=>v2.CompareTo(v1));
        }
        private string getCoverageDirPath (int coverageJobId){
            return Path.Combine(_configuration.GetCoverageDirPath(), $"job{coverageJobId}");
        }
        private void setCoverageDirPath(JobMetadata job){
            // If while traversing coverage jobs, a previous one to this
            // job is not found, then the oldest one is used
            job.CoverageDirPath = getCoverageDirPath(_coverageJobIds.Last());
            foreach(var coverageJobId in _coverageJobIds)
            {
                if (coverageJobId < job.Id)
                {
                    job.CoverageDirPath = getCoverageDirPath(coverageJobId);
                    break;
                }
            }
        }

        private void collectNameStatusInChange(string namestatusPath, Dictionary<string, ALFileChange> changedALFiles, Dictionary<string, NonALFileChange> changedNonALFiles, string NAVBeforeDirPath, string NAVAfterDirPath)
        {
            using(var namestatusReader = new StreamReader(namestatusPath))
            {
                string statusLine;
                while((statusLine = namestatusReader.ReadLine()) != null)
                {
                    var status = statusLine.Split('\t');
                    if(status.Length != 2)
                        continue;
                    var changeType = status[0];
                    var changedFilePath = status[1];
                    FileOperation fileOperation;
                    if(changeType == "A")
                        fileOperation = FileOperation.Added;
                    else if(changeType == "M")
                        fileOperation = FileOperation.Modified;
                    else if(changeType == "D")
                        fileOperation = FileOperation.Deleted;
                    else 
                        continue;

                    if(!isALFilePath(changedFilePath)){
                        var nonALFileChange = new NonALFileChange();
                        nonALFileChange.FileOperation = fileOperation;
                        nonALFileChange.Path = changedFilePath;
                        changedNonALFiles.Add(changedFilePath, nonALFileChange);
                    }
                    else {
                        var alFileChange = new ALFileChange();
                        alFileChange.FileOperation = fileOperation;
                        alFileChange.Path = changedFilePath;
                        if (alFileChange.FileOperation == FileOperation.Added || alFileChange.FileOperation == FileOperation.Modified)
                        {
                            parseFileChange(alFileChange, NAVAfterDirPath);
                        }
                        else
                        {
                            parseFileChange(alFileChange, NAVBeforeDirPath);
                        }
                        changedALFiles.Add(changedFilePath, alFileChange);
                    }
                }
            }

        }
        private void collectNumStatInChange(string numstatPath, Dictionary<string, ALFileChange> changedALFiles)
        {
            using(var numstatReader = new StreamReader(numstatPath))
            {
                string numstatLine;
                while((numstatLine = numstatReader.ReadLine()) != null)
                {
                    var stats = numstatLine.Split('\t');
                    if(stats.Length != 3){
                        continue;
                    }
                    if(!changedALFiles.ContainsKey(stats[2])){
                        continue;
                    }
                    var fileChange = changedALFiles[stats[2]];
                    fileChange.NAddedLines = int.Parse(stats[0]);
                    fileChange.NDeletedLines = int.Parse(stats[1]);
                }
            }
 
        }

        private void collectDiffU0InChange(string diffU0Path, Dictionary<string, ALFileChange> changedALFiles)
        {
            using(var reader = new StreamReader(diffU0Path))
            {
                string line;

                ALFileChange changedALFile = null;
                while ((line = reader.ReadLine()) != null)
                {
                    var regex = new Regex(@"diff --git a/(?<file1>.*)\sb/(?<file2>.*)");
                    var match = regex.Match(line);
                    if(match.Success){
                        if(changedALFiles.ContainsKey(match.Groups["file1"].Value))
                            changedALFile = changedALFiles[match.Groups["file1"].Value];
                        else if(changedALFiles.ContainsKey(match.Groups["file2"].Value))
                            changedALFile = changedALFiles[match.Groups["file2"].Value];
                        else
                            changedALFile = null;
                        continue;
                    }
                    regex = new Regex(@"@@\s\-(?<before>[\d,]+)\s\+(?<after>[\d,]+)\s@@");
                    match = regex.Match(line);
                    Func<string, (int, int)> hunkDetails = hunkHead => {
                        var parts = hunkHead.Split(',');
                        if(parts.Length == 1)
                            return (int.Parse(parts[0]), 1);
                        return (int.Parse(parts[0]), int.Parse(parts[1]));
                    };
                    if((changedALFile != null) && match.Success){
                        ALLineChange lineChange = new ALLineChange();
                        lineChange.BeforeLineAndCount = hunkDetails(match.Groups["before"].Value);
                        lineChange.AfterLineAndCount = hunkDetails(match.Groups["after"].Value);
                        changedALFile.LineChanges.Add(lineChange);
                    }
                }
            }
        }

        private void loadFileChanges(JobMetadata job)
        {
            var NAVBeforeDirPath = Path.Combine(job.DirPath, "NAV-before");
            var NAVAfterDirPath = Path.Combine(job.DirPath, "NAV-after");
            if((!Directory.Exists(NAVBeforeDirPath))&&(!Directory.Exists(NAVAfterDirPath))){
                job.ALFileChanges = new List<ALFileChange>();
                job.NonALFileChanges = new List<NonALFileChange>();
                return;
            }
            var numstatPath = Path.Combine(job.DirPath, "gitdiff-numstat.log");
            var namestatusPath = Path.Combine(job.DirPath, "gitdiff-namestatus.log");
            var diffU0Path = Path.Combine(job.DirPath, "gitdiff-U0.log");
            if(!(File.Exists(numstatPath)&&File.Exists(namestatusPath)&&File.Exists(diffU0Path))){
                job.ALFileChanges = new List<ALFileChange>();
                job.NonALFileChanges = new List<NonALFileChange>();
                return;
            }
            Dictionary<string, ALFileChange> changedALFiles = new Dictionary<string, ALFileChange>();
            Dictionary<string, NonALFileChange> changedNonALFiles = new Dictionary<string, NonALFileChange>();
            collectNameStatusInChange(namestatusPath, changedALFiles, changedNonALFiles, NAVBeforeDirPath, NAVAfterDirPath);
            collectNumStatInChange(numstatPath, changedALFiles);
            collectDiffU0InChange(diffU0Path, changedALFiles);
            job.ALFileChanges = changedALFiles.Values.ToList();
            job.NonALFileChanges = changedNonALFiles.Values.ToList();
       }
        private void parseFileChange(ALFileChange fileChange, string codebasePath)
        {
            var fileToParsePath = Path.Combine(codebasePath, fileChange.Path);
            var contents = File.ReadAllText(fileToParsePath);
            Regex ALHeaderRegex = new Regex(@"(?<ObjectType>\w+)\s+(?<ObjectId>\d+)\s+(?<ObjectName>(\w|\d|_)+|\""[^\""]+\"")");
            var match = ALHeaderRegex.Match(contents);
            if(!match.Success){
                return;
            }
            fileChange.ALObjectType = match.Groups["ObjectType"].Value.ToLower();
            fileChange.ALObjectName = match.Groups["ObjectName"].Value;
            fileChange.ALObjectId = int.Parse(match.Groups["ObjectId"].Value);
            fileChange.IsTest = false;
            if(fileChange.ALObjectType != "codeunit")
                return;
            var isTestRegex = new Regex(@"\s*Subtype\s+=\s+Test\s*;");
            fileChange.IsTest = isTestRegex.IsMatch(contents);
        }
        private bool isALFilePath(string filePath)
        {
            if(filePath.Length < 3){
                return false;
            }
            return filePath.Substring(filePath.Length-3).ToLower() == ".al";
        }
        public List<JobMetadata> LoadJobs()
        {
            if(_jobs != null){
                return _jobs;
            }
            var timestamp = new DateTimeOffset(DateTime.UtcNow).ToUnixTimeSeconds();
            Console.WriteLine($"{timestamp}: Starting jobs loading");
            loadCoverageJobIds();
            var jobDirs = Directory.EnumerateDirectories(_configuration.GetCIJobsDirPath(), "job*").ToList();
            _jobs = jobDirs.Select(jobDir=>JobMetadataCSVReader.LoadJobMetadata(jobDir))
                            .Where(jobDir=>jobDir != null)
                            .Where(_configuration.HasJob)
                            .ToList();
            foreach(var job in _jobs)
            {
                timestamp = new DateTimeOffset(DateTime.UtcNow).ToUnixTimeSeconds();
                Console.WriteLine($"{timestamp}: Loading job{job.Id} file changes");
                setCoverageDirPath(job);
                loadFileChanges(job);
            }
            return _jobs;
        }

        

        private int GetJobIdFromPath(string path)
        {
            var regex = new Regex(@".*job(\d+)$");
            var match = regex.Match(path);
            if (!match.Success)
            {
                throw new Exception("Invalid job path");
            }
            return int.Parse(match.Groups[1].Value);
        }

        public IEnumerable<TestRun> GetJobAppTestRunResults(JobMetadata job)
        {
            var testRunsDirPath = GetJobTestRunDirPath(job);
            Func<string, bool> matchesRegex = taskName =>
            {
                if (_configuration.UsedTasksRegex().Count == 0)
                {
                    return true;
                }
                return _configuration.UsedTasksRegex().Any(
                    regex => regex.IsMatch(taskName)
                );
            };

            var testResultsFilePaths = Directory.EnumerateFiles(testRunsDirPath, "*.csv").Where(
                filePath => matchesRegex(Path.GetFileNameWithoutExtension(filePath))
            ).ToArray();

            foreach(var path in testResultsFilePaths)
            {
                var testRuns = JobAppTestTaskCSVReader.LoadJobAppTestTasks(path);
                var taskName = Path.GetFileNameWithoutExtension(path);
                foreach(var testRun in testRuns)
                {
                    testRun.Job = job;
                    testRun.TaskName = taskName;
                    yield return testRun;
                }
            }
        }

        public TestRun GetTestRun(JobMetadata job, TestRun testRun)
        {
            var path = GetTestRunsFilePath(job, testRun);
            if(!File.Exists(path))
                return null;
            var testRuns = JobAppTestTaskCSVReader.LoadJobAppTestTasks(path);
            foreach(var loadedTestRun in testRuns)
            {
                if(
                    loadedTestRun.TestCodeunitId == testRun.TestCodeunitId &&
                    loadedTestRun.ProcedureName == testRun.ProcedureName
                ) return loadedTestRun;
            }
            return null;
        }

        private string GetJobTestRunDirPath(JobMetadata job)
        {
            string runsDir = "TestRuns";
            if (_configuration.GetTestGranularity() == TestGranularity.PerCodeunit)
                runsDir = "TestRuns-Codeunit";
            return Path.Combine(_configuration.GetCIJobsDirPath(), $"job{job.Id}", runsDir);
        }

        private string GetTestRunsFilePath(JobMetadata job, TestRun testRun)
        {
            return Path.Combine(
                GetJobTestRunDirPath(job),
                $"{testRun.TaskName}.csv"
            );
        }
    }
}