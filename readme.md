




## Setup

1. [Find Your Azure AD Object ID](#find-your-azure-ad-object-id) and/or those requiring access to KeyVault.
1. [Update Vault ACL configuration](#manage-vault-acls)
1. Run the Bicep [deployment](#deploy-script).
1. Optionally deploy FHIR Loader using shell [script](#deploy-fhir-bulk-loader).
1. Optionally grant `FHIR Data Contributor` role to the Azure App Registration used for testing from Postman.

### Deploy Script

```sh
cd deploy

az login -t 72f988bf-86f1-41af-91ab-2d7cd011db47

az account set -s 35f934aa-bdb1-4827-bb40-be79343ca2f6

az deployment group create -g 'NEOMv2' -f main.bicep --name ("main-" + (Get-Date -Format "s").replace(':', '-')) --parameters `@main.parameters.demo.json
```

### Find Your Azure AD Object ID

```sh
az ad signed-in-user show --query id -o tsv
```

### Manage Synapse RBAC

- Confirm client IP is added under `Networking` in order to connect.

```sh
az synapse role assignment list --workspace-name synw-neom-demo-e1 --assignee-object-id 78ff7aef-7f4d-4874-9210-486c3c33f43e
az synapse role assignment create --workspace-name synw-neom-demo-e1 --assignee-object-id 5b296cf9-9e2f-471d-ba10-04494b602c5d --role "Synapse Administrator"
```

### Manage Vault ACLs

Use either RBAC or Access Policies in Vault. Update the following sections in the [Bicep parameter file](/deploy/main.parameters.demo.json) file.

> NOTE: FHIR Loader deploy script expects access policy support. This step fails but can be done manually afterwards with RBAC.

#### Add Vault RBAC

```json
"vaultPrincipalIds": {
  "value": [
    "{AAD_OBJECT_ID_GOES_HERE}"
  ]
}
```

#### Add Vault Access Policy

```json
    "vaultAccessPolicies": {
      "value": [
        {
          "objectId": "",
          "permissions": {
            "certificates": [
              "All"
            ],
            "keys": [
              "All"
            ],
            "secrets": [
              "All"
            ]
          }
        }
      ]
    },
```

## Deploy FHIR Bulk Loader

This is optional but useful for importing batches of data into FHIR service.

```
./deployFhirBulk.bash -i 35f934aa-bdb1-4827-bb40-be79343ca2f6 -g NEOM -l eastus -n neom-demo-e1 -k kv-neom-demo-e1 -o fhir
```

### Manually Configure FHIR Bulk Loader Event Grid Subscriptions

```
az eventgrid event-subscription create --name 'ndjsoncreated' --source-resource-id '/subscriptions/35f934aa-bdb1-4827-bb40-be79343ca2f6/resourceGroups/NEOM/providers/Microsoft.Storage/storageAccounts/neomdemoe1store' --endpoint '/subscriptions/35f934aa-bdb1-4827-bb40-be79343aca2f6/resourceGroups/NEOM/providers/Microsoft.Web/sites/sfb-neomdemoe1/functions/ImportNDJSON' --endpoint-type 'azurefunction' --subject-begins-with '/blobServices/default/containers/ndjson' --subject-ends-with '.ndjson' --advanced-filter data.api stringin CopyBlob PutBlob PutBlockList FlushWithClose
```

```
az eventgrid event-subscription create --name 'bundlecreated' --source-resource-id '/subscriptions/35f934aa-bdb1-4827-bb40-be79343ca2f6/resourceGroups/NEOM/providers/Microsoft.Storage/storageAccounts/neomdemoe1store' --endpoint '/subscriptions/35f934aa-bdb1-4827-bb40-be79343ca2f6/resourceGroups/NEOM/providers/Microsoft.Web/sites/sfb-neomdemoe1/functions/ImportBundleEventGrid' --endpoint-type 'azurefunction' --subject-begins-with '/blobServices/default/containers/bundles' --subject-ends-with '.json' --advanced-filter data.api stringin CopyBlob PutBlob PutBlockList FlushWithClose
```

## Generate FHIR Patient Data

```
./run_synthea -p 50 --exporter.fhir.export=true --exporter.split_records=true --exporter.ccda.export=true --exporter.fhir.bulk_data=false --generate.append_numbers_to_person_names=false
```

## Troubleshoot Meditech Errors

This occurs when using `Create` mode and the patient id is not part of the message and can't be loaded from the device id.

```json
{ "time": "2022-11-15T21:53:22.3218980Z", "resourceId": "/SUBSCRIPTIONS/35F934AA-BDB1-4827-BB40-BE79343CA2F6/RESOURCEGROUPS/NEOM/PROVIDERS/MICROSOFT.HEALTHCAREAPIS/WORKSPACES/HCNEOMDEMOE1/IOTCONNECTORS/HI-NEOM-DEMO-E1", "location": "eastus", "operationName": "FHIRConversion", "category": "DiagnosticLogs", "resultDescription": "Fhir resource of type Patient not found.", "resultType": "Microsoft.Health.Fhir.Ingest.Service.ResourceIdentityNotDefinedException"}
```

This occurs when using `Lookup` mode and the device is not in the FHIR server.

```json
{ "time": "2022-11-17T14:05:55.0676870Z", "resourceId": "/SUBSCRIPTIONS/35F934AA-BDB1-4827-BB40-BE79343CA2F6/RESOURCEGROUPS/NEOM/PROVIDERS/MICROSOFT.HEALTHCAREAPIS/WORKSPACES/HWNEOMDEMOE1/IOTCONNECTORS/HI-NEOM-DEMO-E1-01", "location": "eastus", "operationName": "FHIRConversion", "category": "DiagnosticLogs", "resultDescription": "Fhir resource of type Device not found.", "resultType": "Microsoft.Health.Fhir.Ingest.FhirResourceNotFoundException"}
```

Unknown:

```json
{ "time": "2022-11-16T23:29:18.0003640Z", "resourceId": "/SUBSCRIPTIONS/35F934AA-BDB1-4827-BB40-BE79343CA2F6/RESOURCEGROUPS/NEOM/PROVIDERS/MICROSOFT.HEALTHCAREAPIS/WORKSPACES/HCNEOMDEMOE1/IOTCONNECTORS/HI-NEOM-DEMO-E1", "location": "eastus", "operationName": "Normalization", "category": "DiagnosticLogs", "resultDescription": "The HealthCheck [ExternalEventHub:IsAuthenticated] did not pass", "resultType": "Microsoft.Health.Fhir.Ingest.Console.PaaS.Exceptions.HealthCheckException"}
{ "time": "2022-11-16T23:29:18.0119550Z", "resourceId": "/SUBSCRIPTIONS/35F934AA-BDB1-4827-BB40-BE79343CA2F6/RESOURCEGROUPS/NEOM/PROVIDERS/MICROSOFT.HEALTHCAREAPIS/WORKSPACES/HCNEOMDEMOE1/IOTCONNECTORS/HI-NEOM-DEMO-E1", "location": "eastus", "operationName": "Normalization", "category": "DiagnosticLogs", "resultDescription": "The HealthCheck [CredentialStore:IsCustomerFacingMiCredentialBundlePresent] did not pass", "resultType": "Microsoft.Health.Fhir.Ingest.Console.PaaS.Exceptions.HealthCheckException"}
{ "time": "2022-11-16T23:30:11.0932240Z", "resourceId": "/SUBSCRIPTIONS/35F934AA-BDB1-4827-BB40-BE79343CA2F6/RESOURCEGROUPS/NEOM/PROVIDERS/MICROSOFT.HEALTHCAREAPIS/WORKSPACES/HCNEOMDEMOE1/IOTCONNECTORS/HI-NEOM-DEMO-E1", "location": "eastus", "operationName": "FHIRConversion", "category": "DiagnosticLogs", "resultDescription": "The HealthCheck [FhirService:IsAuthenticated] did not pass", "resultType": "Microsoft.Health.Fhir.Ingest.Console.PaaS.Exceptions.HealthCheckException"}
```

## FAQ

1. Several Bicep modules are currently not used as issues occur with them:
  - Microsoft.MachineLearningServices
  - Microsoft.Web for Logic App Standard