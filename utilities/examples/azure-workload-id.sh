#!/bin/bash

# Get the current Azure subscription ID
export SUBSCRIPTION="$(az account show --query id --output tsv)"

# Set the name for the user-assigned managed identity
export USER_ASSIGNED_IDENTITY_NAME="redpoint-rpi"

# Set the Azure resource group name (replace with your actual resource group)
export RESOURCE_GROUP="<my-resource-group>"

# Set the Azure region (e.g., eastus, westus2)
export LOCATION="<my-azure-region>"

# Set the AKS cluster name (replace with your cluster name)
export CLUSTER_NAME="<my-aks-cluster>"

# Set the Kubernetes namespace where the service account will be created
export SERVICE_ACCOUNT_NAMESPACE="redpoint-rpi"

# Set the name of the Kubernetes service account
export SERVICE_ACCOUNT_NAME="redpoint-rpi"

# Set the name of the federated identity credential
export FEDERATED_IDENTITY_CREDENTIAL_NAME="redpoint-rpi"

# Create a user-assigned managed identity in the specified resource group and location
az identity create \
  --name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --subscription "${SUBSCRIPTION}"

# Retrieve the client ID of the created managed identity
export USER_ASSIGNED_CLIENT_ID="$(az identity show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --query 'clientId' --output tsv)"

# Get credentials for the specified AKS cluster to interact with it using kubectl
az aks get-credentials \
  --name "${CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}"

# Create a Kubernetes service account with an annotation for Azure Workload Identity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
EOF

# Retrieve the OIDC issuer URL for the AKS cluster
export AKS_OIDC_ISSUER="$(az aks show \
  --name "${CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "oidcIssuerProfile.issuerUrl" \
  --output tsv)"

# Create a federated identity credential linking the Kubernetes service account to the managed identity
az identity federated-credential create \
  --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" \
  --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --issuer "${AKS_OIDC_ISSUER}" \
  --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" \
  --audience api://AzureADTokenExchange
