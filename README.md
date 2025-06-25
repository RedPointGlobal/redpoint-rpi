![rp_cdp_logo](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/432d779f-de4e-4936-80fe-3caa4d732603)
## Redpoint Interaction (RPI) | Deployment on Kubernetes
With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

This chart installs Redpoint Interaction (RPI) on Kubernetes using HELM.
![RPI v7 (3)](https://github.com/user-attachments/assets/376b5fd2-315e-4bb6-9476-774bea85b24b)
### Table of Contents
- [System Requirements ](#system-requirements)
- [Considerations Before you begin ](#considerations-before-you-begin)
- [Begin Deployment ](#begin-deployment)
- [Post Greenfield Deployment Configuration](#post-greenfield-deployment-configuration)
- [Post Upgrade Deployment Configuration](#post-upgrade-deployment-configuration)
- [Retrieve Client Endpoints ](#retrieve-client-endpoints)
- [Download Client Executable ](#download-client-executable)
- [Configure Storage ](#configure-storage)
- [Configure Realtime](#configure-realtime)
- [Configure Open ID Connect](#configure-open-id-connect)
- [Configure Content Generation Tools](#configure-content-generation-tools)
- [Configure Custom Metrics](#configure-custom-metrics)
- [Configure High Availability ](#configure-high-availability)
- [Configure Autoscaling with custom metrics](#configure-autoscaling-with-custom-metrics)
- [RPI Documentation](#rpi-documentation)
- [Getting Support](#getting-support)

### System Requirements

- **Operational Databases**
    - Microsoft SQL Server 2019 or later on any of the following plaforms: ```SQLServer on VM```, ```AzureSQLDatabase```, ```AmazonRDSSQL```, ```GoogleCloudSQL```, ```PostgreSQL```
    - 8 GB Memory or more
    - 200 GB or more free disk space.

- **Data Warehouses**
    - Databases on any of the following platforms: ```AzureSQLDatabase```, ```AmazonRDSSQL```, ```GoogleCloudSQL```, ```SQLServer on VM```, ```Snowflake```, ```PostgreSQL```, ```Amazon Redshift```, ```Google BigQuery```

- **Kubernetes Cluster:**

   - Latest stable version of Kubernetes. Select from this list of [Kubernetes certified solution providers](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/). From each provider page, you can learn how to install and setup production ready clusters.

   -  Nodepools Sizing
        - 8 vCPUs per node
        - 16 GB of Memory per node
        - Minimum of 2 nodes for high availability

The system specs outlined above are for running RPI in a modest environment. Ajust them based on your production environment and specific use case.

### Prerequisites
| Ensure that the following requirements are met!                                                                                                                                                                                                                                   |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| - **Redpoint Container Registry:** Open a [Support](mailto:support@redpointglobal.com) ticket requesting access to download RPI images.<br><br> - **RPI License:** Open a [Support](mailto:support@redpointglobal.com) ticket to obtain your RPI v7 License activation key.<br><br> - **Kubectl:** Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), a command-line tool for interacting with your Kubernetes cluster.<br><br> - **Helm:** Install [Helm](https://helm.sh/docs/helm/helm_install/) and ensure you have the required permissions for your target kubernetes cluster. |

### Considerations Before you begin
Before deploying RPI, determine whether you're planning a Greenfield deployment or an Upgrade deployment.

- **Upgrade Deployment:** RPI is deployed in an existing version 6.x environment. This means using the existing cluster, tenant, operations and logging databases, cache, and queue providers, with the RPI v7 containers being added to the existing setup. The upgrade from RPI v6.x to RPI v7.x is more involved. Before attempting to upgrade, be sure to read the [Redpoint Interaction upgrade path](https://docs.redpointglobal.com/bpd/upgrade-to-rpi-v7-x)

![upgrade-start](https://github.com/user-attachments/assets/c6e517ed-89ba-4045-8686-c5ad8bc8c9a2)

- **Greenfield Deployment:** RPI is deployed in a completely new environment. This means the creation of a new cluster, tenant, operations and logging databases, cache and queue providers. All these components are deployed from scratch, independent of any existing deployments.

Both deployment methods require you deploy the RPI v7 containers following the same steps. However, the post-deployment configuration steps will differ. Details for each method are outlined in the [Post Greenfield Deployment Configuration](#post-greenfield-deployment-configuration) and [Post Upgrade Deployment Configuration](#post-upgrade-deployment-configuration) sections below.

### Begin Deployment

At a highlevel, the deployment process flows as follows:

- Clone this repository to your local environment.
- Create a Kubernetes namespace dedicated for RPI 
- Create the Kubernetes secrets for ```imagePull``` and TLS certificates for ```Ingress```.
- Provide the connection details for:
   - Operational database server
   - Data warehouse server (If using Redshift or BigQuery)
   - Cache and Queue providers (If using RPI Realtime)
- Deploy the application using Helm.

To begin, follow the detailed instructions in the sections below.

**1. Clone this repository**

Cloning the repository locally ensures you have an independent copy of the project, which is not directly affected by upstream changes and gives you control over versioning.

```
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
```

**2. Create Kubernetes Namespace:**

A Kubernetes namespace provides a logical separation within the cluster ensuring the resources and configurations for this project do not interfere with others in your cluster

```
kubectl create namespace redpoint-rpi 
```

**3. Create Container Registry Secret:**

Create a Kubernetes secret for ```imagePull```. This secret will store the credentials required to pull RPI images from the Redpoint container registry. Obtain these credentials from Redpoint Support and replace ```<your_username>``` and ```<your_password>``` with your actual credentials:

```
NAMESPACE=redpoint-rpi
DOCKER_SERVER=rg1acrpub.azurecr.io
DOCKER_USERNAME=<your_username>
DOCKER_PASSWORD=<your_password>

kubectl create secret docker-registry redpoint-rpi \
--namespace $NAMESPACE \
--docker-server=$DOCKER_SERVER \
--docker-username=$DOCKER_USERNAME \
--docker-password=$DOCKER_PASSWORD
```

**4. Create TLS Certificate Secret:**

The Helm chart deploys an ingress controller to expose the URL endpoints required for accessing RPI services using HTTPS. The only requirement on your part is to provide a TLS certificate key pair. To add the certificate, create a Kubernetes secret as shown below:

```
NAMESPACE=redpoint-rpi
CERT_PATH=./your_cert.crt
KEY_PATH=./your_cert.key

kubectl create secret tls ingress-tls \
--namespace $NAMESPACE \
--cert=$CERT_PATH \
--key=$KEY_PATH
```

With the secret created, configure the domain for your ingress. Open the ```values.yaml``` file, locate the ```ingress``` section, and replace ```example.com``` with your actual domain name. If you prefer to use your own ingress controller instead of the one provided by the Helm chart, set the value of ```controller.enabled``` to ```false```.

```
ingress:
  domain: example.com
  controller:
    enabled: false
```

**5. Configure Operational Database Provider**

The [operational databases](https://docs.redpointglobal.com/rpi/admin-key-concepts) store information necessary for RPI to function. There are two core operational databases: ```Pulse``` and ```Pulse_Logging```. Update the ```databases.operational``` section in the ```values.yaml``` with your SQL Server details.

```
databases:
  operational: 
    provider: sqlserver
    server_host: <my-server-host>
    server_username: <my-server-username>
    server_password: <my-server-password>
    pulse_database_name: <my-pulse-database-name>
    pulse_logging_database_name: <my-pulse-logging-database-name>
```

**6. Configure Datawarehouse Provider**

**Note:** This section only applies if your [datawarehouse](https://docs.redpointglobal.com/rpi/supported-connectors#Supportedconnectors-Databaseplatforms) is ```Redshift``` or ```BigQuery```. Both providers use ODBC drivers, which require a configuration file to be included in the containers. The details you provide are used to configure the Data Source Name (DSN). After deployment, the connection string for your Redshift or BigQuery data warehouse would look like this: ```dsn=redshift``` or ```dsn=bigquery```. This references the DSN that was automatically created using the details you provided.

```
datawarehouse:
  provider: redshift
  redshift:
    server: your_redshift_server_endpoint
    port: 5439
    database: my_redshift_db
    username: my_redshift_user
    password: my_redshift_password
```

For the selected provider, make sure to complete the appropriate section either ```googleSettings``` or ```amazonSettings``` under ```cloudIdentity``` to supply the credentials required.

**Note:** For both existing RPI v6.x deployments (during an upgrade) and new (greenfield) installations that require [RPI Realtime](https://docs.redpointglobal.com/rpi/rpi-realtime), ensure you complete the steps outlined in the [Configure Realtime](#configure-realtime) section before proceeding to Step 7.

**7. Install RPI**

Make sure you are in the cloned repository's directory and run the Helm install command
```
pwd # print working directory

.
├── README.md
├── utilities
├── redpoint-rpi
└── chart-release-notes.md
└── values.yaml

helm install redpoint-rpi redpoint-rpi/ --values values.yaml
```

If everything goes well, You should see the output below.
```
NAME: redpoint-rpi
LAST DEPLOYED: Mon Apr  28 02:31:46 2025
NAMESPACE: redpoint-rpi
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
********************************* SUCCESS! *********************************
```
It may take some time for all the RPI services to fully initialize. We recommend waiting approximately 5-10 minutes to ensure that the services are completely up and running. 

### Retrieve Client Endpoints

To interact with RPI services, such as client login, you need to obtain the URL endpoints exposed by the ingress. Use the following command to list the ingresses in the redpoint-rpi namespace
```
kubectl get ingress --namespace redpoint-rpi
```
If no IP address is displayed, wait a few minutes and then re-run the command. Once the load balancer is ready, you should see output similar to the following, where ```<Load Balancer IP>``` will be replaced with the actual IP address:
```
NAME           HOSTS                                  ADDRESS              PORTS     AGE
redpoint-rpi   rpi-deploymentapi.example.com          <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-interactionapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-integrationapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-realtimeapi.example.com            <Load Balancer IP>   80, 443   32d
```

Create DNS records in your DNS zone to map each hostname to the load balancer's IP address. This ensures proper routing of traffic to your services. You can then access RPI Services with the following endpoints:

```
https://rpi-deploymentapi.example.com                              # Deployment Service
https://pi-interactionapi.example.com                              # Client hostname
https://rpi-integrationapi.example.com                             # Integration API
https://rpi-realtimeapi.example.com                                # Realtime API
https://rpi-callbackapi.example.com                                # Callback API
https://rpi-interactionapi.example.com/api/deployment/download     # Client Download
```

### Download Client Executable

To connect to the RPI server, download the client application provided by the Interaction API. You have two options:

- Visit the Interaction API splash page to find the download link.
- Use the direct link: ```https://rpi-interactionapi.example.com/download```

### Configure Cloud Identity

**Note: This step is optional.** You can skip it if you're not using cloud services.

Certain RPI functionality (e.g., secret managers, Azure and GCP plugins) is able to make use of cloud provider identity to authenticate with cloud services. This can be configured in the ```cloudIdentity``` section within the ```values.yaml``` file. Currently, the supported authentication methods are ```Azure AKS Workload Identity```, ```Google Service Account``` and ```Amazon AWS Access Keys```.

Open the ```values.yaml``` file and navigate to the ```cloudIdentity``` section. Set the provider field to your desired cloud provider. Supported values are ```Azure```, ```Amazon```, and ```Google```.

```
cloudIdentity:
  enabled: true
  provider: Azure
```

For Azure, perform steps to enable [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-migrate-from-pod-identity) and grant the associated Managed Identity with permission to access the applicable Azure services. The Helm Chart only requires you provide the Managed Identity's client ID in the ```values.yaml```

```
azureSettings:
  managedIdentityClientId: <your-managed-identity-client_id>
```

For Google Cloud, perform steps to create a Service Account in the target project and grant it permissions to access the applicable Google services. Create a Kubernetes ConfigMap containing the JSON file associated with the service account. The Helm Chart only requires you provide the Google project ID and the name of this ConfigMap in the ```values.yaml```

```
googleSettings:
  configMapName: my-google-svs-account
  projectId: <my-google-project-id>
```

For Amazon, perform steps to create an IAM user in the target account, grant the user permissions to access the necessary AWS services. The Helm Chart only requires you provide the ```Acccess Key ID```, ```Secret Access Key``` and ```region``` in the ```values.yaml```

```
amazonSettings:
    accessKeyId: <my-iam-access-key>
    secretAccessKey: <my-iam-secret-access-key>
    region: us-east-1  
```

### Configure Secrets Management

**Note: This step is optional**. You can skip it if you're comfortable using native Kubernetes secrets.

By default, the Helm chart creates Kubernetes secrets for passwords and connection strings defined in the ```values.yaml``` file. You can disable this behavior and use an external key vault. Currently, the supported key vaults are ```Azure Key Vault```, and ```Google Secrets Manager```. To use an external key vault, configure the ```cloudIdentity``` section as shown below: 

```
cloudIdentity:
  enabled: true
  provider: Azure
  secretsManagement:
    enabled: true
    secretsProvider: keyvault
    autoCreateSecrets: false
    vaultUri: https://myvault.vault.azure.net/
    appSettingsVaultUri: https://myvault.vault.azure.net/
```

The name of each Key Vault secret must match the corresponding environment variable name, with underscores (_) replaced by hyphens (-). For example, an environment variable like ConnectionStrings__OperationalDatabase should be stored in Key Vault as: ```ConnectionStrings--OperationalDatabase```. Below is an example of secrets created in Azure Key Vault.

```
ClusterEnvironment--OperationalDatabase--ConnectionSettings--Password
ClusterEnvironment--OperationalDatabase--ConnectionSettings--Username
ConnectionStrings--LoggingDatabase
ConnectionStrings--OperationalDatabase

RealtimeAPIConfiguration--AppSettings--RealtimeAPIKey
RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Value
RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Value
```

### Configure Storage

RPI uses File Share storage for storing files such as those exported via interactions or selection rules to a [File Output directory ](https://docs.redpointglobal.com/rpi/file-output-directory), custom plugins or files shared with Redpoint Data Management (RPDM). In Azure, AWS, or Google Cloud, this storage is backed by their respective managed file share services such as ```Azure Files```, ```Amazon EFS``` and ```Google Filestore```

You are responsible for provisioning the storage based on your hosting platform's offering. Once the storage has been provisioned, create a PersistentVolumeClaim (PVC) and reference its name in the ```values.yaml``` file.

```
storage:
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
    Plugins:
      enabled: true
      claimName: realtimeplugins
      mountPath: /app/plugins
    DataManagementUploadDirectory:
      enabled: true
      claimName: rpdmuploaddirectory
      mountPath: /rpdmuploaddirectory
```

### Configure Realtime

[RPI Realtime](https://docs.redpointglobal.com/rpi/configuring-realtime-queue-providers) consists of a suite of functionality that allows you to make decisions about the most appropriate content to be displayed to a person of interest in real time.

- **Queue Providers**

[Queue Providers](https://docs.redpointglobal.com/rpi/configuring-realtime-queue-providers) are used to provide RPI with message queuing capabilities. To configure a Queue Provider, Open the ```values.yaml``` file and locate the ```realtimeapi.queueProvider``` section. Update this section with Queue provider you intend to use. Supported options are: ```amazonsqs ```, ```googlepubsub```,```azureeventhubs ```, ```azureservicebus```,```rabbitmq```

```
queueProvider:
  provider: amazonsqs
```

- **Personalized Content Queues**

RabbitMQ is currently the only supported queue provider for personalized content delivery, though support for additional providers is coming soon. For now, you have two options:

  - Use your own external RabbitMQ broker (BYO), or
  - Use the default free and open source RabbitMQ instance provisioned by the Helm chart.

If you are already using another queue provider (e.g. Amazon SQS for Realtime), RabbitMQ will run in parallel specifically for personalized content.

To use the default RabbitMQ, Open your values.yaml file and locate the ```realtimeapi.queueProvider.rabbitmq``` section. Set ```queueProvider.rabbitmq.internal: true``` and specify your preferred username and password. To use an external broker (BYO), simply set ```queueProvider.rabbitmq.internal: false``` and provide the rest of the connection details.

```
queueProvider:
  rabbitmq:
    internal: true
    hostname: rpi-rabbitmq
    virtualHost: "/"
    username: redpointdev
    password: <my-secure-password>
```

Once RabbitMQ is running, login to the RPI Client and configure the personalized content setup. The hostname for the built-in RabbitMQ instance is always ```rpi-rabbitmq``` while web console access is available at ```https://rpi-rabbitmq-console.example.com```. You can retrieve the actual console URL by inspecting your configured ingress endpoints.

![image](https://github.com/user-attachments/assets/8cf151fc-a47f-4de8-bf89-6884387a726c)

- **Cache Providers**

[Cache Providers](https://docs.redpointglobal.com/rpi/cache-configuration) allow RPI to store and access various data quickly, such as Visitor Profiles, Realtime Decisions rules, and content.Open the ```values.yaml``` file and locate the ```realtimeapi.cacheProviders``` section. Here, specify the Cache provider you intend to use. Supported options are: ```mongodb```, ```redis``` ,```googlebigtable``` ```inMemorySql```

```
cacheProviders:
  provider: mongodb
```

**Note:** When using the RPI SQL Server native cache provider, you can download the necessary setup scripts for SQL Server in-memory cache tables from the deployment service's downloads page: ```https://$DEPLOYMENT_SERVICE_URL/download/UsefulSQLScripts``` After downloading, extract the UsefulSQLScripts archive, and locate the script in the following path ```UsefulSQLScripts\SQLServer\Realtime\In Memory Cache Setup.sql.``` 

- **API authentication (Basic)**

The default authentication method for the Realtime API is an authentication token in the header of the call to the API endpoint. The token is configured with the following setting in the ```values.yaml```

```
realtimeapi:
  authentication:
    type: basic
```

- **API authentication (OAuth)**

The Realtime API can also be configured to use [OAuth](https://docs.redpointglobal.com/rpi/rpi-realtime-authentication) instead of the header token authentication. To configure RPI Realtime to use OAuth, first create the SQL Server or PostgreSQL database required by the OAuth implementation. The scripts to create the database can be downloaded from the Configuration Service ```https://$DEPLOYMENT_SERVICE_URL/download/UsefulSQLScripts``` After downloading, extract the UsefulSQLScripts archive, and locate the script in the following path ```UsefulSQLScripts\SQLServer\Realtime\RealtimeCore.sql.```. It's recommended to create this database on the same SQL server hosting the RPI operational databases.

Once the RealtimeCore database has been created, enable the OAuth configuration in the ```values.yaml```

```
realtimeapi:
  authentication:
    type: oauth
```

- **Token endpoint**

To authenticate with RPI Realtime using OAuth, you must request a bearer token from the token endpoint ```https://rpi-realtimeapi.example.com/connect/token```. This endpoint accepts a ```username``` and ```password``` to authenticate the user and returns a ```bearer token```. The bearer token is a time limited credential that authorizes the user to make subsequent calls to the Realtime API.

Example: Requesting a Token and Calling the API

```
# Requesting a Token

TOKEN=$(curl -L -X POST \
  "http://$REALTIME_API_ADDRESS/connect/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "username=$USERNAME" \
  --data-urlencode "password=$PASSWORD" \
  --data-urlencode "client_secret=$CLIENT_SECRET" | jq -r '.access_token')

# Get version information for Realtime API and Realtime Agent
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/system/version" \
 -H "accept: application/json" \
 -H "Authorization: Bearer $TOKEN" | jq 

```

- **Multi-tenancy**

RPI Realtime currently supports a single-tenant architecture. This means that a separate instance of Realtime must be deployed for each RPI tenant, with dedicated queues and cache resources isolated per tenant. For instance, if your RPI cluster includes two tenants such as ```rpi-tenant1``` and ```rpi-tenant2```, you'll need to deploy Realtime separately for each. This is achieved by customizing individual ```values.yaml``` files.

Follow the steps below to set up a multi-tenant deployment.

**Tenant 1**
   -  Define a values file for the tenant e.g ```values-realtime-tenant1.yaml```
   -  Configure the values file with tenant specific queue and cache settings
   -  Disable all other services, ensuring only realtimeapi remains enabled

   ```
   realtimeapi:
     enabled: true
   interactionapi:
     enabled: false
   executionservice:
     enabled: false
   ```

   -  Deploy the tenant

      ```
      helm install realtime-tenant1 redpoint-rpi \
      --values values-realtime-tenant1.yaml --namespace redpoint-rpi
      ```
**Tenant 2**

Repeat the same steps above for Tenant 2, using a separate ```values-realtime-tenant2.yaml``` file configured with tenant-specific queue and cache resources.

### RPI Queue Reader

The [RPI Queue Reader ](https://docs.redpointglobal.com/rpi/admin-queue-reader-setup) service is used to drain Queue Listener and RPI Realtime queues. This container now handles all work previously undertaken by the Web cache data importer, Web events importer and Web form processor system tasks which have been deprecated.

To enabled and configure the Queue Reader, open the ```values.yaml``` file and update the ```queueReader``` section

```
queueReader: 
  enabled: true
  isFormProcessingEnabled: true
  isEventProcessingEnabled: true
  isCacheProcessingEnabled: true
  tenantIds:
    - "<my-rpi-client-id>"
```

The queue reader exposes the following operational endpoints which are available via Ingress:

```
/api/operations/start     – Initiates an operation
/api/operations/status    – Retrieves the current status of an operation
/api/operations/stop      – Stops an ongoing operation
/api/operations/stats     – Returns execution statistics
```

### Post Greenfield Deployment Configuration

 - **Activate RPI License**

After deployment is successful, apply a license activation key. This is done by calling the ```/api/licensing/activatelicense``` endpoint in the deployment service as shown below

```
ACTIVATION_KEY=<my-license-activation-key>
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
SYSTEM_NAME=<my-dev-rpi-system>

curl -X POST "$API_URL" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "ActivationKey": "'"$ACTIVATION_KEY"'",
    "SystemName": "'"$SYSTEM_NAME"'"
  }'
```

A successful activation returns a ```200 OK ``` response. Once RPI is deployed and the license activated, you're ready to proceed with installing your first cluster and adding tenants

 - **Install the cluster operational databases**

```
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
INITIAL_ADMIN_USERNAME=coreuser
INITIAL_ADMIN_PASSWORD=.Admin123
INITIAL_ADMIN_EMAIL=coreuser@example.com

curl -X 'POST' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/installcluster?waitTimeoutSeconds=360" \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d '{
  "UseExistingDatabases": false,
  "CoreUserInitialPassword": "'"$INITIAL_ADMIN_PASSWORD"'",
  "SystemAdministrator": {
    "Username": "'"$INITIAL_ADMIN_USERNAME"'",
    "EmailAddress": "'"$INITIAL_ADMIN_EMAIL"'"
  }
}'

```
Get the install cluster deployment status:
```
curl -X 'GET' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/status" \
  -H 'accept: text/plain'
```
You should receive the ```"Status": "LastRunComplete"``` response to confirm that the cluster deployment has completed successfully.
```
{
  "DeploymentInstanceID": "default",
  "Status": "LastRunComplete",
  "PulseDatabaseName": "Pulse",
  "Messages": [
    "[2024-08-06 03:13:50] Install starting",
    "[2024-08-06 03:13:50] Deployment files already unpacked",
    "[2024-08-06 03:13:50] Operational Database Type: AmazonRDSSQL",
    "[2024-08-06 03:13:50] Pulse Database Name: Pulse",
    "[2024-08-06 03:13:50] Logging Database Name: Pulse_Logging",
    "[2024-08-06 03:13:50] Database Host: rpiopsmssqlserver",
    "[2024-08-06 03:13:50] Core user password has been provided",
    "[2024-08-06 03:13:50] Creating the databases",
    "[2024-08-06 03:13:50] Updating cluster details",
    "[2024-08-06 03:13:50] Updating cluster details",
    "[2024-08-06 03:13:50] Loading Plugins",
    "[2024-08-06 03:13:55] Adding 'what is new'",
    "[2024-08-06 03:13:55] Setting sys admin details"
  ]
}
```
  - **Install the tenant operational databases** 
  
With the cluster deployed, add your first client. To assist in this process, a JSON building tool is available at ```https://$DEPLOYMENT_SERVICE_URL/clienteditor.html```. Use it to construct a JSON payload that aligns with your client's requirements and Datawarehouse options then execute the call below.

```
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
TENANT_NAME=<my-rpi-client-name>
CLIENT_ID=00000000-0000-0000-0000-000000000000
DATAWAREHOUSE_PROVIDER=SQLServer
DATAWAREHOUSE_SERVER=<my-datawarehouse-server>
DATAWAREHOUSE_NAME=<my-datawarehouse-name>
DATAWAREHOUSE_USERNAME=<my-datawarehouse-username>
DATAWAREHOUSE_PASSWORD=<my-datawarehouse-password>

curl -X 'POST' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/addclient?waitTimeoutSeconds=360" \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d "{
  \"Name\": \"$TENANT_NAME\",
  \"Description\": \"My RPI Client X\",
  \"ClientID\": \"$CLIENT_ID\",
  \"UseExistingDatabases\": false,
  \"DatabaseSuffix\": \"$TENANT_NAME\",
  \"DataWarehouse\": {
    \"ConnectionParameters\": {
      \"Provider\": \"$DATAWAREHOUSE_PROVIDER\",
      \"UseDatabaseAgent\": false,
      \"Server\": \"$DATAWAREHOUSE_SERVER\",
      \"DatabaseName\": \"$DATAWAREHOUSE_NAME\",
      \"IsUsingCredentials\": true,
      \"Username\": \"$DATAWAREHOUSE_USERNAME\",
      \"Password\": \"$DATAWAREHOUSE_PASSWORD\",
      \"SQLServerSettings\": {
        \"Encrypt\": true,
        \"TrustServerCertificate\": true
      }
    },
    \"DeploymentSettings\": {
      \"DatabaseMode\": \"SQL\",
      \"DatabaseSchema\": \"dbo\"
    }
  },
  \"TemplateTenant\": \"NoTemplateTenant\",
  \"StartupConfiguration\": {
    \"Users\": [
      \"coreuser\"
    ],
    \"FileOutput\": {
      \"UseGlobalSettings\": true
    }
  }
}"
```

Get the tenant deployment status

```
curl -X 'GET' \
  'https://$DEPLOYMENT_SERVICE_URL/api/deployment/status' \
  -H 'accept: text/plain'
```

You should receive the ```"Status": "LastRunComplete"``` response to confirm that the client deployment has completed successfully.

### Post Upgrade Deployment Configuration

Once the RPI v7 containers have been successfully deployed as described above, you can trigger the upgrade process as shown below

```
curl -X 'GET' \
  'https://$DEPLOYMENT_SERVICE_URL/api/deployment/upgrade?waitTimeoutSeconds=360' \
  -H 'accept: text/plain'
```

You should receive ```"Status": "LastRunComplete"```, and ```Upgrade Complete``` in the response to confirm that the cluster deployment has been completed successfully.

```
{
  "DeploymentInstanceID": "default",
  "Status": "LastRunComplete",
  "PulseDatabaseName": "Pulse",
  "Messages": [
    "[2024-10-09 17:22:49] Upgrade starting",
    "[2024-10-09 17:22:49] Operational Database Type: AmazonRDSSQL",
    "[2024-10-09 17:22:49] Pulse Database Name: Pulse",
    "[2024-10-09 17:22:49] Logging Database Name: Pulse_Logging",
    "[2024-10-09 17:22:49] Database Host: rpiopsmssqlserver",
    "[2024-10-09 17:22:49] Version before upgrade 6.7.24250",
    "[2024-10-09 17:22:49] Upgrading to version 7.4.24278.1712",
    "[2024-10-09 17:22:49] Upgrading the database",
    "[2024-10-09 17:23:35] Updating database version",
    "[2024-10-09 17:23:35] Adding 'what is new'",
    "[2024-10-09 17:23:35] Loading Plugins",
    "[2024-10-09 17:24:19] Upgrade Complete"
  ]
}
```

If any errors occur during the upgrade, the deployment API will provide relevant details in the response. Please analyze these details and resolve any issues before attempting to re-run the upgrade.

 - **Activate RPI License**

After the upgrade operation is successful, apply a license activation key. This is done by calling the ```/api/licensing/activatelicense``` endpoint in the deployment service as shown below.

```
export ACTIVATION_KEY="your_license_activation_key"
export DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
export SYSTEM_NAME="my_dev_rpi_system"

curl -X 'POST' \
  'https://$DEPLOYMENT_SERVICE_URL/api/licensing/activatelicense' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "ActivationKey": "'"${ACTIVATION_KEY}"'",
  "SystemName": "'"${SYSTEM_NAME}"'"
}'
```

A successful activation returns a ```200 OK ``` response. Once RPI is upgraded and the license activated, you're ready to proceed with downloading the Client executable for login and post upgrade validation

 - **Update System Configuration**

RPI stores certain tenant level settings in the operational databases. When cloning the v6 operational databases, these settings are carried over and must be updated to align with the v7 environment. For example, the ```FileOutputDirectory``` used in your v6 cluster might differ from the one intended for your v7 cluster. After the upgrade completes successfully, the RPI administrator should review and update the following settings via the Configuration tab in the RPI client:

```Environment > FileExportLocation```: Sets the Export destinations where: 0 = File Output Directory, 1 = Default FTP Location, 2 = External Content Provider

```Environment > FileOutputDirectory```: Specifies the path within the RPI v7 containers where the FileOutputDirectory volume is mounted. The default path is /fileoutputdir, but consult your Kubernetes administrator if the volume was mounted to a different location.

```Environment > DataManagementUploadDirectory```: Specifies the path within the RPI v7 containers where the DataManagementUploadDirectory volume is mounted. The default path is /rpdmuploaddirectory, but consult your Kubernetes administrator if the volume was mounted to a different location.

```Channels >  Channel name```:  Update relevant configuration to match your v7 requirements

### Configure Open ID Connect
RPI supports the use of the AzureAD, Okta and KeyCloak [OpenID connection (OIDC) ](https://docs.redpointglobal.com/rpi/admin-authentication) providers to be used to authenticate users accessing RPI. To integrate an OIDC provider with your environment, update the settings in the ```OpenIdProviders``` section of the ```values.yaml``` file. Adjust these values to match your environment's configuration

```
OpenIdProviders:
  enabled: true
  name: AzureAD
```

### Configure Security Context
RPI containers run under a preconfigured non-root user and group ```(uid: 7777, gid: 777)``` in alignment with container security best practices. While Kubernetes does allow overriding this securityContext, doing so introduces a challenge: the application directory (/app) and its contents are owned by the default user ```(7777:777)```, and changing the runtime user requires reconciling file ownership and permissions within the container.

If your organization enforces a specific runAsUser and runAsGroup policy, we recommend creating a custom container image that builds on top of our published base image. This allows you to:

 - Define the required user and group IDs during the image build process
 - Adjust ownership and permissions of key directories—such as /app—to match the expected runtime security context

Below is an example of how to adapt the container image for use in the interactionapi service deployment:
```
FROM rg1acrpub.azurecr.io/docker/redpointglobal/releases/rpi-interactionapi

# Switch to root to change ownerships
USER root

# Define the new runtime user and group
ENV RUNTIME_USER=redpointrpi
ENV RUNTIME_UID=10001
ENV RUNTIME_GROUP=redpointrpi
ENV RUNTIME_GID=10001

# Create group and user using the compatible syntax
RUN addgroup \
    --gid "$RUNTIME_GID" \
    "$RUNTIME_GROUP" \
 && adduser \
    --disabled-password \
    --gecos "" \
    --home /app \
    --ingroup "$RUNTIME_GROUP" \
    --no-create-home \
    --uid "$RUNTIME_UID" \
    "$RUNTIME_USER"

# Fix permissions for volume-mountable dirs
RUN chown -R "$RUNTIME_UID":"$RUNTIME_GID" /app /app/logs /app/.dotnet-tools /app/.dotnet-counters

USER "$RUNTIME_UID":"$RUNTIME_GID"
```
### Configure Content Generation Tools

RPI integrates with OpenAI services and Azure Cognitive Search for [external content generation](https://docs.redpointglobal.com/rpi/configuring-external-content-generation-tools). To enable this integration, provide credentials for your OpenAI APIs and Cognitive Search components. The Model subsection includes storage settings for embedding vectors, such as ModelDimensions, the Azure Storage ConnectionString, and the target ContainerName and BlobFolder where model data is stored.

Open the ```values.yaml``` file and navigate to the ```redpointAI``` section. Update this section with your configuration details. Inline comments are included within the values.yaml file to explain each key-value pair

```
redpointAI:
  enabled: true 
```
### Configure Custom Metrics

RPI services expose a ```/metrics``` endpoint for scrapping using Prometheus. For the web services, this endpoint provides a collection of default .NET metrics. Other services expose custom metrics specific to their core functionalities. Before enabling custom metrics, ensure that you already have Prometheus running in your cluster and configured to target the rpi namespace for scraping.

- The **Execution Service:** displays the number of activities currently running, the total executed since startup, and the maximum number of activities it is configured to handle. You can create dashboards in Grafana for visualization with the following metrics:

  - ```execution_max_thread_count:``` This is the value configured for `RPIExecution__MaxThreadsPerExecutionService`. It defines the limit on how many work items an execution service can take on.

  - ```execution_total_executing_count:``` This is the actual number of work items an execution service is running. It can be used, in relation to ```execution_max_thread_count```, to set a threshold at which to scale up or down the number of execution services running.

```
- execution_client_jobs_executing_count:  Number of client jobs currently executing.
- execution_tasks_executing_count:        Number of system tasks currently executing.
- execution_workflows_executing_count:    Number of workflow activities currently executing.
- execution_client_jobs_completed_count:  Number of client jobs that have completed execution.
- execution_tasks_completed_count:        Number of system tasks that have completed execution.
- execution_workflows_completed_count:    Number of workflow activities that have completed.
- execution_workflows_suspended_count:    Number of workflow activities that have been suspended.
```

- The **Node Manager:** tracks the number of activities allocated to execution services and the number of triggers it fires. You can create dashboards in Grafana for visualization with the following metrics:

```
- node_manager_activities_allocated_count: Number of workflow activities allocated.
- node_manager_tasks_allocated_count:      Number of system tasks allocated by the Node Manager.
- node_manager_triggers_fired_count:       Number of triggers fired by the Node Manager.
```

- The **Queue Reader:** counts the number of items processed in its various queues, giving visibility into queue consumption and throughput. You can create dashboards in Grafana for visualization with the following metrics:

```
- queue_listener_valid_queue_listener_messages
- queue_listener_invalid_queue_listener_messages
```

To enable custom metrics, set the following value in your ```values.yaml```

```
customMetrics:
  enabled: true
```

### Configure High Availability

This chart deploys RPI in HA mode using Kubernetes' native Horizontal Pod Autoscaler (HPA). Alternatively, you can disable the HPA and configure fixed replica counts directly in the ```values.yaml```, as demonstrated below

- **HA mode with static replicasets**

```
realtimeapi:
  autoscaling:
    enabled: false
  replicas: 2
interactionapi:
  autoscaling:
    enabled: false
  replicas: 2
executionservice:
  autoscaling:
    enabled: false
  replicas: 2
nodemanager:
  autoscaling:
    enabled: false
  replicas: 2
```

- **HA mode with kubernetes autoscaling (HPA)**

```
autoscaling:
  enabled: true
  type: hpa
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

### Configure Autoscaling with custom metrics

When you enable custom metrics as described in the [Configure Custom Metrics](#configure-custom-metrics) section above. You can leverage [ KEDA ](https://keda.sh/), a Kubernetes-based Event Driven Autoscaler to act on them. Prepare your cluster by:

- Install and configure KEDA according to your Kubernetes platform's setup instructions
- Set the autoscaling type to ```keda``` in the ```values.yaml```.

The Helm Chart will deploy a ```ScaledObject``` that instructs KEDA to query Prometheus for the value of the specified metric for example ```execution_max_thread_count```. When the metric reaches a predefined threshold, KEDA triggers horizontal scaling, increasing the ```maxReplicaCount``` to accommodate the additional load. Conversely, when the load decreases, KEDA scales the replicas back down ```minReplicaCount```, optimizing resource usage and reducing costs.

To configure autoscaling based on custom metrics, update your ```values.yaml``` with the following values:

```
autoscaling:
  enabled: true
  type: keda
  kedaScaledObject:
    serverAddress: <my-prometheus-query-endpoint>
    metricName: <my-metrics-name>.
    query: <my-prometheus-promq-query>
    threshold: "90"
    pollingInterval: 15
    minReplicaCount: 2
    maxReplicaCount: 5
```

Enable the preferred autoscaling type for each service independently by setting autoscaling.type to either keda or hpa in the values.yaml configuration. Both types can coexist, allowing you to fine-tune autoscaling strategies on a per-service basis.

```
NAME                  REFERENCE                     TARGETS       MINPODS   MAXPODS   REPLICAS
keda-hpa              Deployment/executionservice   1/90 (avg)       2         5         2
rpi-callbackapi       Deployment/callbackapi        cpu: 0%/80%      1         5         1
rpi-integrationapi    Deployment/integrationapi     cpu: 0%/80%      1         5         1
rpi-interactionapi    Deployment/interactionapi     cpu: 15%/80%     1         5         1
rpi-realtimeapi       Deployment/realtimeapi        cpu: 0%/80%      1         5         1

```
The Helm Chart deploys a scaling object for a single custom metric, but you can extend it to create more ScaledObjects. Below is an example of configuring a custom ScaledObject with Azure Workload Identity authentication.

```
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: rpi-executionservice
  namespace: redpoint-rpi
spec:
  podIdentity:
      provider: azure-workload
      identityId: <my-workload-identity-id>

---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: rpi-executionservice
  namespace: redpoint-rpi
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rpi-executionservice
  triggers:
    - type: prometheus
      metadata:
        serverAddress: https://my-example.prometheus.com
        metricName: execution_tasks_executing_count
        query:  <my-prometheus-promq-query>
        threshold: "80"
        authenticationRef:
          name: rpi-executionservice
  pollingInterval: 15
  minReplicaCount: 2
  maxReplicaCount: 5
```

### RPI Documentation
To explore in-depth documentation and stay updated with the latest release notes for RPI, be sure to visit the [RPI Documentation Site ](https://docs.redpointglobal.com/rpi/)

### Getting Support 
If you encounter any challenges specific to the RPI application, our dedicated support team is here to assist you. Please reach out to us with details of the issue for prompt and expert help using [support@redpointglobal.com](support@redpointglobal.com)

```Note on Scope of Support```
While we are fully equipped to address issues directly related to the RPI application, please be aware that challenges pertaining to Kubernetes configurations, network connectivity, or other external system issues fall outside our support scope. For these, we recommend consulting with your IT infrastructure team or seeking assistance from relevant technical forums.
