using System;
using System.Text.RegularExpressions;

namespace TestPrioritizationAlgs
{
    public class JobRetrievalConfiguration
    {
        public Regex[] UsedTasksRegex;
    }

    public class TestRunFeaturesConfiguration
    {
        // TestRun Features to set
    }

    

    public class JobTestTask
    {
        public string Name { get; set; }
        public string Status { get; set; }
        public int Duration { get; set; }
    }

}