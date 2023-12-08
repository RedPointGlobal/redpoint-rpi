![RG](https://user-images.githubusercontent.com/42842390/158004336-60f07c05-7e5d-420e-87a6-22c5ac206fb6.jpg)
## Redpoint Interaction (RPI) | Deployment on Kubernetes
With RedPoint Interaction™ you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

In this guide, we take a Step-by-Step deployment of Redpoint Interaction (RPI) on Kubernetes using HELM.
![image](https://user-images.githubusercontent.com/42842390/229413149-ff9497cd-8ed4-4512-96e1-c71932680350.png)
### Table of Contents
- [System Requirements ](#system-requirements)
- [Prerequisites ](#prerequisites)
- [Install Procedure ](#install-procedure)
- [RPI Endpoints ](#rpi-url-endpoints)
- [License Activation ](#license-activation)
- [Customize for Production ](#customize-for-production)
    - [SQL Server ](#sql-server)
    - [Ingress ](#ingress)
    - [High Availability ](#high-availability)
    - [RPI Storage ](#rpi-storage)
- [Customize for Cloud Provider ](#customize-for-cloud-provider)
    - [Google Cloud (GCP) ](#goole-cloud)
    - [Amazon Cloud (AWS) ](#amazon-cloud)
- [Useful Scripts ](#useful-scripts)
- [RPI Documentation](#rpi-documentation)
- [Support](#support)

### System Requirements

- SQL Server for RPI Operational Databases
    - Version: 2019 or later
    - 8 GB Memory or more
    - 100 GB or more free disk space.
    - Any of the of the following Database types
       - AzureSQL Database
       - Amazon RDS for SQL Server
       - Google Cloud SQL for SQL Server 
       - Microsoft SQL Server on virtual machine or bare metal

- Kubernetes Cluster
    - Latest stable version of Kubernetes
    - Self-hosted or any of the cloud provider offerings (AKS, EKS, GKE)
    - Nodepool with 2 or more nodes for high availabilty
    - 4 vCPUs and 8 GB memory per node
    - 100 GB or more free disk space per node
    
### Prerequisites
Before installing RPI, ensure that the following requirements are met:

1. Access to a Kubernetes cluster is essential. If you don't have one, consider setting up a Kubernetes solution following the guidelines provided by Kubernetes for [Production](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/)
2. Install kubectl, a command-line tool for interacting with your Kubernetes cluster. Detailed installation instructions can be found [Here](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
3.  Ensure the availability of a SQL Server for hosting RPI databases. This server will be integral for the data storage and management needs of RPI.
4. To access RPI's container images, request access to Redpoint's container registry. Open a support ticket at support@redpointglobal.com requesting access to the RPI repository.
5. An activation key is required to use RPI. Contact Redpoint support to obtain your license key

| **NOTE:** Before you Begin!           |
|---------------------------------------|
| This guide is primarily tailored for deployments on Microsoft Azure. However, RPI is also compatible with Amazon Web Services (AWS) and Google Cloud Platform (GCP). Ensure you select the appropriate cloud provider in the values.yaml file before proceeding with the installation. This setting can be found in the global section of values.yaml.|

### Install Procedure
Before installing RPI, follow these preparatory steps to ensure a smooth setup:

- Configure SQL Server Settings:

Ensure you have correctly configured the SQL Server details in the ConfigEditor.ConnectionSettings section of the values.yaml file. This includes setting the correct server address, username, password, database names, and other relevant SQL settings.
```
  configeditor:
    ConnectionSettings:
```

- Select Cloud Provider:

In the values.yaml file, under the global application settings, specify the cloud provider where your infrastructure is hosted. Supported providers include Azure, AWS, and GCP. This setting ensures that RPI aligns with your cloud infrastructure.
```
  cloudProvider: azure
  deploymentType: client
```

- Create Kubernetes Namespace:

Run the following command to create a Kubernetes namespace where the RPI services will be deployed:
```
kubectl create namespace redpoint-rpi
```

- Create Docker Registry Secret:

Create a Kubernetes secret containing the image pull credentials for the Redpoint container registry. These credentials are provided by Redpoint Support. Replace <your_username> and <your_password> with your actual credentials:
```
kubectl create secret docker-registry docker-io \
--namespace redpoint-rpi \
--docker-server=rg1acrpub.azurecr.io \
--docker-username=<your_username> \
--docker-password=<your_password>
```
- Create TLS Certificate Secret:

If you are using SSL for RPI access endpoints, create a Kubernetes secret containing your TLS certificate's private and public keys. Replace path/to/tls.cert and path/to/tls.key with the actual paths to your certificate files:
```
kubectl create secret tls tls-secret \
--namespace redpoint-rpi \
--cert=path/to/tls.cert \
--key=path/to/tls.key

```
After completing the above steps, proceed with the installation:

- Clone the RPI repository to your local machine:
```
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
```
- Change into the cloned repository's directory:
```
cd redpoint-rpi
```
- Execute the following Helm command to install RPI on your Kubernetes cluster, using the configurations set in your values.yaml file:
```
helm install redpoint-rpi redpoint-rpi/ --values values.yaml

```
If everything goes well, You should see the output below.
```
NAME: redpoint-rpi
LAST DEPLOYED: Sat Apr  1 02:31:46 2023
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
Initially, you might not see an IP address for your endpoints. This delay is normal and occurs because it takes some time for the ingress load balancer to be provisioned. If no IP address is displayed, wait a few minutes and then re-run the command. Once the load balancer is ready, you should see output similar to the following, where <Load Balancer IP> will be replaced with the actual IP address:
```
redpoint-rpi   redpointrpi-config.example.com          <Load Balancer IP>   80, 443   32d
redpoint-rpi   redpointrpi.example.com                 <Load Balancer IP>   80, 443   32d
redpoint-rpi   redpointrpi-integrationapi.example.com  <Load Balancer IP>   80, 443   32d
redpoint-rpi   redpointrpi-realtime.example.com        <Load Balancer IP>   80, 443   32d
```
After completing the default installation, the next crucial step involves setting up your DNS:

Add a DNS record in your DNS zone. This record should point to the IP address of the load balancer provided by your Kubernetes ingress. This setup ensures that the domain names you use (like redpointmercury.example.com) correctly route to your RPI instance.

With the DNS configuration in place, you're ready to access the Mercury interfaces:
```
redpointrpi-config.example.com                             # Configuration editor
redpointrpi.example.com                                    # RPI Client 
redpointrpi.example/api/deployment/downloads/Client        # RPI Client Executable Download
redpointrpi-integrationapi.example.com                     # Integration API
redpointrpi-realtime.example.com                           # RPI Realtime
```
### License Activation
After receiving your activation key from Redpoint Support, you can activate your RPI instance. Follow these steps to access the Configuration Editor and enter your license key:

- Navigate to the RPI Configuration Editor using your web browser. This interface is where you will enter the provided activation key.

At this point, the default installation is complete and you are ready to add your first RPI tenant. 

### Customize for Production
  ### SQL Server
In a Production setting, you will need to use a production-grade database server.
- Disable the default SQL server creation in the ```values.yaml``` file
```
mssql:
  enabled: true # Change this to false
```
- Replace the following section to reflect your production database server.
```
  configeditor:
    ConnectionSettings:
      Server: <your server IP or FQDN>
      Username: <Your sql admin user>
      Password: <Your sql admin user password>
      DatabaseType: <Either of SQLServer, AzureSQLDatabase, AmazonRDSQL, GoogleCloudSQL or PostgreSQL>
      ConnectionStrings_LoggingDatabase: <Your base64 encoded SQL server connection string for Pulse_Logging>
      ConnectionStrings_OperationalDatabase: <Your base64 encoded SQL server connection string for Pulse>

Example connection string
ConnectionStrings_LoggingDatabase: Server=tcp:<server IP>,1433;Database=Pulse_Logging;User ID=<username>;Password=<password>;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;
ConnectionStrings_OperationalDatabase: Server=tcp:<server IP>,1433;Database=Pulse_Logging;User ID=<username>;Password=<password>;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;
```
  ### Ingress
In a Production setting, you will need to use a proper domain that is not ```example.com```. You must create a Kubernetes secret that contains your organization's TLS certificate and private key. This secret is used by the nginx ingress controller to terminate TLS. 

The secret must be named ```ingress-tls``` and can be created using the following command

```
kubectl create secret tls ingress-tls --cert=<your_cert_file> --key=<your_key_file> --namespace redpoint-rpi
```
Next, replace the ```example.com``` domain with your certificate domain.
```
  hosts:
    config: rpi-config.example.com     
    client: rpi-client.example.com
    integration: rpi-integapi.example.com
    helpdocs: rpi-docs.example.com
```
  ### High Availability
The default installation includes a single replica of each RPI service. In a production setting, you need high-availability. To do this, set the number of replicas to 2 or more as shown below. You need at least 2 or more worker nodes for the Pods to run on separate nodes.
```
global:
  replicaCount: 3
``` 
NOTE: Only the ```Integration API``` service does not support HA as of this release so you should only run a single replica to avoid any weird errors and behaviour. This should be resolved in a future release 

  ### RPI Storage
The default installation creates only 10 GiB of persistent storage for the RPI Output directory. In a production setting, you need atleast 100 GiB or more. To change this setting, replace the section below in the ```values.yaml``` file
```
appsettings:
  volumes: 
    rpi_output_directory: 10Gi # Change this to 100Gi or more
```
### Customize for Cloud Provider
RPI needs an output directroy for storing files. This can be be a fully-managed NFS file service. Follow your target cloud provider documentation to create one and then update the applicable sections in the ```value.yaml``` file as shown below 
```
global:
  cloudProvider: azure # or google or amazon

appsettings:
  storage:
    class:
      google: filestore.csi.storage.gke.io
      amazon:
        provisioner: smb.csi.k8s.io
        volumeHandle: example        # make sure it's a unique id
        Source: example              # Fsx FQDN
        nodeStageSecretRef: smbcreds # Fsx connection secret
```
### RPI Documentation
For detailed RPI documentation and release notes, please visit the official RPI documentation website at the address below

https://support.redpointglobal.com

### Support
For additional support and guidance, email support@redpointglobal.com with as much detail as possible regarding the issue you are facing.
