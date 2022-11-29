// See https://aka.ms/new-console-template for more information
using Neom.Iomt.Data.Generator;

Console.WriteLine("Merging Synthea and CSV data!");

// Load Synthea data
// Load Neom data
// Produce file contents
// Merge patient data
// Update device data
// Write new records

var manager = new FhirResourceManager("C:\\Users\\luisape\\repos\\synthea\\output\\fhir", "C:\\Users\\luisape\\repos\\CSV2FHIR\\bin\\Debug\\netcoreapp3.1\\output");
await manager.StartAsync();