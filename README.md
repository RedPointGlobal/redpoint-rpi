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
- [RPI Services Access URLs ](#rpi-services-access-urls)
- [RPI Storage ](#rpi-storage)
- [RPI Realtime Cache and Queue Providers](#rpi-realtime-cache-and-queue-providers)
- [RPI High Availability ](#rpi-high-availability)
- [RPI License Activation ](#license-activation)
- [RPI Documentation](#rpi-documentation)
- [Support](#support)

### System Requirements
- **SQL Server**
    - Any of the of the following types
       - Microsoft Azure SQL Database
       - Amazon RDS for SQL Server
       - Google Cloud SQL for SQL Server 
       - Microsoft SQL Server (self-hosted)
    - Version: 2019 or later
    - 8 GB Memory or more
    - 256 GB or more free disk space.

- **Kubernetes Cluster:**
Ensure you use the latest stable version of Kubernetes, which can be either self-hosted or managed. Managed options include Azure Kubernetes Service (AKS), Amazon Elastic Kubernetes Service (EKS), and Google Kubernetes Engine (GKE). If you don't already have a Kubernetes cluster, refer to the ```./kubernetes/``` directory. This directory contains official quickstart guides for the managed options.

- **Kubernetes Nodepools**
    - Node Sizing for RPI Workloads
       - 8 vCPUs per node
       - 16 GB of Memory per node
       - Minimum of 2 nodes for high availability

### Before you begin
Ensure that the following requirements are met:

- **Redpoint Container Registry access:** Open a support ticket at support@redpointglobal.com requesting access to download RPI container images.

- **RPI License:** Open a support ticket at support@redpointglobal.com to obtain your RPI v7 License activation key. 

- Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), a command-line tool for interacting with your Kubernetes cluster.

- Install [Helm](https://helm.sh/docs/helm/helm_install/) and ensure you have the required permissions from your Kubernetes Administrator to deploy applications in the target cluste

### Greenfield Installation
In a Greenfield installation, you're setting up RPI in a completely new environment. This includes: A new cluster, A new tenant, New operations and logging databases, New cache and queue providers. This approach ensures that all components are installed fresh and independent of any existing systems. 

Follow the following steps to get started

**1. Set your target Cloud Provider:**

Open the ```values.yaml``` file and locate the ```cloud``` section. Here, specify the cloud provider where you intend to deploy RPI. Supported options are: ```azure```, ```amazon```, ```google``` and ```selfhosted```
```
  cloud: amazon
```
**2 Configure SQL Server Settings:**

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
**4. Create the Container Registry Secret:**

Run the following command to create a Kubernetes secret for ```imagePull```. This secret will store the credentials required to pull RPI Docker images from the Redpoint container registry. Obtain these credentials from Redpoint Support and replace ```<your_username>``` and ```<your_password>``` with your actual credentials:
```
DOCKER_USERNAME=<your_username> 
DOCKER_PASSWORD=<your_password>
DOCKER_SERVER=rg1acrpub.azurecr.io
NAMESPACE=redpoint-rpi

kubectl create secret docker-registry redpoint-rpi \
--namespace $NAMESPACE \
--docker-server=$DOCKER_SERVER \
--docker-username=$DOCKER_USERNAME \
--docker-password=$DOCKER_PASSWORD
```
**5. Create the TLS Certificate Secrets:**

The Helm chart deploys an ingress resource and an NGINX ingress controller to expose the URL endpoints required for accessing RPI services. These endpoints are secured using HTTPS. The only requirement on your part is to provide a TLS certificate for TLS termination.

To add the certificate, run the following command to create a Kubernetes secret. Replace ```path/to/your_cert.crt``` and ```path/to/your_cert.key``` with the actual paths to your certificate files:
```
CERT_FILE=path/to/your_cert.crt
KEY_FILE=path/to/your_cert.key
NAMESPACE=redpoint-rpi

kubectl create secret tls ingress-tls \
--namespace $NAMESPACE \
--cert=$CERT_FILE \
--key=$KEY_FILE
```
If you prefer to use a custom ingress controller rather than the NGINX ingress controller provided by the chart, you can disable the built-in controller by modifying the ```values.yaml``` file. Set the ```ingress.controller.enabled``` setting to false as shown below:
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

### RPI Services Access URLs

To interact with RPI services, such as client login or using the integration API, you need to obtain the URL endpoints exposed by the ingress. Use the following command to list the ingresses in the redpoint-rpi namespace
```
kubectl get ingress --namespace redpoint-rpi
```
Initially, you might not see an IP address for your endpoints. This is normal and occurs because provisioning the ingress load balancer takes some time. If no IP address is displayed, wait a few minutes and then re-run the command. Once the load balancer is ready, you should see output similar to the following, where ```<Load Balancer IP>``` will be replaced with the actual IP address:
```
NAME           HOSTS                                   ADDRESS              PORTS     AGE
redpoint-rpi   rpi-configeditor.example.com           <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-client.example.com                 <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-integrationapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-realtime.example.com               <Load Balancer IP>   80, 443   32d
```

Add DNS records for the above hosts in your DNS zone. This ensures that the domain names you use for example ```rpi-client.example.com``` correctly route to your RPI instance.

With the DNS configuration in place, RPI Services can be accessed at the follwing addresses:
```
rpi-configeditor.example.com                              # Configuration editor
rpi-client.example.com                                    # RPI Client hostname
rpi-configeditor.example/api/deployment/downloads/Client  # RPI Client Executable Download
rpi-integrationapi.example.com                            # Integration API
rpi-realtime.example.com                                  # RPI Realtime
```
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
Use the contents of this file as a reference to customize the ```values.yaml``` file for the Helm Chart before deploying the new v7 cluster. For instance, you will need to update the SMTP and database connection strings in the values.yaml based on the information provided in the example.

To perform the upgrade, follow the same steps outlined in the [Greenfield Installation](#greenfield-installation) section. The key differences are

  - **SQL Server Configuration:** Ensure your SQL server configuration points to your existing databases, caches, and queues from your current RPI version 6 environment.

  - **Helm Chart Customization:** Modify the Helm Chart to incorporate the details provided in the Upgrade Assistant output. Update the ```values.yaml``` file with the relevant environment variables and configuration settings from the output to ensure compatibility with v7.

### Demo Installation
In a Demo installation, RPI is set up using the default configurations provided by the Helm Chart. This includes:

  - Containerized SQL Server for the Operations databases
  - MongoDB as the Cache Provider
  - RabbitMQ as the Queue Provider

These components are pre-configured and deployed automatically, allowing you to quickly get started with a fully functional setup.

To perform a demo installation, open the values.yaml file and set the cloud value to demo:
```
cloud: demo
```

### License Activation

After installing RPI, you need to apply a license. You have two options for applying the license:

 - **During Cluster Installation:** In a [Greenfield Installation](#greenfield-installation) where you need to call the ```/api/deployment/installCluster``` endpoint to install the operational databases as shown in the example below

 ```
ACTIVATION_KEY="your_license_activation_key"
ACTIVATION_URL=rpi-configeditor.example.com
SYSTEM_NAME="my_dev_rpi_system"

 curl -X 'POST' \
  'https://$ACTIVATION_URL/api/deployment/installcluster?waitTimeoutSeconds=360' \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d '{
  "UseExistingDatabases": false,
  "CoreUserInitialPassword": ".Admin123",
  "SystemAdministrator": {
    "Username": "coreuser",
    "EmailAddress": "coreuser@noemail.com"
  },
  "LicenseInfo": {
    "ActivationKey": "'"${ACTIVATION_KEY}"'",
    "SystemName": "'"${SYSTEM_NAME}"'"
  }
}'
 ```
 - **Directly via the License API:** In an [Upgrade Installation](#greenfield-installation) where you need to call the ```/api/licensing/activatelicense``` endpoint to activate your existing RPI cluster as shown in the example below

```
ACTIVATION_KEY="your_license_activation_key"
ACTIVATION_URL=rpi-configeditor.example.com
SYSTEM_NAME="my_dev_rpi_system"

curl -X 'POST' \
  'https://$ACTIVATION_URL/api/licensing/activatelicense' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "ActivationKey": "'"${ACTIVATION_KEY}"'",
  "SystemName": "'"${SYSTEM_NAME}"'"
}'
```

With RPI installed and license activated, you are ready to use the application. 

### High Availability

The default installation of RPI services is configured with a single replica for each service. However, for a production environment, it's crucial to ensure high availability to maintain service continuity and manage load efficiently.

To achieve high availability, adjust the number of replicas for each service to 2 or more. Additionally, the cluster admin can create a [Horizontal Pod Autoscaler (HPA)](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) to automatically manage the number of pod replicas based on observed CPU utilization or other select metrics. Here’s how you can set the replica count in the ```values.yaml``` file:
```
replicas:
  interactionapi: 2
  integrationapi: 2
  configeditor: 2
  callbackapi: 2
  nodemanager: 2
  executionservice: 2
  realtimeapi: 2
```
### RPI Storage

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
### RPI Realtime Cache and Queue Providers

RPI Realtime consists of the Realtime webservice and Realtime Agent. The ```Realtime webservice``` facilitates the making of content applicability decisions, and the recording of events undertaken by e.g. a site visitor - whiel the ```Realtime Agent``` provides access for the RPI Realtime service to the RPI operational and data databases.

The Queue connectors allow RPI access to inbound collection of data from sources like a web form submission. RPI can then act on this information in several ways, such as sending a follow up email after a purchase, executing Realtime decisions to display personalized landing page content, etc. 

To configure a Queue Provider, Open the ```values.yaml``` file and locate the ```queueProviders``` section. Here, specify the Queue provider you intend to use. Supported options are: ```amazonsqs```, ```rabbitmq ```, ```googlepubsub```,```azureeventhubs ```, ```azureservicebus```,```azurestoragequeues```

```
queueProviders: 
  type: amazonsqs 
```

In order for RPI realtime decisions to be used, a caching mechanism must be made available, and configuration performed to ensure that the RPI Realtime application can make use of the same. 

To configure a Cache Provider, Open the ```values.yaml``` file and locate the ```cacheProviders``` section. Here, specify the Cache provider you intend to use. Supported options are: ```mongodb```, ```cassandra ```, ```redis``` ,```googlebigtable```

```
cacheProviders: 
  type: mongodb
```

### RPI Documentation
To explore in-depth documentation and stay updated with the latest release notes for RPI, be sure to visit our documentation site by clicking the link below

 [Redpoint Documentation Site ](https://docs.redpointglobal.com/rpi/)

### Support 
If you encounter any challenges specific to the RPI application, our dedicated support team is here to assist you. Please reach out to us with details of the issue for prompt and expert help.

[support@redpointglobal.com](support@redpointglobal.com)

```Note on Scope of Support```
While we are fully equipped to address issues directly related to the RPI application, please be aware that challenges pertaining to Kubernetes configurations, network connectivity, or other external system issues fall outside our support scope. For these, we recommend consulting with your IT infrastructure team or seeking assistance from relevant technical forums.
