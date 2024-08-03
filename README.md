![rp_cdp_logo](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/432d779f-de4e-4936-80fe-3caa4d732603)
## Redpoint Interaction (RPI) | Deployment on Kubernetes
With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

In this guide, we take a Step-by-Step deployment of Redpoint Interaction (RPI) on Kubernetes using HELM.
![image](https://user-images.githubusercontent.com/42842390/229413149-ff9497cd-8ed4-4512-96e1-c71932680350.png)
### Table of Contents
- [System Requirements ](#system-requirements)
- [Prerequisites ](#prerequisites)
- [Install Procedure ](#install-procedure)
- [RPI Endpoints ](#rpi-endpoints)
- [RPI Storage ](#rpi-storage)
- [RPI Realtime ](#rpi-realtime)
  - [Queue Providers ](#queue-providers)
  - [Cache Providers ](#queue-providers)
- [RPI High Availability ](#rpi-high-availability)
- [License Activation ](#license-activation)
- [RPI v6 Upgrade Assistant](#rpi-v6-upgrade-assistant)
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

- **Redpoint Container Registry access:** 
  - Prior to installing RPI, open a support ticket at support@redpointglobal.com requesting access to the RPI repository.

- **RPI License:** 
  - Prior to installing RPI, open a support ticket at support@redpointglobal.com to obtain your License activation key. 

- **Commandline Tools:** 
  - Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), a command-line tool for interacting with your Kubernetes cluster.
  - Install [Helm](https://helm.sh/docs/helm/helm_install/), a package manager for Kubernetes.
  - Ensure you obtain the necessary permissions to install applications in your Kubernetes cluster.

### Install Procedure
Follow the following steps to install RPI:

- **1) Set your target Cloud Provider:**

Open the ```values.yaml``` file and locate the ```cloud``` section. Here, specify the cloud provider where you intend to deploy RPI. Supported options are: ```azure```, ```amazon```, ```google``` and ```demo```
```
  cloud: amazon
```
- **2) Configure SQL Server Settings:**

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
- **3) Create Kubernetes Namespace:**

Run the following command to create the Kubernetes namespace for deploying RPI services and set it as the default context for future CLI commands
```
kubectl create namespace redpoint-rpi && \
kubectl config set-context --current --namespace=redpoint-rpi
```
- **4) Create the Container Registry Secret:**

Run the following command to create a Kubernetes Secret containing the credentials needed to pull images from the Redpoint container registry. Obtain these credentials from Redpoint Support and replace ```<your_username>``` and ```<your_password>``` with your actual credentials:
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
- **5) Create the TLS Certificate Secrets:**

A certificate (.crt) and certificate key (.key) file are needed for Ingress TLS. The certificate file ```(.crt)``` contains the public key , while the certificate key file ```(.key)``` contains the private key. Run the following command to create the Kubernetes secret, replacing ```path/to/your_cert.crt``` and ```path/to/your_cert.key``` with the actual paths to your certificate files:
```
CERT_FILE=path/to/your_cert.crt
KEY_FILE=path/to/your_cert.key
NAMESPACE=redpoint-rpi

kubectl create secret tls ingress-tls \
--namespace $NAMESPACE \
--cert=$CERT_FILE \
--key=$KEY_FILE

```
**6) Install RPI:**

After completing the above steps, you are now ready to proceed with the installation as follows:

- Clone the RPI repository to your local machine:
```
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
```
- Change into the cloned repository's directory:
```
cd redpoint-rpi
```
- Run the following Helm command to install RPI on your Kubernetes cluster, using the configurations set in your values.yaml file:
```
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
It may take some time for all the RPI services to fully initialize. We recommend waiting approximately 5-10 minutes to ensure that the services are completely up and running. This patience is crucial for the successful retrieval of ingress endpoints in the subsequent step.

### RPI Endpoints

To view the RPI endpoints, use the following kubectl command. This command lists all the ingress resources in the redpoint-rpi namespace, showing you the configured endpoints.
```
kubectl get ingress --namespace redpoint-rpi
```
Initially, you might not see an IP address for your endpoints. This delay is normal and occurs because it takes some time for the ingress load balancer to be provisioned. If no IP address is displayed, wait a few minutes and then re-run the command. Once the load balancer is ready, you should see output similar to the following, where ```<Load Balancer IP>``` will be replaced with the actual IP address:
```
NAME           HOSTS                                   ADDRESS              PORTS     AGE
redpoint-rpi   redpointrpi-config.example.com          <Load Balancer IP>   80, 443   32d
redpoint-rpi   redpointrpi.example.com                 <Load Balancer IP>   80, 443   32d
redpoint-rpi   redpointrpi-integrationapi.example.com  <Load Balancer IP>   80, 443   32d
redpoint-rpi   redpointrpi-realtime.example.com        <Load Balancer IP>   80, 443   32d
```
After completing the default installation, the next crucial step involves setting up your DNS:

Add a DNS record in your DNS zone. This record should point to the IP address of the load balancer provided by your Kubernetes ingress. This setup ensures that the domain names you use (like redpointrpi.example.com) correctly route to your RPI instance.

With the DNS configuration in place, you're ready to access the RPI interfaces:
```
rpi-configeditor.example.com                              # Configuration editor
rpi-client.example.com                                    # RPI Client 
rpi-configeditor.example/api/deployment/downloads/Client  # RPI Client Executable Download
rpi-integrationapi.example.com                            # Integration API
rpi-realtime.example.com                                  # RPI Realtime
```
### License Activation

After installing RPI, you need to apply a license. This license is obtained from Redpoint Support. Follow the steps below to access the Configuration Editor and enter your license key:

- Navigate to the RPI Configuration Editor using your web browser. This interface is where you will enter the provided activation key.

![image](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/9947e054-b527-434c-8c44-ac551b560a3f)

![image](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/cc407181-162a-4860-b191-4f7c6746720e)

At this point, the default installation is complete and you are ready to add your first RPI tenant. 

### High Availability

The default installation of RPI services is configured with a single replica for each service. However, for a production environment, it's crucial to ensure high availability to maintain service continuity and manage load efficiently.

To achieve high availability, adjust the number of replicas for each service to 2 or more. Additionally, the cluster admin could also create a [Horizontal Pod Autoscaler (HPA)](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) to automatically manage the number of pod replicas based on observed CPU utilization or other select metrics. Here’s how you can set the replica count in the ```values.yaml``` file:
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
  # Define storage configuration
  storage:
    # Set whether storage is enabled or not (false means disabled)
    enabled: false
    # Specify the persistent volume claim for the directory
    persistentVolumeClaim: rpifileoutputdir

```
### RPI Realtime

RPI Realtime consists of the Realtime webservice and Realtime Agent. The ```Realtime webservice``` facilitates the making of content applicability decisions, and the recording of events undertaken by e.g. a site visitor. The ```Realtime Agent``` provides access for the RPI Realtime service to the RPI operational and data databases.

 - ### Queue Providers

The Queue connectors allow RPI access to inbound collection of data from sources like a web form submission. RPI can then act on this information in several ways, such as sending a follow up email after a purchase, executing Realtime decisions to display personalized landing page content, etc. Open the ```values.yaml``` file and locate the ```queueProviders``` section. Here, specify the Queue provider you intend to use. Supported options are: ```amazonsqs```, ```rabbitmq ```, ```azureservicebus```, ```googlepubsub```,```azureeventhubs ```, ```azureservicebus```,```azurestoragequeues```

```
queueProviders: 
  type: amazonsqs 
```

 - ### Cache Providers
In order for RPI realtime decisions to be used, a caching mechanism must be made available, and configuration performed to ensure that the RPI Realtime application can make use of the same. Open the ```values.yaml``` file and locate the ```cacheProviders``` section. Here, specify the Cache provider you intend to use. Supported options are: ```mongodb```, ```cassandra ```, ```redis``` ,```googlebigtable```

```
cacheProviders: 
  type: mongodb
```

### RPI v6 Upgrade Assistant
If you are upgrading from a lower version of RPI, use the [Interaction Upgrade Helper](https://github.com/RedPointGlobal/redpoint-rpi/blob/main/UpgradeAssistant.zip) prior to upgrade to check availability of plugins in the v7 version. Download and extract the zip from the link above and execute the ```RedPoint.Interaction.UpgradeHelper```application. When executed, the Helper requests that a v6 Pulse database connection string be entered.  Assuming that it is able to connect, it checks for v7 compatibility of all plugins currently in use.  If one or more incompatible plugins is found, their details are displayed, and the option to output the same to a file is provided.

The resultant file contains details of the plugins in question, along with a series of v7 environment variables, which can serve as a starting point for customizing the Helm Chart ```values.yaml``` prior to deploying the new v7 cluster.  An example is provided below:
```
{
  "General": {
    "ConnectionStrings__OperationalDatabase": "Server=localhost,2433;Database=Pulse;UID=[x];PWD=[x];ConnectRetryCount=12;ConnectRetryInterval=10;Encrypt=false",
    "ConnectionStrings__LoggingDatabase": "[not set]",
    "RPI__ServiceHostName": "local.rphelios.net",
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
### RPI Documentation
To explore in-depth documentation and stay updated with the latest release notes for RPI, be sure to visit our documentation site by clicking the link below

 [Redpoint Documentation Site ](https://docs.redpointglobal.com/rpi/)

### Support 
If you encounter any challenges specific to the RPI application, our dedicated support team is here to assist you. Please reach out to us with details of the issue for prompt and expert help.

[support@redpointglobal.com](support@redpointglobal.com)

```Note on Scope of Support```
While we are fully equipped to address issues directly related to the RPI application, please be aware that challenges pertaining to Kubernetes configurations, network connectivity, or other external system issues fall outside our support scope. For these, we recommend consulting with your IT infrastructure team or seeking assistance from relevant technical forums.
