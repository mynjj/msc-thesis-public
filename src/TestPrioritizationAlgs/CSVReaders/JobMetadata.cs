using System;
using System.IO;
using System.Linq;
using System.Globalization;
using CsvHelper;
using CsvHelper.Configuration;
using CsvHelper.TypeConversion;

namespace TestPrioritizationAlgs.CSVReaders
{
    class JobMetadataClassMap: ClassMap<JobMetadata>
    {
        public JobMetadataClassMap()
        {
            Map(m => m.Id);
            Map(m => m.Status);
            Map(m => m.ExecutionTime);
            Map(m => m.FailedAppTest);
            Map(m => m.SubmitTime).TypeConverter<JobMetadataSubmitTimeConverter<DateTime>>();
        }
    }
    class JobMetadataSubmitTimeConverter<T>: DefaultTypeConverter
    {
        public override object ConvertFromString(string text, IReaderRow row, MemberMapData memberMapData)
        {
            return DateTime.ParseExact(text, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture);
        }
    }
    public class JobMetadataCSVReader
    {
        static public JobMetadata LoadJobMetadata(string jobDirPath)
        {
            string jobMetadataFilePath = jobDirPath + "\\jobmetadata.csv";
            var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                HeaderValidated = null,
                MissingFieldFound = null
            };
            if(!File.Exists(jobMetadataFilePath))
                return null;

            using(var reader = new StreamReader(jobMetadataFilePath))
            using(var csv = new CsvReader(reader, csvConfig))
            {
                csv.Context.RegisterClassMap<JobMetadataClassMap>();
                JobMetadata newJobMetadata = csv.GetRecords<JobMetadata>().First();
                newJobMetadata.DirPath = jobDirPath;
                return newJobMetadata;
            }
        }
    }
}
