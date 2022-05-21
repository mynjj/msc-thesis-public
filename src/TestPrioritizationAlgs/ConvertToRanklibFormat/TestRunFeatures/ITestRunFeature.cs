using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    public interface ITestRunFeature
    {
        IEnumerable<string> Compute(JobMetadata job, TestRun testRun, Coverage coverage);
    }
}
