using System;
using System.Linq;
using System.Globalization;
using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    public class HistoryProperties: ITestRunFeature
    {
        int _failedWindowSize;
        private Dictionary<string, ValueTuple<int, LinkedList<TestRunResult>, float, int>> _historicValues;
        public HistoryProperties(int failedWindowSize)
        {
            _failedWindowSize = failedWindowSize;
            // times failed, times failed in window, duration average, total times seen
            _historicValues = new Dictionary<string, (int, LinkedList<TestRunResult>, float, int)>();
        }
        public IEnumerable<string> Compute(JobMetadata job, TestRun testRun, Coverage coverage)
        {
            var key = $"{testRun.TaskName}.{testRun.TestCodeunitId}.{testRun.ProcedureName}";
            if(!_historicValues.ContainsKey(key))
            {
                var runsHistory = new LinkedList<TestRunResult>();
                // By default unseen test runs are considered as not failing previously.
                for (int i = 0; i < _failedWindowSize; i++)
                    runsHistory.AddFirst(TestRunResult.Succeeded);

                _historicValues.Add(key, (0, runsHistory, 0,0));
            }
            var testHistoricData = _historicValues[key];

            var timesFailed = _historicValues[key].Item1;
            var lastResults = _historicValues[key].Item2;
            var averageDuration = _historicValues[key].Item3;
            var total = _historicValues[key].Item4;

            if(testRun.TestRunResult == TestRunResult.Failed)
                timesFailed++;
            if(total!=0)
                averageDuration = (averageDuration+testRun.TestProcedureDuration/total)*(total/(total+1));
            else
                averageDuration = testRun.TestProcedureDuration;

            total++;

            yield return (timesFailed/total).ToString(CultureInfo.InvariantCulture);
            yield return (lastResults.Where(t => t == TestRunResult.Failed).Count().ToString());
            yield return averageDuration.ToString(CultureInfo.InvariantCulture);


            testHistoricData.Item1 = timesFailed;
            testHistoricData.Item2.AddFirst(testRun.TestRunResult);
            testHistoricData.Item2.RemoveLast();
            testHistoricData.Item3 = averageDuration;
            testHistoricData.Item4 = total;
            _historicValues[key] = testHistoricData;
        }
    }
}
