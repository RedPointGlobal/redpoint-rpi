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
Before you install RPI, you must:

1. Have a Kubernetes solution available to use. ( https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/ )
2. Install kubectl. ( https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/ )
3. Have a SQL Server server available to use for RPI databases
4. Request access to Redpoint's container registry. Open a ticket with support@redpointglobal.com requesting access to the RPI repository. 
5. Have a license key to activate RPI. Contact Redpoint support for an activation key

| **NOTE:** Before you Begin!           |
|---------------------------------------|
|  This guide assumes Microsoft Azure is the underlying platform for your Kubernetes infrastructure. However RPI can also be deployed on clusters within the Amazon and Google Cloud platforms. Before installing RPI, set the target Cloud platform in the ```values.yaml``` file as shown in step 3 below.|

### Install Procedure
The default installation creates a SQL server for the RPI operations databases. This is fine for a ```DEMO``` environment. However, for production workloads, you must make changes as described in the [Customize for Production ](#customize-for-production) section 

1) Clone this repository and connect to your target Kubernetes Cluster
```
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
```
2) Make sure you are inside the ```redpoint-rpi``` directory 
```
cd redpoint-rpi
```
3) Set your target cloud platform by updating the section below in the ```values.yaml``` file.
```
global:
  cloudProvider: azure # or google or amazon   
```
4)  Create a kubernetes secret that contains Redpoint container registry credentials. This credential will provided to you by Redpoint Support.
```
kubectl create secret docker-registry docker-io --namespace redpoint-rpi --docker-server=rg1acrpub.azurecr.io \
--docker-username=<your_username> --docker-password=<your_password>
```
5) Run the following command to install RPI
```
kubectl config set-context --current --namespace=redpoint-rpi \
&& helm install redpoint-rpi redpoint-rpi/ --values values.yaml --create-namespace
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

1. RPI has been successfully installed in your cluster.
  - It may take a few minutes for the all the RPI services to start. Please wait about 10 minutes.
```
### RPI Endpoints
The default installation includes an Nginx ingress controller that exposes the relevant RPI endpoints based on the domain specified in the ingress section within the ```values.yaml```domain. 
```
ingress:
  domain: example.com
```
Run the command below to retrieve all the endpoints. This command will keep checking the ingress IP address every 10 seconds until it finds one. Once an IP address is found, it will display the IP and the corresponding ingress hostname.
```
NAMESPACE="redpoint-rpi"; INGRESS_IP=""; while true; do INGRESS_IP=$(kubectl get ingress --namespace $NAMESPACE -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}"); if [ -n "$INGRESS_IP" ]; then echo "IP address found: $INGRESS_IP"; kubectl get ingress --namespace $NAMESPACE; break; else echo "No IP address found, waiting for 10 seconds before checking again..."; sleep 10; fi; done
```
```NOTE``` The load balancer creation takes a few minutes so you may not see an IP address immediately. Just keep trying the command a few more times and you will eventually you see a single IP address assigned to the endpoints below;

```
rpi-config.example.com                             # Configuration editor
rpi-client.example.com                             # RPI Client 
rpi-config.example/api/deployment/downloads/Client # RPI Client download link
rpi-integapi.example.com                           # Integration API
rpi-realtime.example.com                           # RPI Realtime
sql-rpi-ops.example.com                                # Default SQL server name
```
Next you need to create DNS records in your DNS zone or you can create temporary entries in your Windows hosts file located at ```C:\Windows\System32\drivers\etc\hosts```

### License Activation
Before using RPI, you need to activate a License. The steps below describe the process

1) Contact Redpoint Support and obtain the following files
   - QLM Settings file
   - QLM Activated License file

2) Access the configuration editor web UI at https://rpi-config.example.com
![image](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/ab0f7b97-be6e-457e-8568-5c5a70b0fcc7)
4) Select the ``Licensing Upload``` endpoint
5) Upload both the QLM Settings file and QLM Activation License file 

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
NOTE: Only the ```Integration API``` service does not support HA as of this release so you should only run a single replica. This should be resolved in a future release 

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
