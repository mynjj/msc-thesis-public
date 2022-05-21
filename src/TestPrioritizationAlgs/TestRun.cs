namespace TestPrioritizationAlgs
{
    public enum TestRunResult
    {
        Failed,
        Succeeded,
        Inconclusive
    }
    public class TestRun
    {
        public string ProcedureName {get; set;}
        public int TestCodeunitId {get; set;}
        public float TestProcedureDuration {get; set;}
        public TestRunResult TestRunResult {get; set;}
        public string Country {get; set;}
        public JobMetadata Job {get; set;}
        public string TaskName { get; set; }
    }
}