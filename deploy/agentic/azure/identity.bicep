// ============================================================
// Managed Identity for RPI workloads
// Created before other resources to enable cross-resource role assignments.
// ============================================================

param prefix string
param location string
param tags object

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${prefix}'
  location: location
  tags: tags
}

output id string = managedIdentity.id
output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
