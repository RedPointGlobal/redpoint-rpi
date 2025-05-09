![rp_cdp_logo](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/432d779f-de4e-4936-80fe-3caa4d732603)
## Redpoint Interaction (RPI) | Deployment on Kubernetes
With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

In this guide, we take a Step-by-Step deployment of Redpoint Interaction (RPI) on Kubernetes using HELM.
![image](https://user-images.githubusercontent.com/42842390/229413149-ff9497cd-8ed4-4512-96e1-c71932680350.png)
### Table of Contents
- [System Requirements ](#system-requirements)
- [Considerations Before you begin ](#considerations-before-you-begin)
- [Accessing RPI Services URLs ](#accessing-rpi-services-urls)
- [Downloading Client Executable ](#downloading-client-executable)
- [Configuring Storage ](#configuring-storage)
- [Configuring Realtime Queue Providers](#configuring-realtime-queue-providers)
- [Configuring Realtime Cache Providers](#configuring-realtime-cache-providers)
- [Configuring Realtime Queue Reader](#configuring-realtime-queue-reader)
- [Configuring Cluster and Tenants](#configuring-cluster-and-tenants)
- [Configuring Open ID Connect (OIDC)](#configuring-open-id-connect)
- [Configuring High Availability ](#configuring-high-availability)
- [Configuring License Activation ](#configuring-license-activation)
- [RPI Documentation](#rpi-documentation)
- [Getting Support](#getting-support)

### System Requirements
- **SQL Server 2019 or later for the Operational Databases**
    - Any of the of the following: ```SQLServer```, ```AzureSQLDatabase```, ```AmazonRDSSQL```, ```GoogleCloudSQL```, ```PostgreSQL```
    - 8 GB Memory or more
    - 200 GB or more free disk space.
- **Any of the following for the Data Warehouse Settings**
    - ```AzureSQLDatabase```, ```AmazonRDSSQL```, ```GoogleCloudSQL```, ```MicrosoftSQLServer```, ```AzureDatabaseMySQL```, ```AzureDatabasePostgreSQL```, ```Snowflake```, ```PostgreSQL```

- **Kubernetes Cluster:**

Latest stable version of Kubernetes. Select from this list of [Kubernetes certified solution providers](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/). From each provider page, you can learn how to install and setup production ready clusters.

-  Nodepools Sizing
    - 4 vCPUs per node
    - 8 GB of Memory per node
    - Minimum of 2 nodes for high availability

The Kubernetes nodepool and SQL server sizing requirements outlined above represent the minimum requirements for running RPI in a modest environment. These settings may need to be adjusted based on your production environment and specific use case. Please ensure you tailor the configurations to meet your production requirements.

### Prerequisites
| Ensure that the following requirements are met!                                                                                                                                                                                                                                   |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| - **Redpoint Container Registry:** Open a [Support](mailto:support@redpointglobal.com) ticket requesting access to download RPI images.<br><br> - **RPI License:** Open a [Support](mailto:support@redpointglobal.com) ticket to obtain your RPI v7 License activation key.<br><br> - **Kubectl:** Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), a command-line tool for interacting with your Kubernetes cluster.<br><br> - **Helm:** Install [Helm](https://helm.sh/docs/helm/helm_install/) and ensure you have the required permissions from your Kubernetes Administrator to deploy applications in the target cluster. |

### Considerations Before you begin
Before deploying RPI, it's important to determine whether you're planning a Greenfield deployment or an Upgrade deployment.

- **Greenfield Deployment:** This approach involves setting up RPI in a completely new environment. It includes the creation of a new RPI cluster, a new RPI tenant, fresh operations and logging databases, and new cache and queue providers. A Greenfield deployment ensures that all components are deployed from scratch, independent of any existing deployments.

- **Upgrade Deployment:** In this case, RPI is being deployed into an existing version 6.x environment. This includes using the current cluster, tenant, operations and logging databases, cache, and queue providers, with the RPI v7 containers being added to the existing setup. The upgrade from RPI v6.x to RPI v7.x is more involved. Before attempting to upgrade, be sure to read the [Redpoint Interaction upgrade path](https://docs.redpointglobal.com/bpd/upgrade-to-rpi-v7-x)
  
![upgrade-start](https://github.com/user-attachments/assets/c6e517ed-89ba-4045-8686-c5ad8bc8c9a2)

Both deployment methods require you to deploy the RPI v7 containers following the same steps. However, the post-deployment configuration steps will differ. Details for each method are outlined in the [Post Deployment- Greenfield](#post-deployment-greenfield) and [Post Deployment- Upgrade](#post-deployment-upgrade) sections below.

**To start the deployment, follow the steps outlined in Steps 1-6 below.**

**1 Clone this repository**

  - Cloning the repository locally ensures you have an independent copy of the project, which is not directly affected by upstream changes. It also gives you control over versioning.

```
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
```

**2. Create Kubernetes Namespace:**

  - A Kubernetes namespace provides a logical separation within the cluster. By creating a dedicated namespace for RPI services, you ensure that the resources and configurations for this project do not interfere with others in your cluster

```
kubectl create namespace redpoint-rpi 
```

**3. Create Container Registry Secret:**

 - Create a Kubernetes secret for ```imagePull```. This secret will store the credentials required to pull RPI images from the Redpoint container registry. Obtain these credentials from Redpoint Support and replace ```<your_username>``` and ```<your_password>``` with your actual credentials:
```
export DOCKER_USERNAME=<your_username> 
export DOCKER_PASSWORD=<your_password>
export DOCKER_SERVER=rg1acrpub.azurecr.io
export NAMESPACE=redpoint-rpi

kubectl create secret docker-registry redpoint-rpi \
--namespace $NAMESPACE \
--docker-server=$DOCKER_SERVER \
--docker-username=$DOCKER_USERNAME \
--docker-password=$DOCKER_PASSWORD
```

**4. Create TLS Certificate Secret:**

  - The Helm chart deploys an ingress resource and an NGINX ingress controller to expose the URL endpoints required for accessing RPI services. These endpoints are secured using HTTPS. The only requirement on your part is to provide a TLS certificate for TLS termination.

To add the certificate, create a Kubernetes secret. Replace ```path/to/your_cert.crt``` and ```path/to/your_cert.key``` with the actual paths to your certificate files:
```
export CERT_FILE=path/to/your_cert.crt
export KEY_FILE=path/to/your_cert.key
export NAMESPACE=redpoint-rpi

kubectl create secret tls ingress-tls \
--namespace $NAMESPACE \
--cert=$CERT_FILE \
--key=$KEY_FILE
```

With the secret created, you need to specify the domain for your ingress configuration. This domain will be used to construct the URLs that users will use to access RPI. To do this, open the ```values.yaml``` file and find the ingress.domain section. Replace ```example.com``` with your actual domain name:
```
ingress:
  domain: example.com
```
If you prefer to use a custom ingress controller rather than the NGINX ingress controller provided by the chart, you can disable the built-in controller. To do this, set the ```ingress.controller.enabled``` setting to false as shown below:
```
ingress:
  controller:
    enabled: false
```

**5. Set your target Cloud Provider:**

  - Open the ```values.yaml``` file and locate the ```cloud``` section. Here, specify the cloud provider where you intend to deploy RPI. Supported options are: ```azure```, ```amazon```, ```google```

```
  cloud: amazon
```

**6. Configure SQL Server Settings:**

  - Open the ```values.yaml``` file, locate the ```databases``` section. Here, you need to provide the correct values for your SQL Server configuration. This includes specifying the database type, server host, username and password. The Supported options for database type are ```sqlserver```, ```azuresqlserver```, ```amazonrdssql```, ```postgresql```, and  ```googlecloudsql```

```
databases: 
  type: amazonrdssql
  serverhost: your_sql_server_host
  username: your_sql_username
  password: your_sql_password
  operationsDatabaseName: Pulse
  loggingDatabaseName: Pulse_Logging
```

**7. Install RPI:**
  - Make sure you are in the cloned repository's directory and run the Helm install command
```
.
├── README.md
├── UpgradeAssistant.zip
├── kubernetes
├── redpoint-rpi
├── smoketests
└── values.yaml

helm install redpoint-rpi redpoint-rpi/ --values values.yaml
```

If everything goes well, You should see the output below.
```
NAME: redpoint-rpi
LAST DEPLOYED: Sat Feb  1 02:31:46 2025
NAMESPACE: redpoint-rpi
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
********************************* SUCCESS! *********************************
```
It may take some time for all the RPI services to fully initialize. We recommend waiting approximately 5-10 minutes to ensure that the services are completely up and running. 

### Accessing RPI Services URLs

To interact with RPI services, such as client login or using the integration API, you need to obtain the URL endpoints exposed by the ingress. Use the following command to list the ingresses in the redpoint-rpi namespace
```
kubectl get ingress --namespace redpoint-rpi
```
Initially, you might not see an IP address for your endpoints. This is normal and occurs because provisioning the ingress load balancer takes some time. If no IP address is displayed, wait a few minutes and then re-run the command. Once the load balancer is ready, you should see output similar to the following, where ```<Load Balancer IP>``` will be replaced with the actual IP address:
```
NAME           HOSTS                                  ADDRESS              PORTS     AGE
redpoint-rpi   rpi-deploymentapi.example.com          <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-interactionapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-integrationapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-realtimeapi.example.com            <Load Balancer IP>   80, 443   32d
```

Add DNS records for the above hosts in your DNS zone. This ensures that the domain names you use for example ```rpi-interactionapi.example.com``` correctly route to your RPI instance.

With the DNS configuration in place, RPI Services can be accessed at the follwing addresses:
```
rpi-deploymentapi.example.com                                 # Deployment Service
rpi-interactionapi.example.com                                # RPI Client hostname
rpi-deploymentapi.example.com/api/deployment/downloads/Client # RPI Client Executable Download
rpi-integrationapi.example.com                                # Integration API
rpi-realtimeapi.example.com                                   # RPI Realtime
```

### Post Deployment- Greenfield

 - **Activate RPI License**

Next step afer the deployment is successful - is to apply a license activation key. This is done by calling the ```/api/licensing/activatelicense``` endpoint in the deployment service. Below is an example of how to make the API call for license activation:

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

A successful activation returns a ```200 OK ``` response. Once RPI is deployed and the license activated, you're ready to proceed with installing your first cluster and adding tenants

 - **Install the cluster operational databases**

```
export DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
export INITIAL_ADMIN_USERNAME=coreuser
export INITIAL_ADMIN_PASSWORD=.Admin123
export INITIAL_ADMIN_EMAIL=coreuser@example.com

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
  
Once the cluster deployment is complete, you can proceed to add your first RPI tenant (client). To assist in this process, a JSON building tool is available at ```https://$DEPLOYMENT_SERVICE_URL/clienteditor.html``` which can help you construct the necessary payload for your tenant setup. After constructing the JSON payload that aligns with your tenant's requirements and Datawarehouse options, simply execute the commands below to add the tenant

```
# Export environment variables
export DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
export TENANT_NAME=My_RPI_Tenant1
export CLIENT_ID="00000000-0000-0000-0000-000000000000"
export DATAWAREHOUSE_PROVIDER=SQLServer
export DATAWAREHOUSE_SERVER=your_datawarehouse_server
export DATAWAREHOUSE_NAME=your_datawarehouse_name
export DATAWAREHOUSE_USERNAME=your_datawarehouse_username
export DATAWAREHOUSE_PASSWORD=your_datawarehouse_password

curl -X 'POST' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/addclient?waitTimeoutSeconds=360" \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d "{
  \"Name\": \"$TENANT_NAME\",
  \"Description\": \"My RPI Tenant 1\",
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

### Post Deployment- Upgrade

Once the RPI v7 containers have been successfully deployed using the Helm deployment instructions in ```Step 1-7``` above, you are now ready to perform the upgrade. This is done by making the following API call to trigger the upgrade process.

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

Next step afer the upgrade operation is successful - is to apply a license activation key. This is done by calling the ```/api/licensing/activatelicense``` endpoint in the deployment service. Below is an example of how to make the API call for license activation:

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

### Downloading Client Executable

To connect to the RPI server, you'll need the RPI Client. This client is included with the Interaction API in a zip file that you can download to your workstation. To get the client, use the following URL: Replace ```example.com``` with the actual domain name used for your ingress.

```
https://rpi-interactionapi.example.com/downloads/Client
```

### Configuring High Availability

The default deployment of RPI services is configured with a single replica for each service. However, for a production environment, it's crucial to ensure high availability to maintain service continuity and manage load efficiently.

To achieve high availability, adjust the number of replicas for each service to 2 or more. Additionally, the cluster admin can create a [Horizontal Pod Autoscaler (HPA)](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) to automatically manage the number of pod replicas based on observed CPU utilization or other select metrics. Here’s how you can set the replica count in the ```values.yaml``` file:
```
replicas:
  interactionapi: 2
  integrationapi: 2
  deploymentapi: 2
  callbackapi: 2
  nodemanager: 2
  executionservice: 2
  realtimeapi: 2
```
### Configuring Storage

RPI requires the following for it's Storage requirements

 - File Share storage (SMB or NFS) used as a [File Output directory ](https://docs.redpointglobal.com/rpi/file-output-directory) for storing any file assets exported via interactions or selection rules
 - Cloud Storage used to support an [External content provider (ECP)](https://docs.redpointglobal.com/rpi/external-content-provider-configuration)

The RPI Helm chart is intentionally non-opinionated on storage solutions. Users are expected to create their own storage configurations based on their Cloud provider's requirements. Simply provide the name of the persistent volume in the `values.yaml` file:

To enable this storage, update the ```values.yaml``` as shown below
```
  storage:
    enabled: true
    persistentVolumeClaim: rpifileoutputdir
```
### Configuring Realtime Queue Providers

[Queue Providers ](https://docs.redpointglobal.com/rpi/configuring-realtime-queue-providers) are used to provide RPI with message queuing capabilities. 

To configure a Queue Provider, Open the ```values.yaml``` file and locate the ```queueProviders``` section. Here, specify the Queue provider you intend to use. Supported options are: ```rabbitmq ```, ```googlepubsub```,```azureeventhubs ```, ```azureservicebus```,```azurestoragequeues```

```
queueProviders: 
  type: amazonsqs 
```
### Configuring Realtime Cache Providers

The [Cache connectors ](https://docs.redpointglobal.com/rpi/cache-configuration) allow RPI to store and access various data quickly (in-memory), such as Visitor Profiles, Realtime Decisions rules, and content. This enables immediate action within data dependent websites, without the delays of retrieving information back from the database.

To configure a Cache Provider, Open the ```values.yaml``` file and locate the ```cacheProviders``` section. Here, specify the Cache provider you intend to use. Supported options are: ```mongodb```, ```cassandra ```, ```redis``` ,```googlebigtable``` ```inMemorySql``` and ```azurecosmosdb```

```
cacheProviders: 
  type: mongodb
```

For the selected cache provider, include the required connection details in the corresponding section of the ```values.yaml```. For instance, if ```mongodb``` is chosen as the cache provider, the configuration might look like this:

```
  mongodb: 
    databaseName: your_rpi_cache_database_name
    ConnectionString: your_mongodb_connection_string
    CollectionName: your_rpi_cache_collection_name
```

**Note:** When using the RPI SQL Server native cache provider, you can download the necessary setup scripts for SQL Server in-memory cache tables from the deployment service's downloads page: ```https://$DEPLOYMENT_SERVICE_URL/download/UsefulSQLScripts``` After downloading, extract the UsefulSQLScripts archive, and locate the script in the following path ```UsefulSQLScripts\SQLServer\Realtime\In Memory Cache Setup.sql.``` 

### Configuring Realtime Queue Reader
A new dedicated  [Queue Reader ](https://docs.redpointglobal.com/rpi/admin-queue-listener-setup) container has been introduced in RPI v7.4, which is responsible for the draining of Queue listener and RPI Realtime queues.

The new container supports operation in two modes:

***Distributed mode:*** facilitates more than one queue reader service draining the same queue. Allows for scaling to improve processing performance. Interim data is stored in an external (redis) cache and queue (any queue provider, but preferably local), which also protects against data loss.

***Non-distributed mode:*** all work for a single queue is handled by a single service. There is no need for an external queue or cache to hold interim data.

The container now handles all work previously undertaken by the Web cache data importer, Web events importer and Web form processor system tasks which have been deprecated:

To configure the Queue Reader, open the ```values.yaml``` file and update the ```queueReader``` section

```
queueReader: 
  isEnabled: true
  isFormProcessingEnabled: true
  isEventProcessingEnabled: true
  isCacheProcessingEnabled: true
  isDistributed: false 
  tenantIds: ["your_clientId_1", "your_clientId_2"]
  useMessageLocks: true
```
### Configuring Open ID Connect (OIDC)
RPI supports OpenID Connect (OIDC) for authentication. To integrate an OIDC provider with your environment, update the settings in the ```OpenIdProviders``` section of the ```values.yaml``` file. Adjust these values to match your environment's configuration

```
OpenIdEnabled: true
OpenIdProviders:
  Name: AzureAD
```
For more information related to these settings please refer to  [Admin: Appendix B - Open ID Connect (OIDC) configuration ](https://docs.redpointglobal.com/rpi/admin-appendix-b-open-id-connect-oidc-configuratio)

### RPI Documentation
To explore in-depth documentation and stay updated with the latest release notes for RPI, be sure to visit our documentation site by clicking the link below

 [Redpoint Documentation Site ](https://docs.redpointglobal.com/rpi/)

### Getting Support 
If you encounter any challenges specific to the RPI application, our dedicated support team is here to assist you. Please reach out to us with details of the issue for prompt and expert help.

[support@redpointglobal.com](support@redpointglobal.com)

```Note on Scope of Support```
While we are fully equipped to address issues directly related to the RPI application, please be aware that challenges pertaining to Kubernetes configurations, network connectivity, or other external system issues fall outside our support scope. For these, we recommend consulting with your IT infrastructure team or seeking assistance from relevant technical forums.
