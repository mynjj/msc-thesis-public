using System;
using System.Linq;
using System.Globalization;
using System.Collections.Generic;

namespace TestPrioritizationAlgs.ConvertToRanklibFormat
{
    public class CoverageScore: ITestRunFeature
    {
        public IEnumerable<string> Compute(JobMetadata job, TestRun testRun, Coverage coverage)
        {
            // Lines covered
            yield return (coverage.GetLinesCovered(testRun)/coverage.MeanLinesCovered).ToString(CultureInfo.InvariantCulture);

            int[] coverageAuras = { 0, 3, 5, 10};
            int[] coverageLineTotals = { 0, 0, 0, 0 };

            var coveredByTest = coverage.LinesCovered(testRun);

            int nFilesChangedCovered = 0;
            foreach(var fileChange in job.ALFileChanges){
                var objectKey = coverage.GetCoverageLineKey(fileChange.ALObjectType, fileChange.ALObjectId.ToString());
                if (objectKey == null) continue;
                if(!coveredByTest.ContainsKey(objectKey)){
                    continue;
                }
                nFilesChangedCovered++;
                foreach(var line in coveredByTest[objectKey]){
                    var lineNumber = line.Item1;
                    var hits = line.Item2;
                    foreach(var lineChange in fileChange.LineChanges){
                        for(var i=0; i<coverageAuras.Length; i++)
                        {
                            var startingLine = lineChange.BeforeLineAndCount.Item1 - coverageAuras[i];
                            var endingLine = startingLine + lineChange.BeforeLineAndCount.Item2 + coverageAuras[i];
                            if (lineNumber >= startingLine && lineNumber <= endingLine)
                                coverageLineTotals[i] += hits;
                        }
                    }
                }
            }

            yield return nFilesChangedCovered.ToString();
            foreach(var totalL in coverageLineTotals)
            {
                yield return totalL.ToString();
            }
            
        }
    }
}
