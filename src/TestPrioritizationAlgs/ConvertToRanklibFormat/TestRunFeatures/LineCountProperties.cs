using System.Linq;
using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    public class LineCountProperties: ITestRunFeature
    {
        public IEnumerable<string> Compute(JobMetadata job, TestRun testRun, Coverage coverage)
        {
            int added = job.ALFileChanges.Select(c=>c.NAddedLines).Sum();
            int deleted = job.ALFileChanges.Select(c=>c.NDeletedLines).Sum();

            yield return added.ToString();
            yield return deleted.ToString();
        }
    }
}
