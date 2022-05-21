using System;
using System.Linq;
using System.Xml;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using TestPrioritizationAlgs.ConvertToRanklibFormat;

namespace TestPrioritizationAlgs
{
    enum PriorityMethod
    {
        Identity,
        Linear,
        Exponential,
        DurationCategories,
        CoverageCategories
    }
    namespace PriorityMethodConfiguration
    {
        class Exponential
        {
            public static double Factor() 
            {
                return 10;
            }
        }
        class Linear
        {
            public static double MaxValue()
            {
                return 10;
            }
        }
        class DurationCategories
        {
            public static double DurationThreshold()
            {
                return 4.5;
            }
        }
    }
    public class Configuration
    {
        private List<ITestRunFeature> _testRunFeatures;
        private PriorityMethod _priorityMethod;
        private Configuration() { 
            _testRunFeatures = new List<ITestRunFeature>();
            //_testRunFeatures.Add(new CoverageScore());
            _testRunFeatures.Add(new FilesAdded());
            _testRunFeatures.Add(new HistoryProperties(6));
            _testRunFeatures.Add(new LineCountProperties());
            //_priorityMethod = PriorityMethod.CoverageCategories;
            _priorityMethod = PriorityMethod.Exponential;
        }
        private static Configuration _configuration;

        public static Configuration GetConfiguration()
        {
            if(_configuration == null){
                _configuration = new Configuration();
            }
            return _configuration;
        }

        public int GetPriority(TestRun testRun, int index, int total, Coverage coverage, JobMetadata job)
        {
            // for methods `identity`, `linear`: assumes index previously sorted by failure+duration
            switch (_priorityMethod)
            {
                case PriorityMethod.Identity:
                    return index + 1;
                case PriorityMethod.Linear:
                    return (int)(1+ index*(PriorityMethodConfiguration.Linear.MaxValue() - 1) / (total-1));
                case PriorityMethod.Exponential:
                    var p = 1+Math.Exp(-testRun.TestProcedureDuration);
                    if (testRun.TestRunResult == TestRunResult.Failed)
                        p += 1;
                    return (int) (PriorityMethodConfiguration.Exponential.Factor()*p);
                case PriorityMethod.DurationCategories:
                    if(testRun.TestRunResult == TestRunResult.Failed)
                        return 3;
                    if (testRun.TestProcedureDuration < PriorityMethodConfiguration.DurationCategories.DurationThreshold())
                        return 2;
                    return 1;
                case PriorityMethod.CoverageCategories:
                    // Failing tests
                    if(testRun.TestRunResult == TestRunResult.Failed)
                        return 7;
                    // Tests modified by current change
                    if(job.ChangedTest(testRun.TestCodeunitId))
                        return 6;
                    var coverageData = coverage.GetCoveragePerTestData(testRun);
                    // Tests without coverage info
                    if(coverageData == null)
                        return 5;
                    // Tests covering objects changed by job
                    var linesCoveredByTest = coverage.LinesCovered(testRun);
                    bool coversLinesChanged = false;
                    foreach(var fileChange in job.ALFileChanges){
                        var objectKey = coverage.GetCoverageLineKey(fileChange.ALObjectType, fileChange.ALObjectId.ToString());
                        if (objectKey == null) continue;
                        if(linesCoveredByTest.ContainsKey(objectKey)){
                            coversLinesChanged = true;
                            break;
                        }
                    }
                    if(coversLinesChanged && coverageData.NLinesCovered >= coverage.MeanLinesCovered)
                        return 4;
                    if (coversLinesChanged && coverageData.NLinesCovered < coverage.MeanLinesCovered)
                        return 3;
                    // Tests covering more than average
                    if(coverageData.NLinesCovered >= coverage.MeanLinesCovered)
                        return 2;
                    // Tests covering less than average
                    return 1;
                default: return 0;
            }
        }

        public bool HasJob(JobMetadata jobMetadata)
        {
            //return jobMetadata.Id == 2496397;
            return true;
            /*
                (_startDateTime == null || jobMetadata.SubmitTime.CompareTo(_startDateTime) >= 0) && 
                (_endDateTime == null || jobMetadata.SubmitTime.CompareTo(_endDateTime) <= 0)
            */
        }
        
        public string GetDataDirPath()
        {
            return "C:\\Users\\t-dimartinez\\Desktop\\msc-data";
        }
        public string GetOutputFolder()
        {
            return $"{GetDataDirPath()}\\ranklib-datasets";
        }

        public List<Regex> UsedTasksRegex()
        {
            return (new List<Regex>());
        }
        public string GetCIJobsDirPath(){
            return $"{GetDataDirPath()}\\ci-history";
        }

        public string GetCoverageDirPath()
        {
            return $"{GetDataDirPath()}\\line-coverage";
        }

        public double TrainingValidationRatio()
        {
            return 0.8;
        }
        public TestGranularity GetTestGranularity()
        {
            return TestGranularity.PerCodeunit;
        }

        public List<ITestRunFeature> GetTestRunFeatures()
        {
            return _testRunFeatures;
        }

        public void WriteConfig(string filePath, List<JobMetadata> jobs)
        {
            var xmlSettings = new XmlWriterSettings() 
            {
                Indent = true
            };
            using (XmlWriter xmlWriter = XmlWriter.Create(filePath, xmlSettings))
            {
                xmlWriter.WriteStartDocument();

                xmlWriter.WriteStartElement("root");
                xmlWriter.WriteStartElement("jobs");
                foreach(var job in jobs)
                {
                    if(HasJob(job))
                    {
                        xmlWriter.WriteStartElement("job");
                        xmlWriter.WriteValue(job.Id);
                        xmlWriter.WriteEndElement();
                    }
                }
                xmlWriter.WriteEndElement();
                xmlWriter.WriteStartElement("testRunFeatures");
                foreach(var testRunFeature in _testRunFeatures)
                {
                    xmlWriter.WriteStartElement("feature");
                    xmlWriter.WriteValue(testRunFeature.GetType().Name);
                    xmlWriter.WriteEndElement();
                }
                xmlWriter.WriteEndElement();
                xmlWriter.WriteStartElement("priorityMethod");
                xmlWriter.WriteValue(_priorityMethod.ToString());
                xmlWriter.WriteEndElement();
                xmlWriter.WriteStartElement("testGranularity");
                xmlWriter.WriteValue(GetTestGranularity().ToString());
                xmlWriter.WriteEndElement();
                xmlWriter.WriteEndElement();
                xmlWriter.WriteEndDocument();
            }    
        }

    }
    public enum TestGranularity
    {
        PerProcedure,
        PerCodeunit
    }
}