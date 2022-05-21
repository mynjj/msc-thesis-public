using System.Linq;
using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    public class FilesAdded: ITestRunFeature
    {
        public IEnumerable<string> Compute(JobMetadata job, TestRun testRun, Coverage coverage)
        {
            // Added tables
            yield return job.ALFileChanges
                .Where(f=>f.IsTable() && f.FileOperation == FileOperation.Added)
                .Count().ToString();
            // Added AL Objects
            yield return job.ALFileChanges
                .Where(f=>f.FileOperation == FileOperation.Added)
                .Count().ToString();
            // Modified AL Objects
            yield return job.ALFileChanges
                .Where(f=>f.FileOperation == FileOperation.Modified)
                .Count().ToString();
            // Removed AL Objects
            yield return job.ALFileChanges
                .Where(f=>f.FileOperation == FileOperation.Deleted)
                .Count().ToString();
            // Changed tests
            yield return job.ALFileChanges
                .Where(f => f.IsTest)
                .Count().ToString();
            // Non AL changes
            yield return job.NonALFileChanges.Count().ToString();
        }
    }
}
