using System;
using System.Collections.Generic;
using System.Text;

namespace TestPrioritizationAlgs
{
    public enum FileOperation
    {
        Added,
        Modified,
        Deleted
    }
    public class ALFileChange
    {
        public bool IsTest { get; set; }
        public string ALObjectType { get; set; }
        public string ALObjectName { get; set; }
        public int ALObjectId { get; set; }
        public FileOperation FileOperation { get; set; }
        public int NAddedLines {get; set;}
        public int NDeletedLines {get; set;}
        public string Path {get; set;}
        public List<ALLineChange> LineChanges {get; set;}
        public ALFileChange () {
            LineChanges = new List<ALLineChange>();
        }

        public bool IsTable(){
            if(ALObjectType == null){
                return false;
            }
            return ALObjectType.ToLower() == "table";
        }

    }
}
