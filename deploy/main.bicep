// Parameters
@description('Optional. Specifies the Azure location for all resources.')
param location string = resourceGroup().location

@description('Required. Specifies the logical environment for all resources.')
param env string = 'demo'

@description('Optional. Specifies the messaging tier for Event Hub Namespace. Defaults to Standard.')
@allowed([
  'Basic'
  'Standard'
])
param eventHubSku string = 'Standard'

@description('Required. The mapping JSON that determines how incoming device data is normalized.')
param deviceMapping object = {
  templateType: 'CollectionContent'
  template: []
}

@description('Required. The mapping JSON that determines how normalized data is converted to FHIR Observations.')
param destinationMapping object = {
  templateType: 'CollectionFhir'
  template: []
}

@description('Optional. Service Tier: PerGB2018, Free, Standalone, PerGB or PerNode.')
@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
])
param lawSku string = 'PerGB2018'

@description('Optional. The workspace data retention in days, between 30 and 730. Defaults to 30 days.')
@minValue(30)
@maxValue(730)
param lawRetentionInDays int = 30

@description('Optional. Enable diagnostic logs. Defaults to true.')
param enableDiagnostics bool = true

@description('Optional. Enable diagnostic logs to be sent to a storage account. Defaults to false. Requires enableDiagnostics to be true.')
param sendLogsToStorageAccount bool = false

@description('Optional. Specifies the SKU for the vault. Defaults to standard.')
@allowed([
  'premium'
  'standard'
])
param vaultSku string = 'standard'

@description('Optional. Array of access policies object.')
param vaultAccessPolicies array = []

@description('Optional. The IDs of the principals to assign the role to.')
param vaultPrincipalIds array = []

@description('Optional. Property that controls how data actions are authorized. When true, the key vault will use Role Based Access Control (RBAC) for authorization of data actions, and the access policies specified in vault properties will be ignored (warning: this is a preview feature). When false, the key vault will use the access policies specified in vault properties, and any policy stored on Azure Resource Manager will be ignored. If null or not specified, the vault is created with the default value of true. Note that management actions are always authorized with RBAC.')
param vaultEnableRbacAuthorization bool = true

@description('Optional. The FHIR service client Azure AD app registration used for testing.')
param fsClientId string = ''

@description('Optional. The FHIR service client secret Azure AD app registration used for testing.')
@secure()
param fsclientsecret string = ''

@description('Optional. The pricing tier of the Storage Account used to store logs. Consider Azure Monitor. FHIR Service and Meditech are not sending logs to Azure monitor and this storage account approach works.')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param logStorageAccountSku string = 'Standard_LRS'

@description('Required. Azure AD object id for the user/group setup as the workspace admin.')
param synapseInitialWorkspaceAdminObjectID string

@description('Optional. Azure AD service principal id for the application registration used to connect to FHIR service.')
param fhirTesterPrincipalId string = ''

@description('Optional. Administrator name used to login to Graph virtual machine.')
param graphAdminUser string = 'neomGraphAdmin'

@secure()
@description('Required. Administrator password used to login to Graph virtual machine.')
param graphAdminPassword string

@secure()
@description('Required. Administrator password used to login to Synapse.')
param synapseSqlPassword string

@description('Optional. Administrator name used to login to Synapse.')
param synapseSqlLogin string = 'neomAdmin'

param deploymentTime string = utcNow()

// Variables
var purposeAffix = 'neom'
var componentNameSuffix = '${purposeAffix}-${env}-${locationMapping[toLower(location)]}'
var componentNameSuffixNoDelimiter = replace(componentNameSuffix, '-', '')
var keyVaultName = 'kv-${componentNameSuffix}'
var healthWorkspaceName = 'hw${componentNameSuffixNoDelimiter}'
var fhirServiceName = 'hf-${componentNameSuffix}'
var fhirAudience = fhirUrl
var fhirUrl = 'https://${healthWorkspaceName}-${fhirServiceName}.fhir.azurehealthcareapis.com'
var eventHubNamespaceName = 'evhns-${componentNameSuffix}'
var lawName = 'log-${componentNameSuffix}'
var eventHubName = 'evh-${componentNameSuffix}'
var iotConnectorName = 'hi-${componentNameSuffix}-01' // 'iomt' is a reserved word and can't be used in name.
var fhirDestinationName = 'hd-${componentNameSuffix}'
var logStaName = 'sta${componentNameSuffixNoDelimiter}logs'
var fhirWriterRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '3f88fce4-5892-4214-ae73-ba5294559913') //FHIR Data Writer
var fhirContributorRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '5a1fc7df-4bf1-4951-a576-89034ee01acd') //FHIR Data Contributor
var eventHubReceiverRoleId = resourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde') //Azure Event Hubs Data Receiver
var locationMapping = {
  eastus: 'e1'
  eastus2: 'e2'
  eastus3: 'e3'
  westus: 'w1'
  westus2: 'w2'
  westus3: 'w3'
}
var formattedAccessPolicies = [for accessPolicy in vaultAccessPolicies: {
  applicationId: contains(accessPolicy, 'applicationId') ? accessPolicy.applicationId : ''
  objectId: contains(accessPolicy, 'objectId') ? accessPolicy.objectId : ''
  permissions: accessPolicy.permissions
  tenantId: contains(accessPolicy, 'tenantId') ? accessPolicy.tenantId : tenant().tenantId
}]
var synapseName = 'synw-${componentNameSuffix}'
var dlStorageName = 'sta${componentNameSuffixNoDelimiter}synw'
var dlStorageFileSystem = 'synapsefs'
var adfName = 'adf-${componentNameSuffix}'
var asbName = 'asb-${componentNameSuffix}'
var acrName = 'acr${componentNameSuffixNoDelimiter}'
var purviewName = 'pview${componentNameSuffixNoDelimiter}'
var cogName = 'cog-${componentNameSuffix}-clinicalai'
var mlName = 'mlw-${componentNameSuffix}-clinicalai'
var mlStorageName = 'sta${componentNameSuffixNoDelimiter}mlw'
var mlAppiName = 'appi-${componentNameSuffix}-mlw'
var logicAppiName = 'appi-${componentNameSuffix}-logic'
var logicAppName = 'logic-${componentNameSuffix}'
var logicAppPlanName = 'asp-${componentNameSuffix}-logic'
var logicAppStorageName = 'sta${componentNameSuffixNoDelimiter}logic'
var vnetName = 'vnet-${componentNameSuffix}'
var graphSubnetName = 'snet-${componentNameSuffix}-graph'
var graphVMName = 'vm-${componentNameSuffix}-graph'

var akvRoleAssignments = [for principalId in vaultPrincipalIds: {
  principalIds: [ principalId ]
  principalType: 'User'
  roleDefinitionIdOrName: 'Key Vault Administrator'
  description: 'Key Vault Administrator'
}]

// Monitoring START ---------------------------------------------------------------
module log 'modules/Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  name: 'law-${deploymentTime}'
  params: {
    name: lawName
    location: location
    serviceTier: lawSku
    dataRetention: lawRetentionInDays
  }
}
// Monitoring END ---------------------------------------------------------------

// AHDS START ---------------------------------------------------------------
resource health 'Microsoft.HealthcareApis/workspaces@2022-05-15' = {
  name: healthWorkspaceName
  location: location
}
// AHDS END ---------------------------------------------------------------

// FHIR START ---------------------------------------------------------------

// Add FHIR Service
resource fhir 'Microsoft.HealthcareApis/workspaces/fhirservices@2022-05-15' = {
  name: fhirServiceName
  parent: health
  location: location
  kind: 'fhir-R4'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessPolicies: []
    authenticationConfiguration: {
      authority: uri(environment().authentication.loginEndpoint, subscription().tenantId)
      audience: fhirAudience
      smartProxyEnabled: false
    }
  }
}

// Add FHIR Service monitoring
resource fhirDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: fhir
  name: 'diagnosticSettings'
  properties: {
    workspaceId: log.outputs.resourceId
    logs: [
      {
        category: 'AuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
// FHIR END ---------------------------------------------------------------

// IOMT START ---------------------------------------------------------------

// Add Event Hub ingestion for IOMT
module evns 'modules/Microsoft.EventHub/namespaces/deploy.bicep' = {
  name: 'evns-${deploymentTime}'
  params: {
    name: eventHubNamespaceName
    skuName: eventHubSku
    location: location
    skuCapacity: 2
    zoneRedundant: true
    isAutoInflateEnabled: true
    maximumThroughputUnits: 8
    diagnosticWorkspaceId: log.outputs.resourceId
    systemAssignedIdentity: true
    eventHubs: [
      {
        name: eventHubName
        messageRetentionInDays: 1
        partitionCount: 8
        consumerGroups: [
          { name: '$Default' }
          { name: iotConnectorName }
        ]
        authorizationRules: [
          {
            name: 'devicedatasender'
            rights: [
              'Send'
            ]
          }
        ]
      }
    ]
  }
}

// Add Meditech Service
resource iotConnector 'Microsoft.HealthcareApis/workspaces/iotconnectors@2022-05-15' = {
  name: iotConnectorName
  parent: health
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    ingestionEndpointConfiguration: {
      eventHubName: eventHubName
      consumerGroup: iotConnectorName
      fullyQualifiedEventHubNamespace: '${eventHubNamespaceName}.servicebus.windows.net'
    }
    deviceMapping: {
      content: deviceMapping
    }
  }
  dependsOn: [
    evns
  ]
}

// Add Meditech monitoring
resource iotConnectorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: iotConnector
  name: 'diagnosticSettings'
  properties: {
    workspaceId: log.outputs.resourceId
    storageAccountId: sendLogsToStorageAccount ? saLogs.outputs.resourceId : null
    logs: [
      {
        //category: 'Diagnostic Logs'
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
  }
}

// Add Meditech config
resource fhirDestination 'Microsoft.HealthcareApis/workspaces/iotconnectors/fhirdestinations@2022-05-15' = {
  name: fhirDestinationName
  parent: iotConnector
  location: location
  properties: {
    resourceIdentityResolutionType: 'Lookup'
    fhirServiceResourceId: fhir.id
    fhirMapping: {
      content: destinationMapping
    }
  }
}

resource PostmanFhirWriter 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(fhirTesterPrincipalId)) {
  scope: fhir
  name: guid(fhirContributorRoleId, fhirTesterPrincipalId, fhir.id)
  properties: {
    roleDefinitionId: fhirContributorRoleId
    principalId: fhirTesterPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Allow Meditech to write to FHIR Service
resource FhirWriter 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: fhir
  name: guid(fhirWriterRoleId, iotConnector.id, fhir.id)
  properties: {
    roleDefinitionId: fhirWriterRoleId
    principalId: iotConnector.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module iotConnector_roleAssignments 'modules/Microsoft.EventHub/namespaces/eventhubs/.bicep/nested_roleAssignments.bicep' = {
  name: '${uniqueString(deployment().name, location)}-Iomt-Rbac-01'
  params: {
    description: eventHubReceiverRoleId
    principalIds: [ iotConnector.identity.principalId ]
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: eventHubReceiverRoleId
    resourceName: '${eventHubNamespaceName}/${eventHubName}'
  }
  dependsOn: [
    evns
  ]
}

// IOMT END ---------------------------------------------------------------

// AKV START ---------------------------------------------------------------

// Add KeyVault
module keyVault 'modules/Microsoft.KeyVault/vaults/deploy.bicep' = {
  name: 'akv-${deploymentTime}'
  params: {
    location: location
    name: keyVaultName
    enableRbacAuthorization: vaultEnableRbacAuthorization
    vaultSku: vaultSku
    publicNetworkAccess: 'Enabled'
    diagnosticWorkspaceId: log.outputs.resourceId
    roleAssignments: akvRoleAssignments
    accessPolicies: formattedAccessPolicies
    softDeleteRetentionInDays: 7
    secrets: {
      secureList: [
        {
          name: 'FS-CLIENT-ID'
          value: fsClientId
        }
        {
          name: 'FS-RESOURCE'
          value: fhirUrl
        }
        {
          name: 'FS-URL'
          value: fhirUrl
        }
        {
          name: 'FS-TENANT-NAME'
          value: subscription().tenantId
        }
        {
          name: 'FS-SECRET'
          value: fsclientsecret
        }
        {
          name: 'FS-CLIENT-SECRET'
          value: fsclientsecret
        }
        {
          name: 'SYNW-SQL-ADMIN'
          value: synapseSqlLogin
        }
        {
          name: 'SYNW-SQL-PASSWORD'
          value: synapseSqlPassword
        }
        {
          name: 'GRAPH-ADMIN'
          value: graphAdminUser
        }
        {
          name: 'GRAPH-PASSWORD'
          value: graphAdminPassword
        }
      ]
    }
  }
}

// AKV END ---------------------------------------------------------------

// Storage LOGS START ---------------------------------------------------------------

module saLogs 'modules/Microsoft.Storage/storageAccounts/deploy.bicep' = if (sendLogsToStorageAccount) {
  name: 'salogs-${deploymentTime}'
  params: {
    location: location
    storageAccountSku: logStorageAccountSku
    storageAccountKind: 'StorageV2'
    name: logStaName
    enableHierarchicalNamespace: false
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    systemAssignedIdentity: true
    tableServices: {
      tables: [
        'FhirEvents'
      ]
      diagnosticWorkspaceId: log.outputs.resourceId
    }
  }
}

// Storage LOGS END ---------------------------------------------------------------

// SYNAPSE START ---------------------------------------------------------------

module synapseStorage 'modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'synapsesta-${deploymentTime}'
  params: {
    location: location
    name: dlStorageName
    enableHierarchicalNamespace: true
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    systemAssignedIdentity: true
    blobServices: {
      containers: [
        {
          name: dlStorageFileSystem
          publicAccess: 'None'
        }
      ]
      diagnosticWorkspaceId: log.outputs.resourceId
    }
  }
}

module synapse 'modules/Microsoft.Synapse/workspaces/deploy.bicep' = {
  name: 'synapse-${deploymentTime}'
  params: {
    name: synapseName
    initialWorkspaceAdminObjectID: synapseInitialWorkspaceAdminObjectID
    defaultDataLakeStorageAccountName: synapseStorage.outputs.name
    defaultDataLakeStorageFilesystem: dlStorageFileSystem
    location: location
    diagnosticWorkspaceId: log.outputs.resourceId
    managedResourceGroupName: '${synapseName}-managed'
    sqlAdministratorLogin: synapseSqlLogin
    sqlAdministratorLoginPassword: synapseSqlPassword
  }
}

// SYNAPSE END ---------------------------------------------------------------

// ADF START ---------------------------------------------------------------

module adf 'modules/Microsoft.DataFactory/factories/deploy.bicep' = {
  name: 'adf-${deploymentTime}'
  params: {
    location: location
    name: adfName
    systemAssignedIdentity: true
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    //managedVirtualNetworkName: 'vnet-${componentNameSuffix}-adf'
  }
}

// ADF END ---------------------------------------------------------------

// ASB START ---------------------------------------------------------------

module asb 'modules/Microsoft.ServiceBus/namespaces/deploy.bicep' = {
  name: 'asb-${deploymentTime}'
  params: {
    location: location
    name: asbName
    diagnosticWorkspaceId: log.outputs.resourceId
    systemAssignedIdentity: true
  }
}

// ASB END ---------------------------------------------------------------

// ACR START ---------------------------------------------------------------

module acr 'modules/Microsoft.ContainerRegistry/registries/deploy.bicep' = {
  name: 'acr-${deploymentTime}'
  params: {
    location: location
    name: acrName
    diagnosticWorkspaceId: log.outputs.resourceId
    systemAssignedIdentity: true
    publicNetworkAccess: 'Enabled'
  }
}

// ACR END ---------------------------------------------------------------

// Purview START ---------------------------------------------------------------

module purview 'modules/Microsoft.Purview/deploy.bicep' = {
  name: 'pview-${deploymentTime}'
  params: {
    location: location
    name: purviewName
    diagnosticWorkspaceId: log.outputs.resourceId
    systemAssignedIdentity: true
    publicNetworkAccess: 'Enabled'
  }
}

// Purview END ---------------------------------------------------------------

// Cognitive Services START ---------------------------------------------------------------

module cog 'modules/Microsoft.CognitiveServices/accounts/deploy.bicep' = {
  name: 'cog-${deploymentTime}'
  params: {
    location: location
    name: cogName
    diagnosticWorkspaceId: log.outputs.resourceId
    systemAssignedIdentity: true
    publicNetworkAccess: 'Enabled'
    kind: 'CognitiveServices'
    sku: 'S0'
    restore: false
  }
}

// Purview END ---------------------------------------------------------------

// ML START ---------------------------------------------------------------

module mlAppi 'modules/Microsoft.Insights/components/deploy.bicep' = {
  name: 'mlappi-${deploymentTime}'
  params: {
    name: mlAppiName
    location: location
    workspaceResourceId: log.outputs.resourceId
    kind: 'web'
  }
}

module mlStorage 'modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'mlsta-${deploymentTime}'
  params: {
    location: location
    name: mlStorageName
    enableHierarchicalNamespace: false
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    systemAssignedIdentity: true
  }
}

// NOTE: Using this module raises an error on re-deploy if the resource exists: No elements in sharedPrivateLinkResources
// module ml 'modules/Microsoft.MachineLearningServices/workspaces/deploy.bicep' = {
//   name: 'ml-${deploymentTime}'
//   params: {
//     location: location
//     name: mlName
//     diagnosticWorkspaceId: log.outputs.resourceId
//     systemAssignedIdentity: true
//     publicNetworkAccess: 'Enabled'
//     sku: 'Standard'
//     tier: 'Standard'
//     associatedStorageAccountResourceId: mlStorage.outputs.resourceId
//     associatedKeyVaultResourceId: keyVault.outputs.resourceId
//     associatedApplicationInsightsResourceId: mlAppi.outputs.resourceId
//     associatedContainerRegistryResourceId: acr.outputs.resourceId
//   }
// }

resource ml 'Microsoft.MachineLearningServices/workspaces@2022-05-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  name: mlName
  location: location
  properties: {
    friendlyName: mlName
    storageAccount: mlStorage.outputs.resourceId
    keyVault: keyVault.outputs.resourceId
    applicationInsights: mlAppi.outputs.resourceId
    containerRegistry: acr.outputs.resourceId
    hbiWorkspace: false
  }
  dependsOn: [
    mlStorage
    keyVault
    mlAppi
    acr
  ]
}

// module mlstorageAccount_roleAssignments 'modules/Microsoft.Storage/storageAccounts/.bicep/nested_roleAssignments.bicep' = {
//   name: '${uniqueString(deployment().name, location)}-Storage-Rbac-01'
//   params: {
//     description: 'Storage Blob Data Contributor'
//     principalIds: [ ml.outputs.principalId ]
//     principalType: 'ServicePrincipal'
//     roleDefinitionIdOrName: 'Storage Blob Data Contributor'
//     resourceId: mlStorage.outputs.resourceId
//   }
// }

// ML END ---------------------------------------------------------------

// LogicApp START ---------------------------------------------------------------

module logicPlan 'modules/Microsoft.Web/serverfarms/deploy.bicep' = {
  name: 'logicPlan-${deploymentTime}'
  params: {
    name: logicAppPlanName
    diagnosticWorkspaceId: log.outputs.resourceId
    location: location
    sku: {
      name: 'WS1'
      tier: 'WorkflowStandard'
    }
    maximumElasticWorkerCount: 20
    targetWorkerSize: 1
    targetWorkerCount: ((env == 'prod') ? 2 : 1)
    zoneRedundant: false
  }
}

module logicStorage 'modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'logicsta-${deploymentTime}'
  params: {
    location: location
    name: logicAppStorageName
    enableHierarchicalNamespace: false
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    systemAssignedIdentity: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

module logicAppi 'modules/Microsoft.Insights/components/deploy.bicep' = {
  name: 'logicAppi-${deploymentTime}'
  params: {
    name: logicAppiName
    location: location
    workspaceResourceId: log.outputs.resourceId
    kind: 'web'
  }
}

module logic 'modules/FunctionApp/main.bicep' = {
  name: 'logic-${deploymentTime}'
  params: {
    name: logicAppName
    type: 'workflow'
    planId: logicPlan.outputs.resourceId
    storageAccountName: logicStorage.outputs.name
    location: location
    functionExtensionVersion: '~4'
    functionRuntime: 'node'
    workspaceId: log.outputs.resourceId
    enableDiagnostics: true
    enableLogging: true
  }
}

// NOTE: Using this module raises an error on deploy: Runtime Scale Monitoring is not supported for this Functions version.
// module logic 'modules/Microsoft.Web/sites/deploy.bicep' = {
//   name: 'logic-${deploymentTime}'
//   params: {
//     name: logicAppName
//     location: location
//     storageAccountId: logicStorage.outputs.resourceId
//     diagnosticWorkspaceId: log.outputs.resourceId
//     kind: 'functionapp,workflowapp'
//     serverFarmResourceId: logicPlan.outputs.resourceId
//     //clientAffinityEnabled: false
//     storageAccountRequired: false
//     httpsOnly: true
//     systemAssignedIdentity: true
//     appInsightId: logicAppi.outputs.resourceId
//     diagnosticLogCategoriesToEnable: [
//       'FunctionAppLogs'
//       'WorkflowRuntimeLogs'
//     ]
//     appSettingsKeyValuePairs: {
//       WEBSITE_NODE_DEFAULT_VERSION: '~14'
//       AzureFunctionsJobHost__extensionBundle__id: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
//       AzureFunctionsJobHost__extensionBundle__version: '[1.*, 2.0.0)'
//       APP_KIND: 'workflowApp'
//       FUNCTIONS_WORKER_RUNTIME: 'node'
//       FUNCTIONS_EXTENSION_VERSION: '~4'
//     }
//     siteConfig: {
//       functionsRuntimeScaleMonitoringEnabled: true
//       numberOfWorkers: 1
//       alwaysOn: false
//       http20Enabled: false
//       functionAppScaleLimit: 0
//       minimumElasticInstanceCount: 3
//     }
//   }
// }

// LogicApp END ---------------------------------------------------------------

// VM START ---------------------------------------------------------------

module virtualNetworks 'modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'vnet-${uniqueString(deployment().name)}'
  params: {
    location: location
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    name: vnetName
    diagnosticWorkspaceId: log.outputs.resourceId
    subnets: [
      {
        addressPrefix: '10.0.0.0/24'
        name: graphSubnetName
      }
    ]
  }
}

module graphVM 'modules/Microsoft.Compute/virtualMachines/deploy.bicep' = {
  name: 'graphVM-${uniqueString(deployment().name)}'
  params: {
    name: graphVMName
    computerName: 'NeomGraph'
    location: location
    adminUsername: graphAdminUser
    adminPassword: graphAdminPassword
    diagnosticWorkspaceId: log.outputs.resourceId
    imageReference: {
      offer: 'windows-11'
      publisher: 'microsoftwindowsdesktop'
      sku: 'win11-21h2-pro'
      version: 'latest'
    }
    osType: 'Windows'
    encryptionAtHost: false // needs to be enabled at subscription level
    vmSize: 'Standard_E16as_v5'
    osDisk: {
      diskSizeGB: '128'
      caching: 'ReadWrite'
      deleteOption: 'Delete'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    bootDiagnostics: false
    nicConfigurations: [
      {
        deleteOption: 'Delete'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: virtualNetworks.outputs.subnetResourceIds[0]
            pipConfiguration: {
              publicIpNameSuffix: '-pip-01'
            }
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
  }
}

resource graphVMSchedule 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${graphVMName}' // Name must follow convention else an error occurs InvalidScheduleId.
  location: location
  properties: {
    dailyRecurrence: {
      time: '2200'
    }
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    timeZoneId: 'Eastern Standard Time'
    targetResourceId: graphVM.outputs.resourceId
    notificationSettings:{
      status: 'Disabled'
    }
  }
  dependsOn: [ graphVM ]
}
// VM END ---------------------------------------------------------------

// Outputs
output fhirResourceId string = fhir.id
output fhirUrl string = fhirUrl
