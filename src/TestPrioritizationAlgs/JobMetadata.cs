using System;
using System.Collections.Generic;

namespace TestPrioritizationAlgs
{
    public class JobMetadata
    {
        bool _hasTestsInit, _hasTests;
        public int Id { get; set; }
        public DateTime SubmitTime { get; set; }
        public string DirPath { get; set; }
        public string Status { get; set; }
        public string ExecutionTime { get; set; }
        public bool FailedAppTest { get; set; }
        public string CoverageDirPath{ get; set; }
        public List<NonALFileChange> NonALFileChanges {get; set;}
        public List<ALFileChange> ALFileChanges { get; set; }
        public bool ChangedTest(int codeunitId){
            if(_hasTestsInit && !_hasTests){
                return false;
            }
            _hasTestsInit = true;
            foreach(var change in ALFileChanges)
            {
                if(!change.IsTest) continue;
                _hasTests = true;
                if(change.ALObjectId == codeunitId) return true;
            }
            return false;
        } 
    }
}