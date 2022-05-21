using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    public class LastNResults: ITestRunFeature
    {
        private Dictionary<string, LinkedList<TestRunResult>> _storedResults;
        public int NResults { get; }
        public LastNResults(int nResults){
            NResults = nResults;
            _storedResults = new Dictionary<string, LinkedList<TestRunResult>>();
        }
        public IEnumerable<string> Compute(JobMetadata job, TestRun testRun, Coverage coverage){
            var key = $"{testRun.TaskName}.{testRun.TestCodeunitId}.{testRun.ProcedureName}";
            //Console.WriteLine(_storedResults.Count.ToString());
            if (!_storedResults.ContainsKey(key))
            {
                var runsHistory = new LinkedList<TestRunResult>();

                // By default unseen test runs are considered as not failing previously.
                for (int i = 0; i < NResults; i++)
                    runsHistory.AddFirst(TestRunResult.Succeeded);
                _storedResults.Add(key, runsHistory);
            }
            var historyResult = new List<string>();
            foreach(var result in _storedResults[key])
                switch(result)
                {
                    case TestRunResult.Failed:
                        historyResult.Add("0");
                        break;
                    case TestRunResult.Succeeded:
                        historyResult.Add("1");
                        break;
                    default:
                        historyResult.Add("2");
                        break;
                }
            _storedResults[key].AddFirst(testRun.TestRunResult);
            _storedResults[key].RemoveLast();
            return historyResult;
        }
    }
}