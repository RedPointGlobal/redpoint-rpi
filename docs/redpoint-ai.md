![redpoint_logo](../chart/images/redpoint.png)
# Redpoint AI

[< Back to Home](../README.md)

## Overview

**Redpoint AI** lets RPI use Azure AI services to assist in building the criteria of **basic selection rules** from natural language. An operator describes a segment in plain language, and RPI uses an Azure OpenAI chat model, grounded with the tenant's attribute metadata, to compose the selection rule criteria.

Three Azure services back the feature. You provision all three in your own Azure subscription:

| Service | Role |
|:--------|:-----|
| **Azure OpenAI** | A chat model that interprets the request and composes the rule, and the `text-embedding-ada-002` model that vectorizes attribute metadata. |
| **Azure AI Search** | Holds the vector and keyword index of the tenant's attribute metadata that grounds the model. |
| **Azure Blob Storage** | Holds the index source documents that RPI generates and that Azure AI Search ingests. |

You provision the three services empty. RPI builds the search index, the vector search, the vector algorithm, and the embeddings on demand when an operator runs **Update AI Model** on a SQL Database Definition. RPI recreates the index on each run, so there is no client-facing configuration of the index schema or vector algorithm, and manual edits to the index are overwritten on the next run.

The feature runs in the same cluster and namespace as the rest of RPI. It is configured through the chart's `redpointAI` values block, and its credentials live in the shared RPI Secret alongside every other RPI secret.

> Azure OpenAI is a proprietary Microsoft service and requires a separate license subscription from Microsoft to access.

---

<details>
<summary><strong style="font-size:1.25em;">Architecture</strong></summary>

```
                 Update AI Model (operator action on a SQL Database Definition)
                 ----------------------------------------------------------------

  RPI services                  Azure OpenAI            Azure Blob          Azure AI Search
  (Execution Service,     ----> embeddings        ----> index source  <---- index + vector
   Node Manager,          (1)   (ada-002)         (2)   documents      (4)  search + indexer
   Integration API,                                          ^                    |
   Interaction API)                                          |____________________|
                                                              ingests source docs

                 Rule generation (operator enters natural-language criteria)
                 -----------------------------------------------------------

  RPI  ----(5) hybrid (vector + keyword) search---->  Azure AI Search
  RPI  <---(6) grounded prompt + chat completion--->  Azure OpenAI (chat model)  ----> rule criteria
```

**Index build** (operator runs Update AI Model on a basic SQL Database Definition):

1. RPI reads the attribute metadata for the SQL Database Definition and calls Azure OpenAI (`text-embedding-ada-002`) to vectorize the attribute names and sample values.
2. RPI writes the vectorized source documents into your Blob container and folder.
3. RPI creates or recreates the Azure AI Search index, vector search configuration, and indexer.
4. Azure AI Search ingests the documents from Blob.

**Rule generation** (operator enters a natural-language description):

5. RPI runs a hybrid (vector and keyword) search against the index to select the relevant attributes.
6. RPI sends a grounded prompt to the Azure OpenAI chat model and uses the response to populate the basic selection rule's criteria.

</details>

<details>
<summary><strong style="font-size:1.25em;">Prerequisites</strong></summary>

| Requirement | Detail |
|:------------|:-------|
| Azure subscription | Approved for Azure OpenAI, with model quota in your target region. |
| Azure permissions | Ability to create resource groups, Azure OpenAI (Cognitive Services), Azure AI Search, and Storage resources, and to read their keys. `Owner` or `Contributor` on the target resource group is sufficient. |
| RPI version | Any current v7 GA release of RPI. |
| Helm chart | A chart that includes the `redpointAI` values block (this chart). |
| RPI tenant | A configured tenant with at least one **basic SQL Database Definition**. This is the object you run Update AI Model on. |
| Integration API | The RPI Integration API service must be running. |
| CLI tooling | `az` (Azure CLI) and `helm`. |

> Azure OpenAI model availability and version strings vary by region and change over time. Choose a supported chat model that is available in your region. The examples below use placeholders for version strings; substitute the version Azure offers you.

</details>

<details>
<summary><strong style="font-size:1.25em;">Step 1: Provision Azure infrastructure</strong></summary>

Provision with either the Azure CLI or the Bicep template below. Both create the three services empty. RPI populates Search and Blob later.

### Azure CLI

```bash
# variables (edit these)
LOCATION="eastus2"
RG="rg-rpi-ai"
OPENAI="rpi-openai-001"               # Azure OpenAI (Cognitive Services) account
SEARCH="rpi-aisearch-001"             # Azure AI Search service
STORAGE="rpiaistore001"               # Storage account (3-24 lowercase alphanumeric)
CONTAINER="redpoint-ai"               # Blob container
CHAT_DEPLOYMENT="gpt-5.2"             # your chat model deployment name
EMBED_DEPLOYMENT="text-embedding-ada-002"

# resource group
az group create -n "$RG" -l "$LOCATION"

# Azure OpenAI
az cognitiveservices account create \
  -n "$OPENAI" -g "$RG" -l "$LOCATION" \
  --kind OpenAI --sku S0 --custom-domain "$OPENAI" --yes

# chat model deployment. The deployment NAME is what you set in
# redpointAI.naturalLanguage.ChatGptEngine.
az cognitiveservices account deployment create \
  -n "$OPENAI" -g "$RG" \
  --deployment-name "$CHAT_DEPLOYMENT" \
  --model-name "gpt-5.2" --model-version "<region-available-version>" \
  --model-format OpenAI --sku-capacity 1 --sku-name "Standard"

# embeddings model deployment
az cognitiveservices account deployment create \
  -n "$OPENAI" -g "$RG" \
  --deployment-name "$EMBED_DEPLOYMENT" \
  --model-name "text-embedding-ada-002" --model-version "<region-available-version>" \
  --model-format OpenAI --sku-capacity 1 --sku-name "Standard"

# Azure AI Search (Basic tier or higher is required for vector search)
az search service create \
  -n "$SEARCH" -g "$RG" -l "$LOCATION" --sku basic

# Storage account and container
az storage account create \
  -n "$STORAGE" -g "$RG" -l "$LOCATION" --sku Standard_LRS --kind StorageV2
az storage container create \
  --account-name "$STORAGE" --name "$CONTAINER" --auth-mode login
```

### Bicep

`redpoint-ai.bicep`:

```bicep
param location string = resourceGroup().location
param openAiName string
param searchName string
param storageName string
param containerName string = 'redpoint-ai'
param chatDeploymentName string = 'gpt-5.2'
param chatModelName string = 'gpt-5.2'
param chatModelVersion string                 // region-available version
param embedDeploymentName string = 'text-embedding-ada-002'
param embedModelVersion string                // region-available version

resource openai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAiName
  location: location
  kind: 'OpenAI'
  sku: { name: 'S0' }
  properties: { customSubDomainName: openAiName }
}

resource chat 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openai
  name: chatDeploymentName
  sku: { name: 'Standard', capacity: 1 }
  properties: {
    model: { format: 'OpenAI', name: chatModelName, version: chatModelVersion }
  }
}

resource embed 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openai
  name: embedDeploymentName
  dependsOn: [ chat ]                          // serialize deployments
  sku: { name: 'Standard', capacity: 1 }
  properties: {
    model: { format: 'OpenAI', name: 'text-embedding-ada-002', version: embedModelVersion }
  }
}

resource search 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: searchName
  location: location
  sku: { name: 'basic' }                       // Basic tier or higher for vector search
  properties: { replicaCount: 1, partitionCount: 1 }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storageName}/default/${containerName}'
  dependsOn: [ storage ]
}

output openAiEndpoint string = openai.properties.endpoint
output searchEndpoint string = 'https://${searchName}.search.windows.net'
```

```bash
az deployment group create -g "$RG" -f redpoint-ai.bicep \
  -p openAiName="$OPENAI" searchName="$SEARCH" storageName="$STORAGE" \
     chatModelVersion="<region-available-version>" \
     embedModelVersion="<region-available-version>"
```

</details>

<details>
<summary><strong style="font-size:1.25em;">Step 2: Configure Azure services</strong></summary>

### Azure OpenAI model deployments

Deploy one chat model and the embeddings model. Supported chat model:

- `GPT-5.2`

The embeddings model is `text-embedding-ada-002`, which produces 1536-dimension vectors.

The deployment name you choose for the chat model is the value you set in `redpointAI.naturalLanguage.ChatGptEngine`. The embeddings deployment name is the value you set in `redpointAI.modelStorage.EmbeddingsModel`.

### Azure AI Search

Do not create the index, data source, or indexer by hand. RPI builds all of it when an operator runs Update AI Model (see Step 4) and recreates it on each run. The search service only needs to exist and to be on a tier that supports vector search (Basic or higher).

### Azure Blob Storage

Provide an existing container, and optionally a folder, where RPI writes the index source documents. RPI manages the contents.

### Authentication

The Redpoint AI runtime authenticates to Azure with keys and a connection string:

| Azure service | Credential | Retrieve with |
|:--------------|:-----------|:--------------|
| Azure OpenAI | account API key | `az cognitiveservices account keys list -n "$OPENAI" -g "$RG" --query key1 -o tsv` |
| Azure AI Search | admin key | `az search admin-key show --service-name "$SEARCH" -g "$RG" --query primaryKey -o tsv` |
| Azure Blob Storage | connection string | `az storage account show-connection-string -n "$STORAGE" -g "$RG" --query connectionString -o tsv` |

These three values become the Kubernetes Secret entries in Step 3.

</details>

<details>
<summary><strong style="font-size:1.25em;">Step 3: Configure the Helm chart</strong></summary>

### Values

Enable Redpoint AI and set the endpoints, model, and storage values in your overrides:

```yaml
redpointAI:
  enabled: true
  naturalLanguage:
    ApiBase: https://<your-openai-name>.openai.azure.com/   # Azure OpenAI endpoint
    ApiVersion: 2023-07-01-preview                          # Azure OpenAI API version
    ChatGptEngine: gpt-5.2                                  # chat model deployment name
    ChatGptTemp: 0.5                                        # 0.0 (deterministic) to 2.0 (creative)
  cognitiveSearch:
    SearchEndpoint: https://<your-search-name>.search.windows.net
  modelStorage:
    EmbeddingsModel: text-embedding-ada-002                 # embeddings deployment name
    ModelDimensions: 1536                                   # must match the embedding model (ada-002 is 1536)
    ContainerName: redpoint-ai                              # Blob container
    BlobFolder: ""                                          # optional Blob folder
    EnableTrace: false                                      # verbose OpenAI-call tracing (see Step 5)
```

There is no vector-search profile or config setting. RPI creates and uses those dynamically when it generates the index.

### Secrets

The three sensitive values live in the shared RPI Secret (default `redpoint-rpi-secrets`), not in `values.yaml`. The required keys are:

| Secret key | Value |
|:-----------|:------|
| `RPI_NLP_API_KEY` | Azure OpenAI API key |
| `RPI_NLP_SEARCH_KEY` | Azure AI Search admin key |
| `RPI_NLP_MODEL_CONNECTION_STRING` | Blob storage connection string |

For `secretsManagement.provider: kubernetes`, add them to the shared Secret:

```bash
kubectl create secret generic redpoint-rpi-secrets \
  --namespace <rpi-namespace> \
  --from-literal=RPI_NLP_API_KEY="$OPENAI_KEY" \
  --from-literal=RPI_NLP_SEARCH_KEY="$SEARCH_KEY" \
  --from-literal=RPI_NLP_MODEL_CONNECTION_STRING="$BLOB_CONNSTR" \
  --dry-run=client -o yaml | kubectl apply -f -
```

For `csi` mode, populate the same keys in your CSI-backed secret store. For `sdk` mode, store them in your cloud vault under the same key names. The chart does not bind `secretKeyRef` entries in SDK mode, and RPI fetches the values at runtime. See [Secrets Management](secrets-management.md).

### What the chart wires

When `redpointAI.enabled` is `true`, the chart emits the `RPI__NLP__*` environment contract:

- The Execution Service, Node Manager, and Integration API receive the full configuration plus the three secret-backed values.
- The Interaction API receives the three secret-backed values only.

Apply with your normal upgrade:

```bash
helm upgrade --install rpi ./chart -n <rpi-namespace> -f my-values.yaml
```

</details>

<details>
<summary><strong style="font-size:1.25em;">Step 4: Configure RPI</strong></summary>

1. Ensure the target tenant is configured.
2. Ensure the tenant has a basic **SQL Database Definition** whose attributes you want available to natural-language rule building. This is the object the AI model is built from.
3. In the RPI client, open the SQL Database Definition and run **Update AI Model**. RPI then:
   - generates embeddings for the definition's attributes (Azure OpenAI),
   - writes the index source documents to your Blob container,
   - creates or recreates the Azure AI Search index, vector search, and indexer.

   Re-run Update AI Model whenever the attribute set changes. Each run recreates the index.
4. In a basic selection rule, use the natural-language assist to generate criteria.

> The RPI Integration API service must be running for this feature.

</details>

<details>
<summary><strong style="font-size:1.25em;">Step 5: Validate the installation</strong></summary>

### Configuration checks

```bash
# The NLP configuration env is present on the consuming services when enabled.
kubectl exec -n <ns> deploy/rpi-executionservice -- printenv | grep '^RPI__NLP__' | sort
# Expect: ApiBase, ApiVersion, ChatGptEngine, ChatGptTemp, SearchEndpoint,
# EmbeddingsModel, Model__ModelDimensions, Model__ContainerName,
# Model__BlobFolder, EnableTrace. The secret-backed ApiKey, SearchKey, and
# Model__ConnectionString are injected from the Secret in kubernetes and csi modes.
```

### Functional check

1. Run Update AI Model on the SQL Database Definition.
2. Confirm a new index exists in Azure AI Search with a populated document count.
3. Confirm the Blob container holds the generated source documents.
4. In a basic selection rule, generate criteria from a natural-language description and confirm a valid rule is produced.

### Tracing

Set `redpointAI.modelStorage.EnableTrace` to `true` for diagnostics. On each call to the OpenAI API during Update AI Model, RPI logs the following to the RPI Server Log as errors (informational tracing, not a failure):

- a JSON representation of all `RPI_NLP_` settings, with keys partially obfuscated,
- the endpoint called,
- the payload sent,
- the response received.

Turn tracing off for normal operation.

</details>

<details>
<summary><strong style="font-size:1.25em;">Troubleshooting</strong></summary>

| Symptom | Likely cause | Resolution |
|:--------|:-------------|:-----------|
| Azure OpenAI 401 or 403 | Wrong or expired `RPI_NLP_API_KEY`, or wrong `ApiBase`. | Re-fetch the key with `az cognitiveservices account keys list`. Confirm `ApiBase` is `https://<name>.openai.azure.com/`. |
| Azure OpenAI 404, deployment not found | `ChatGptEngine` or `EmbeddingsModel` does not match an Azure deployment name. | These are deployment names, not model names. List them with `az cognitiveservices account deployment list`. |
| Azure OpenAI 429 | Throttling or insufficient model quota. | Raise the deployment capacity, or retry. Limit how often Update AI Model runs. |
| Update AI Model fails building the index | Wrong search key, search tier without vector support, or wrong endpoint. | Verify `RPI_NLP_SEARCH_KEY` (admin key) and `SearchEndpoint`, and that the service is Basic tier or higher. |
| Embedding dimension mismatch | `ModelDimensions` does not match the embedding model output. | Set `ModelDimensions` to the model's size (`text-embedding-ada-002` is 1536). |
| Index empty after Update AI Model | Wrong Blob connection string, or missing container or folder. | Verify `RPI_NLP_MODEL_CONNECTION_STRING`, `ContainerName`, and `BlobFolder`. Confirm RPI wrote documents to Blob. |
| Blob access denied | Connection string lacks access, or the storage firewall blocks the cluster. | Re-issue the connection string. Ensure storage network rules allow the cluster. |
| Poor or incorrect rule results | Stale index, or temperature too high. | Re-run Update AI Model after attribute changes. Lower `ChatGptTemp` (for example, `0.3`) for more deterministic output. |
| NLP env vars missing on a pod | `redpointAI.enabled` is false, or the pod is not a consuming service. | Set `redpointAI.enabled` to `true`. Only the Execution Service, Node Manager, and Integration API receive the full configuration; the Interaction API receives the secret keys only. |

To capture the exact OpenAI request and response, enable `EnableTrace` (see Step 5) and inspect the RPI Server Log.

</details>

<details>
<summary><strong style="font-size:1.25em;">Reference example</strong></summary>

```yaml
# my-values.yaml (Redpoint AI portion)
secretsManagement:
  provider: kubernetes            # or csi or sdk

redpointAI:
  enabled: true
  naturalLanguage:
    ApiBase: https://acme-rpi-openai.openai.azure.com/
    ApiVersion: 2023-07-01-preview
    ChatGptEngine: gpt-5.2        # chat model deployment name
    ChatGptTemp: 0.5
  cognitiveSearch:
    SearchEndpoint: https://acme-rpi-search.search.windows.net
  modelStorage:
    EmbeddingsModel: text-embedding-ada-002
    ModelDimensions: 1536
    ContainerName: redpoint-ai
    BlobFolder: prod
    EnableTrace: false
```

```
Secret  redpoint-rpi-secrets:
  RPI_NLP_API_KEY                  = <Azure OpenAI key>
  RPI_NLP_SEARCH_KEY               = <Azure AI Search admin key>
  RPI_NLP_MODEL_CONNECTION_STRING  = <Blob connection string>
```

Checklist:

- [ ] Azure OpenAI with a supported chat model and `text-embedding-ada-002`.
- [ ] Azure AI Search on Basic tier or higher (vector search), sized for your attribute volume.
- [ ] Storage account and container reachable from the cluster.
- [ ] The three secret keys populated via your secrets provider.
- [ ] `redpointAI.enabled` set to `true` and values applied.
- [ ] Update AI Model run on each relevant SQL Database Definition.
- [ ] `EnableTrace` set to `false` in steady state.

</details>

<details>
<summary><strong style="font-size:1.25em;">Settings reference</strong></summary>

| Helm value | Environment variable | Required | Notes |
|:-----------|:---------------------|:---------|:------|
| `redpointAI.enabled` | gate | yes | Master toggle. Default `false`. |
| `naturalLanguage.ApiBase` | `RPI__NLP__ApiBase` | yes | Azure OpenAI endpoint. |
| `naturalLanguage.ApiVersion` | `RPI__NLP__ApiVersion` | yes | For example, `2023-07-01-preview`. |
| `naturalLanguage.ChatGptEngine` | `RPI__NLP__ChatGptEngine` | yes | Chat model deployment name. |
| `naturalLanguage.ChatGptTemp` | `RPI__NLP__ChatGptTemp` | yes | `0.0` to `2.0`. Default `0.5`. |
| `cognitiveSearch.SearchEndpoint` | `RPI__NLP__SearchEndpoint` | yes | Azure AI Search endpoint. |
| `modelStorage.EmbeddingsModel` | `RPI__NLP__EmbeddingsModel` | yes | Embeddings deployment name. |
| `modelStorage.ModelDimensions` | `RPI__NLP__Model__ModelDimensions` | yes | `1536` for ada-002. |
| `modelStorage.ContainerName` | `RPI__NLP__Model__ContainerName` | yes | Blob container. |
| `modelStorage.BlobFolder` | `RPI__NLP__Model__BlobFolder` | no | Blob folder. |
| `modelStorage.EnableTrace` | `RPI__NLP__EnableTrace` | no | Verbose tracing. Default `false`. |
| `RPI_NLP_API_KEY` (Secret) | `RPI__NLP__ApiKey` | yes | Azure OpenAI key. |
| `RPI_NLP_SEARCH_KEY` (Secret) | `RPI__NLP__SearchKey` | yes | Search admin key. |
| `RPI_NLP_MODEL_CONNECTION_STRING` (Secret) | `RPI__NLP__Model__ConnectionString` | yes | Blob connection string. |

</details>
