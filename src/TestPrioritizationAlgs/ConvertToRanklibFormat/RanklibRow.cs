using System.Globalization;
using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    class RanklibRow
    {
        public TestRun TestRun { get; set; }
        public int Priority { get; set; }
        public List<string> Features { get; set; }
        public RanklibRow(TestRun testRun, int priority)
        {
            TestRun = testRun;
            if(priority <= 0){
                throw new System.Exception("Priority must be a positive number");
            }
            Features = new List<string>();
            Priority = priority;
        }
        public override string ToString()
        {
            int JobId = TestRun.Job.Id;
            string result = $"{Priority} q:{JobId} ";
            for(int i=0; i<Features.Count; i++)
            {
                result += $"{i+1}:{Features[i]} ";
            }
            result += $"# {TestRun.Country}-{TestRun.TestCodeunitId}-{TestRun.ProcedureName} @ {TestRun.TaskName}";
            return result;
        }
        public string ValidationMetadata()
        {
            int jobId = TestRun.Job.Id;
            int testCodeunitId = TestRun.TestCodeunitId;
            string duration = TestRun.TestProcedureDuration.ToString(CultureInfo.InvariantCulture);
            string result = TestRun.TestRunResult.ToString();
            return $"JobId:{jobId},TestCodeunitId:{testCodeunitId},Duration:{duration},Result:{result}";
        }
    }
}