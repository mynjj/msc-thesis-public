using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace TestPrioritizationAlgs
{
    namespace Cmdlets
    {
        [Cmdlet(VerbsData.ConvertTo, "RanklibFormat")]
        public class ConvertToRanklibFormat: PSCmdlet
        {
            public string[] Tasks;

            public DateTime StartTime { get; set; }

            public DateTime EndTime { get; set; }

            public static void Start()
            {
                /*
                var data = new DataRepository();
                var from = new DateTime();
                var to = new DateTime();
                data.SetDateRange(from, to);
                Dictionary<int, JobMetadata> jobs = data.JobsInDateRange();
                TestPrioritizationAlgs.ConvertToRanklibFormat.GetRanklibIndependentColumns(jobs);
                */
            }

            protected override void ProcessRecord()
            {
                //TestPrioritizationAlgs.ConvertToRanklibFormat.ProcessJob();
            }
        }
    }
}