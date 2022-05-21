using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;

namespace TestPrioritizationAlgs
{
    public class CoveragePerTestData
    {
        public int NLinesCovered{get; set;}
        public List<string> CoverageFiles {get; set;}
        public CoveragePerTestData(){
            CoverageFiles = new List<string>();
        }
    }
    public class Coverage
    {
        string _coverageDirPath;
        Dictionary<string, CoveragePerTestData> _perTestData;
        public float MeanLinesCovered { get; private set; }
        Dictionary<string, Dictionary<string, List<(int, int)>>> _perTestLinesCovered;
        public Coverage(string coverageDirPath)
        {
            _coverageDirPath = coverageDirPath;
            _perTestData = new Dictionary<string, CoveragePerTestData>();
            _perTestLinesCovered = new Dictionary<string, Dictionary<string, List<(int, int)>>>();
        }

        public CoveragePerTestData GetCoveragePerTestData(TestRun testRun)
        {
            var key = testPrefix(testRun);
            if (!_perTestData.ContainsKey(key)) {
                return null;
            }
            return _perTestData[key];
        }
        public void LoadLinesCovered(List<TestRun> testRuns)
        {
            MeanLinesCovered = GetMeanLinesCovered(testRuns);
        }
        private float GetMeanLinesCovered(List<TestRun> testRuns)
        {
            if (testRuns.Count() == 0) {
                return 0;
            }
            int totalCovered = 0;
            foreach (var testRun in testRuns) {
                if (_perTestData.ContainsKey(testPrefix(testRun)))
                {
                    totalCovered += _perTestData[testPrefix(testRun)].NLinesCovered;
                    continue;
                }
                var coverageData = new CoveragePerTestData();
                coverageData.CoverageFiles = GetTestRunCoverageFiles(testRun).ToList();
                coverageData.NLinesCovered = coverageData.CoverageFiles
                                                .Select(f => File.ReadLines(f).Count()).Sum();
                _perTestData.Add(testPrefix(testRun), coverageData);
                totalCovered += coverageData.NLinesCovered;
            }
            return totalCovered / testRuns.Count();
        }
        public int GetLinesCovered(TestRun testRun)
        {
            if (!_perTestData.ContainsKey(testPrefix(testRun))) {
                return 0;
            }
            return _perTestData[testPrefix(testRun)].NLinesCovered;
        }
        public IEnumerable<string> GetTestRunCoverageFiles(TestRun testRun)
        {
            return Directory.EnumerateFiles(_coverageDirPath, $"{testPrefix(testRun)}*");
        }
        private string testPrefix(TestRun testRun)
        {
            return $"{testRun.Country}_{testRun.TestCodeunitId}";
        }

        public Dictionary<string, List<(int, int)>> LinesCovered(TestRun testRun)
        {
            var testKey = testPrefix(testRun);
            if (_perTestLinesCovered.ContainsKey(testKey))
            {
                return _perTestLinesCovered[testKey];
            }
            Dictionary<string, List<(int, int)>> testData = new Dictionary<string, List<(int, int)>>();
            var coverageData = GetCoveragePerTestData(testRun);
            foreach(var file in coverageData.CoverageFiles)
            {
                foreach(var line in File.ReadLines(file))
                {
                    var parts = line.Replace("\"", "").Split(',');
                    var lineKey = GetCoverageLineKey(parts[0], parts[1]);
                    if (lineKey == null) continue;
                    if (!testData.ContainsKey(lineKey))
                    {
                        testData.Add(lineKey, new List<(int, int)>());
                    }
                    testData[lineKey].Add((int.Parse(parts[2]), int.Parse(parts[3])));
                }
            }
            _perTestLinesCovered[testKey] = testData;
            return _perTestLinesCovered[testKey];
        }

        public string GetCoverageLineKey(string objectType, string objectId)
        {
            if(objectType == null || objectId == null)
            {
                return null;
            }
            return $"{objectType.ToLower()}-{objectId}";
        }
    }
}