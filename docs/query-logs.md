

## Get count of IOMT messages processed

```
AzureMetrics 
| where Resource == 'HI-NEOM-DEMO-E1'
| where MetricName == 'FhirResourceSaved' or MetricName == 'NormalizedEvent'
| summarize count() by MetricName
```

## Count of logs by Azure resource

```
AzureDiagnostics 
| summarize count() by Resource
```

## Count of audit events by FHIR resource

```
MicrosoftHealthcareApisAuditLogs 
| summarize count() by FhirResourceType
```