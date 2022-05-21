using System;
using System.IO;
using System.Globalization;
using System.Collections.Generic;
using CsvHelper;
using CsvHelper.Configuration;
using CsvHelper.TypeConversion;

namespace TestPrioritizationAlgs.CSVReaders
{
    class JobAppTestTaskDataTestRunResultConverter<T>: DefaultTypeConverter
    {
        public override object ConvertFromString(string text, IReaderRow row, MemberMapData memberMapData)
        {
            switch (text)
            {
                case "0": return TestRunResult.Failed;
                case "1": return TestRunResult.Succeeded;
                default: return TestRunResult.Inconclusive;
            }
        }
    }

    class JobAppTestTaskDataTestProcedureDurationConverter<T>: DefaultTypeConverter
    {
        public override object ConvertFromString(string text, IReaderRow row, MemberMapData memberMapData)
        {
            CultureInfo culture = (CultureInfo)CultureInfo.InvariantCulture.Clone();
            culture.NumberFormat.NumberDecimalSeparator = ",";
            return float.Parse(text, culture);
        }

    }

    class TestRunClassMap: ClassMap<TestRun>
    {
        public TestRunClassMap()
        {
            Map(m=>m.Country);
            Map(m=>m.TestCodeunitId);
            Map(m=>m.ProcedureName);
            Map(m=>m.TestProcedureDuration).TypeConverter<JobAppTestTaskDataTestProcedureDurationConverter<float>>();
            Map(m=>m.TestRunResult).Name("Result").TypeConverter<JobAppTestTaskDataTestRunResultConverter<TestRunResult>>();
        }
    }

    public class JobAppTestTaskCSVReader
    {
        static public IEnumerable<TestRun> LoadJobAppTestTasks(string path)
        {
            var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                HeaderValidated = null,
                MissingFieldFound = null
            };
            using(var reader = new StreamReader(path))
            using(var csv = new CsvReader(reader, csvConfig))
            {
                csv.Context.RegisterClassMap<TestRunClassMap>();
                var testRuns = csv.GetRecords<TestRun>();
                foreach(var testRun in testRuns){
                    if(testRun.TestRunResult != TestRunResult.Inconclusive)
                        yield return testRun;
                }
            }

        }
    }
}
