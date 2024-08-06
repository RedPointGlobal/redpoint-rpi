![rp_cdp_logo](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/432d779f-de4e-4936-80fe-3caa4d732603)
## Redpoint Interaction (RPI) | Deployment on Kubernetes
With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

In this guide, we take a Step-by-Step deployment of Redpoint Interaction (RPI) on Kubernetes using HELM.
![image](https://user-images.githubusercontent.com/42842390/229413149-ff9497cd-8ed4-4512-96e1-c71932680350.png)
### Table of Contents
- [System Requirements ](#system-requirements)
- [Before You Begin ](#before-you-begin)
- [Greenfield Installation ](#greenfield-installation)
- [Upgrade Installation ](#upgrade-installation)
- [Demo Installation ](#demo-installation)
- [Accessing RPI Services URLs ](#accessing-rpi-services-urls)
- [Configuring Storage ](#configuring-storage)
- [Configuring Realtime Queue Providers](#configuring-realtime-queue-providers)
- [Configuring Realtime Cache Providers](#configuring-realtime-cache-providers)
- [Configuring Cluster and Tenants](#configuring-cluster-and-tenants)
- [Configuring High Availability ](#configuring-high-availability)
- [Configuring License Activation ](#configuring-license-activation)
- [RPI Documentation](#rpi-documentation)
- [Getting Support](#getting-support)

### System Requirements
- **SQL Server 2019 or later**
    - Any of the of the following: ```Azure SQL Database```, ```Amazon RDS```, ```Google Cloud SQL```, ```Microsoft SQL Server```
    - 8 GB Memory or more
    - 256 GB or more free disk space.

- **Kubernetes Cluster:**

Latest stable version of Kubernetes. Select from this list of [Kubernetes certified solution providers](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/). From each provider page, you can learn how to install and setup production ready clusters.

-  Nodepools Sizing
    - 8 vCPUs per node
    - 16 GB of Memory per node
    - Minimum of 2 nodes for high availability

### Before you begin
| Ensure that the following requirements are met!                                                                                                                                                                                                                                   |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| - **Redpoint Container Registry** [Open a support ticket](mailto:support@redpointglobal.com) requesting access to download RPI container images.<br><br> - **RPI License:** [Open a support ticket](mailto:support@redpointglobal.com) to obtain your RPI v7 License activation key.<br><br> - Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), a command-line tool for interacting with your Kubernetes cluster.<br><br> - Install [Helm](https://helm.sh/docs/helm/helm_install/) and ensure you have the required permissions from your Kubernetes Administrator to deploy applications in the target cluster. |

### Greenfield Installation
In a Greenfield installation, you're setting up RPI in a completely new environment. This includes: a new RPI cluster, new RPI tenant, new operations and logging databases, new cache and queue providers. This approach ensures that all components are installed fresh and independent of any existing deployments. 

Follow the following steps to get started

**1. Set your target Cloud Provider:**

Open the ```values.yaml``` file and locate the ```cloud``` section. Here, specify the cloud provider where you intend to deploy RPI. Supported options are: ```azure```, ```amazon```, ```google``` and ```selfhosted```
```
  cloud: amazon
```
**2. Configure SQL Server Settings:**

Open the ```values.yaml``` file, locate the ```databases``` section. Here, you need to provide the correct values for your SQL Server configuration. This includes specifying the database type, server host, username and password. The Supported options for database type are ```sqlserver```, ```azuresql```, ```amazonrds```, ```postgresql```, and  ```googlecloudsql```
```
databases: 
  type: amazonrds
  serverhost: your_sql_server_host
  username: your_sql_username
  password: your_sql_password
  operationsDatabaseName: Pulse
  loggingDatabaseName: Pulse_Logging
```
**3. Create Kubernetes Namespace:**

Run the following command to create the Kubernetes namespace for deploying RPI services and set it as the default context for future CLI commands
```
kubectl create namespace redpoint-rpi && \
kubectl config set-context --current --namespace=redpoint-rpi
```
**4. Create Container Registry Secret:**

Run the following command to create a Kubernetes secret for ```imagePull```. This secret will store the credentials required to pull RPI images from the Redpoint container registry. Obtain these credentials from Redpoint Support and replace ```<your_username>``` and ```<your_password>``` with your actual credentials:
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
**5. Create TLS Certificate Secret:**

The Helm chart deploys an ingress resource and an NGINX ingress controller to expose the URL endpoints required for accessing RPI services. These endpoints are secured using HTTPS. The only requirement on your part is to provide a TLS certificate for TLS termination.

To add the certificate, run the following command to create a Kubernetes secret. Replace ```path/to/your_cert.crt``` and ```path/to/your_cert.key``` with the actual paths to your certificate files:
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
**6. Install RPI:**
  - Clone the RPI repository to your local machine
  - Change into the cloned repository's directory
  - Execute the Helm install command
```
git clone https://github.com/RedPointGlobal/redpoint-rpi.git && \
cd redpoint-rpi && \
helm install redpoint-rpi redpoint-rpi/ --values values.yaml
```

If everything goes well, You should see the output below.
```
NAME: redpoint-rpi
LAST DEPLOYED: Sat July  1 02:31:46 2024
NAMESPACE: redpoint-rpi
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
********************************* SUCCESS! *********************************
```
It may take some time for all the RPI services to fully initialize. We recommend waiting approximately 5-10 minutes to ensure that the services are completely up and running. 

### Accesing RPI Services URLs

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

### Configuring License Activation

After installing RPI, you need to apply a license. This is accomplished by calling the ```/api/licensing/activatelicense``` API endpoint of the deployment service, as demonstrated in the example below:

```
export ACTIVATION_KEY="your_license_activation_key"
export ACTIVATION_URL=rpi-deploymentapi.example.com
export SYSTEM_NAME="my_dev_rpi_system"

curl -X 'POST' \
  'https://$ACTIVATION_URL/api/licensing/activatelicense' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "ActivationKey": "'"${ACTIVATION_KEY}"'",
  "SystemName": "'"${SYSTEM_NAME}"'"
}'
```
With RPI installed and the license activated, you're now ready to install your first cluster and add tenants.

### Configuring Cluster and Tenants

If you have completed a [Greenfield Installation](#greenfield-installation) of RPI, there are two additional steps needed to prepare it for user access. These steps involve using the deployment service API to set up the operational databases required for the RPI cluster and for each new RPI tenant (client). Please refer to the examples below:

  - **Install Cluster:** 

Run the following command to install the cluster
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
To check the status of the cluster installation, execute the following command:
```
curl -X 'GET' \
  'https://$DEPLOYMENT_SERVICE_URL/api/deployment/status' \
  -H 'accept: text/plain'
```
You should receive the ```"Status": "LastRunComplete"``` response to confirm that the cluster installation has been completed successfully.
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
  - **Add Client:** 
  
Once the cluster installation is complete, you can proceed to add your first RPI tenant (client). To do this, execute the following command:

```
# Export environment variables
export DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
export TENANT_NAME=My_RPI_Tenant1
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
  \"ClientID\": \"\",
  \"UseExistingDatabases\": false,
  \"DatabaseSuffix\": \"$TENANT_NAME\",
  \"DataWarehouse\": {
    \"ConnectionParameters\": {
      \"Provider\": \"SQLServer\",
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
To check the status of the client installation, execute the following command:
```
curl -X 'GET' \
  'https://$DEPLOYMENT_SERVICE_URL/api/deployment/status' \
  -H 'accept: text/plain'
```
You should receive the ```"Status": "LastRunComplete"``` response to confirm that the cluster installation has been completed successfully.

### Upgrade Installation

In an Upgrade installation, you will set up RPI in an existing version 6.x environment, which includes an existing cluster, tenant, operations and logging databases, cache, and queue providers.

Before performing the upgrade, use the ```Interaction Upgrade``` Helper to check the v7 compatibility of all plugins currently used in your version 6 installation. Follow these steps:

  - Download and extract the [Upgrade Helper](https://github.com/RedPointGlobal/redpoint-rpi/blob/main/UpgradeAssistant.zip)
  - Execute the ```RedPoint.Interaction.UpgradeHelper```application. 
  
When running the Helper, you will be prompted to enter a v6 Pulse database connection string. Once connected, the Helper will check the compatibility of all currently used plugins with v7. If any incompatible plugins are found, their details will be displayed, and you will have the option to output this information to a file.

The resulting file will contain details about the incompatible plugins along with a set of v7 environment variables. An example output is shown below:
```
{
  "General": {
    "ConnectionStrings__OperationalDatabase": "[your_v6_connection_string],
    "ConnectionStrings__LoggingDatabase": "[your_v6_connection_string]",
    "RPI__ServiceHostName": "your_v6_rpi_hostname",
    "RPI__SMTP__EmailSenderAddress": "[x]",
    "RPI__SMTP__Address": "[x]",
    "RPI__SMTP__Port": 587,
    "RPI__SMTP__EnableSSL": false,
    "RPI__SMTP__UseCredentials": false
  },
  "Execution": {
    "RPIExecution__QueueListener__IsEnabled": true,
    "RPIExecution__QueueListener__QueuePath": "RPIListenerQueue"
  },
  "InteractionAPI": {
    "RPIClient__HelpStartPageURL": "[x]"
  }
}
```
Use the contents of this file as a reference to customize the ```values.yaml``` file for the Helm Chart before deploying the new v7 cluster. For instance, you will need to update the SMTP and database connection strings in the ```values.yaml``` based on the information provided in the example.

To perform the upgrade, follow the same steps outlined in the [Greenfield Installation](#greenfield-installation) section. The key differences are

  - **SQL Server Configuration:** Ensure your SQL server configuration, caches and queues provider settings all point to your current RPI version 6 environment.

  - **Helm Chart Customization:** Modify the Helm Chart to incorporate the details provided in the Upgrade Assistant output. Update the ```values.yaml``` file with the relevant environment variables and configuration settings from the output to ensure compatibility with v7.

### Demo Installation
In a Demo installation, RPI is set up using the default configurations provided by the Helm Chart. This includes:

  - Containerized SQL Server for the Operations databases
  - Redis as the Cache Provider
  - RabbitMQ as the Queue Provider
  - Self-signed certificate used for Ingress

These components are pre-configured and deployed automatically, allowing you to quickly get started with a fully functional setup.

To perform a demo installation, open the values.yaml file and set the cloud value to demo:
```
cloud: demo
```
### Configuring High Availability

The default installation of RPI services is configured with a single replica for each service. However, for a production environment, it's crucial to ensure high availability to maintain service continuity and manage load efficiently.

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

 - File Share storage (SMB or NFS) used as a File Output directory for storing any file assets exported via interactions or selection rules
 - Cloud Storage (Blob or S3) used to support an RPI external content provider (ECP)

The RPI Helm chart is intentionally non-opinionated on storage solutions. Users are expected to create their own storage configurations based on their Cloud provider's requirements. Simply provide the name of the persistent volume in the `values.yaml` file:

To enable this storage, update the ```values.yaml``` as shown below
```
  storage:
    enabled: true
    persistentVolumeClaim: rpifileoutputdir
```
### Configuring Realtime Queue Providers

[Queue Providers ](https://docs.redpointglobal.com/rpi/configuring-realtime-queue-providers) are used to provide RPI with message queuing capabilities. 

To configure a Queue Provider, Open the ```values.yaml``` file and locate the ```queueProviders``` section. Here, specify the Queue provider you intend to use. Supported options are: ```amazonsqs```, ```rabbitmq ```, ```googlepubsub```,```azureeventhubs ```, ```azureservicebus```,```azurestoragequeues```

```
queueProviders: 
  type: amazonsqs 
```
### Configuring Realtime Cache Providers

The [Cache connectors ](https://docs.redpointglobal.com/rpi/cache-configuration) allow RPI to store and access various data quickly (in-memory), such as Visitor Profiles, Realtime Decisions rules, and content. This enables immediate action within data dependent websites, without the delays of retrieving information back from the database.

To configure a Cache Provider, Open the ```values.yaml``` file and locate the ```cacheProviders``` section. Here, specify the Cache provider you intend to use. Supported options are: ```mongodb```, ```cassandra ```, ```redis``` ,```googlebigtable```

```
cacheProviders: 
  type: mongodb
```

### RPI Documentation
To explore in-depth documentation and stay updated with the latest release notes for RPI, be sure to visit our documentation site by clicking the link below

 [Redpoint Documentation Site ](https://docs.redpointglobal.com/rpi/)

### Getting Support 
If you encounter any challenges specific to the RPI application, our dedicated support team is here to assist you. Please reach out to us with details of the issue for prompt and expert help.

[support@redpointglobal.com](support@redpointglobal.com)

```Note on Scope of Support```
While we are fully equipped to address issues directly related to the RPI application, please be aware that challenges pertaining to Kubernetes configurations, network connectivity, or other external system issues fall outside our support scope. For these, we recommend consulting with your IT infrastructure team or seeking assistance from relevant technical forums.
