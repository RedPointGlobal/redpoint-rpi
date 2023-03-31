## Redpoint Interaction (RPI) - Deployment on Kubernetes
With RedPoint Interaction™ you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

In this guide, we take a Step-by-Step deployment of Redpoint Interaction (RPI) on Kubernetes using HELM.

### Table of Contents
- [Prerequisites ](#prerequisites)
- [System Requirements ](#system-requirements)
- [Install Procedure ](#install-procedure)
- [Ingress ](#ingress)
- [RPI URL Endpoints ](#rpi-url-endpoints)
- [RPI License](#install-license)
- [RPI Documentation](#rpi-documentation)
- [Support](#support)

### System Requirements

- SQL Server for RPI Operational Databases
    - Version: 2019 or later
    - 8 GB Memory or more
    - 100 GB or more free disk space.
    - SSD disks for best IO perfomance
    - The SQL Server database can be any of the following
       - AzureSQL Database
       - Amazon RDS for SQL Server
       - Cloud SQL for SQL Server 
       - Microsoft SQL Server on Linux or Windpws

- Kubernetes Cluster
    - Latest stable version of Kubernetes
    - Nodepool with 2-3 nodes for high availabilty
    - 8 vCPUs and 16 GB memory per node
    - 100 GB or more free disk space per node
    - The Kubernetes cluster can be any of the following
       - Self hosted Kubernetes
       - Managed Kubernetes (AKS, EKS, GKE)
    
### Prerequisites

Before you install RPI, you must:

1. Have a Kubernetes solution available to use. ( https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/ )
2. Install kubectl. ( https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/ )
3. Have a SQL Server server available to use for RPI databases
4. Docker ID, create one at https://hub.docker.com/ and provide the account ID to Redpoint Support so they can grant you permissions to pull the RPI container images
5. Have a license key to activate RPI. Contact Redpoint support for an activation key

### Install Procedure