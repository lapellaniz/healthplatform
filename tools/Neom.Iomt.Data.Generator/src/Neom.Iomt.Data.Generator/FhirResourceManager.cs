using Hl7.Fhir.Serialization;
using System.Text.Json;
using System.Threading.Tasks.Dataflow;
using Hl7.Fhir.Model;
using Hl7.Fhir.Rest;

namespace Neom.Iomt.Data.Generator
{
    internal class FhirResourceManager
    {
        private readonly string _syntheaDataFolder;
        private readonly string _csvDataFolder;
        private readonly BufferBlock<FhirResourceEntry> _buffer;
        private readonly HashSet<string> _loadedPatients = new();
        private readonly JsonSerializerOptions _fhirBundleSerializationOptions = new JsonSerializerOptions().ForFhir(typeof(fhir.Bundle).Assembly);
        private readonly JsonSerializerOptions _fhirPatientSerializationOptions = new JsonSerializerOptions().ForFhir(typeof(fhir.Patient).Assembly);

        public FhirResourceManager(string syntheaDataFolder, string csvDataFolder)
        {
            _buffer = new BufferBlock<FhirResourceEntry>(new DataflowBlockOptions() { BoundedCapacity = 10 });
            _syntheaDataFolder = syntheaDataFolder;
            _csvDataFolder = csvDataFolder;
        }

        public async System.Threading.Tasks.Task StartAsync()
        {
            var produce = Produce();
            var consume = Consume();
            await System.Threading.Tasks.Task.WhenAll(produce, _buffer.Completion);
            var result = await consume;
            Console.WriteLine($"Processed {result} record(s).");
        }

        private async System.Threading.Tasks.Task Produce()
        {
            var syntheaRecords = Directory.EnumerateFiles(_syntheaDataFolder).ToList();
            var csvRecords = Directory.EnumerateFiles(_csvDataFolder).ToList();

            Console.WriteLine($"Found {csvRecords.Count} CSV records to merge.");

            for (int i = 0; i < syntheaRecords.Count; i++)
            {
                if (!CanLoadResource(syntheaRecords[i]))
                {
                    continue;
                }
                var entry = new FhirResourceEntry
                {
                    SyntheaRecord = syntheaRecords[i],
                    CsvRecord = csvRecords[i]
                };
                await _buffer.SendAsync(entry);
            }

            _buffer.Complete();
        }

        private async System.Threading.Tasks.Task<int> Consume()
        {
            int recordsProcessed = 0;

            while (await _buffer.OutputAvailableAsync())
            {
                FhirResourceEntry? entry = null;
                try
                {
                    // Grab entry
                    entry = await _buffer.ReceiveAsync();
                    Console.WriteLine($"Processing record {entry.SyntheaRecord}.");

                    // Read files
                    var syntheaJson = await File.ReadAllTextAsync(entry.SyntheaRecord);
                    var csvJson = await File.ReadAllTextAsync(entry.CsvRecord);

                    // Parse FHIR
                    var syntheaBundle = JsonSerializer.Deserialize<fhir.Bundle>(syntheaJson, _fhirBundleSerializationOptions);
                    var csvPatient = JsonSerializer.Deserialize<fhir.Patient>(csvJson, _fhirPatientSerializationOptions);
                    if (syntheaBundle == null)
                    {
                        throw new Exception($"Synthea bundle '{entry.SyntheaRecord}' was not deserialized.");
                    }
                    if (csvPatient == null)
                    {
                        throw new Exception($"CSV Patient '{entry.CsvRecord}' was not deserialized.");
                    }

                    // Find patient bundle entry
                    var syntheaPatientBundleEntry = syntheaBundle.Entry.Where(e => e.Resource.TypeName == "Patient").Select(e => e).First();
                    var syntheaPatient = (Patient)syntheaPatientBundleEntry.Resource;
                    var syntheaPatientId = syntheaPatient.Id;

                    // Remove synthea entry
                    syntheaBundle.Entry.Remove(syntheaPatientBundleEntry);

                    // Add IOMT patient device identifier
                    // Use PatientID as the device association
                    // Currently MedTech service expects an identifier with a single value and no system...
                    csvPatient.Identifier.Add(new Identifier() { Value = csvPatient.Id });

                    // Add CSV bundle entry
                    var newBundleEntry = syntheaBundle.AddResourceEntry(csvPatient, $"urn:uuid:{csvPatient.Id}");
                    newBundleEntry.Request = new Bundle.RequestComponent { Method = Bundle.HTTPVerb.PUT, Url = $"Patient/{csvPatient.Id}" };

                    // Add IOMT Device
                    var deviceId = csvPatient.Id; // use patient ID for easy lookup
                    var device = new Device
                    {
                        Id = deviceId,
                        Status = Device.FHIRDeviceStatus.Active,
                        DistinctIdentifier = deviceId,
                        ManufactureDate = DateTime.Parse("01/01/2022").ToString("s"),
                        LotNumber = Guid.NewGuid().ToString(),
                        SerialNumber = Guid.NewGuid().ToString(),
                        Patient = new ResourceReference($"Patient/{csvPatient.Id}"),
                        Type = new CodeableConcept("http://snomed.info/sct", "467178001", "Bedside heart rate monitor (physical object)", "Bedside heart rate monitor (physical object)")
                    };
                    device.DeviceName.Add(new Device.DeviceNameComponent() { Name = "Home heartrate monitor (physical object)", Type = DeviceNameType.UserFriendlyName });
                    device.Identifier.Add(new Identifier { Value = deviceId });
                    device.UdiCarrier.Add(new Device.UdiCarrierComponent() { DeviceIdentifier = deviceId, CarrierHRF = $"(01){deviceId}(11)710321(17)960404(10)84546978(21)50428" });
                    var newDeviceBundleEntry = syntheaBundle.AddResourceEntry(device, $"urn:uuid:{deviceId}");
                    newDeviceBundleEntry.Request = new Bundle.RequestComponent { Method = Bundle.HTTPVerb.PUT, Url = $"Device/{deviceId}" };

                    // Convert to JSON and update bundle patient IDs
                    var syntheaNewJson = JsonSerializer.Serialize(syntheaBundle, _fhirBundleSerializationOptions);
                    var syntheaMergedJson = syntheaNewJson.Replace($"urn:uuid:{syntheaPatientId}", $"Patient/{csvPatient.Id}");

                    // Output new file
                    var outputDir = Path.Combine(Directory.GetCurrentDirectory(), "output");
                    if (!Directory.Exists(outputDir))
                    {
                        Directory.CreateDirectory(outputDir);
                    }
                    var outputPath = Path.Combine(outputDir, Path.GetFileName(entry.CsvRecord));
                    await File.WriteAllTextAsync(outputPath, syntheaMergedJson);

                    recordsProcessed++;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error occurred processing record {entry?.SyntheaRecord}. Error: {ex}");
                }
            }
            return recordsProcessed;
        }

        private bool CanLoadResource(string patientFilePath)
        {
            var patientFileName = Path.GetFileNameWithoutExtension(patientFilePath);
            var patientKey = string.Join('_', patientFileName.Split('_').Take(2));
            if (patientKey.Contains("practitionerInformation", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
            else if (patientKey.Contains("hospitalInformation", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
            else if (_loadedPatients.Contains(patientKey))
            {
                return false;
            }
            _loadedPatients.Add(patientKey);
            return true;
        }
    }

    internal class FhirResourceEntry
    {
        public string SyntheaRecord { get; set; }
        public string CsvRecord { get; set; }
    }
}
