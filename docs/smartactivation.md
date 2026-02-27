![redpoint_logo](../images/logo.png)
## Redpoint Interaction (RPI) | Smart Activation
The [RPI Smart Activation](https://docs.redpointglobal.com/cdp/data-activation-overview-page) feature enables additional RPI Web UI components required for integration with RPI services. 

The Smart Activation overview page displays what’s going on with your activation activities and is your starting point to:

 - Build one or more segments
 - Build one or more audiences
 - Activate an audience (data extract) that can be run immediately or scheduled to run at a later date
 - Access data layouts

 By default, this functionality is disabled and only deployed when the ```smartActivation.enabled``` flag is explicitly set to ```true``` in the Helm Chart ```values.yaml```.

<div style="background-color:#ffe5e5; padding:16px; border-left:6px solid #cc0000;">
  <strong style="color:#cc0000; font-size: 1.1em;">ADVISORY</strong>
  <p>We recommend you <strong>do not</strong> enable Smart Activation at this time. Contact your Redpoint representative for further details.</p>
</div>

### Table of Contents
- [System Requirements ](#system-requirements)
- [Prerequisites ](#considerations-before-you-begin)
- [Begin Deployment ](#begin-deployment)
- [Post Deployment Configuration ](#post-deployment-configuration)
- [RPI Documentation](#rpi-documentation)
- [Getting Support](#getting-support)

### System Requirements

- **Operational Databases**
    - **MongoDB** version 7.x on any of the following plaforms: ```MongoDB on VM```, ```MongoDB Atlas```
    - 8 GB Memory or more on VM
    - M20 (General) on Atlas
    - 100 GB or more free disk space.
    - **SQL Server**. Required for the ```Keycloak``` database. This should be the same SQL Server instance that hosts the RPI operational databases

### Prerequisites

| Ensure that the following requirements are met before enabling Smart Activation!                                                                                                                                                                                                                                   |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| - **Container Registry:** Open a [Support](mailto:support@redpointglobal.com) ticket requesting access to download the RPI Smart Activation images.<br><br> - **Activation License:** Open a [Support](mailto:support@redpointglobal.com) ticket to obtain the RPI Smart Activation License. |

Before enabling Smart Activation, an administrator must ensure that a service account has been created within RPI. This account is used by the Smart Activation components to authenticate and communicate with RPI via the Integration API.

The service account must be a member of the following RPI groups:

- ```Everyone```
- ```IntegrationAPI```
- ```Cluster Administrators```

### Begin Deployment

Once you have the prerequisites completed, enable Smart Activation by configuring your ```values.yaml``` as shown below

```
# Enable Smart Activation functionality
smartActivation:
  enabled: true

# Configure credentials for the Integration API service account
integrationapi:
  username: admin@noemail.com          
  password: <my_Super_Strong_Pwd>

# Configure the default administrator credentials for the Web UI
authservice:
  default_username: admin@noemail.com
  default_password: <my_Super_Strong_Pwd>

# Configure the default administrator credentials for Keycloak
keycloak:
  username: admin@noemail.com
  password: <my_Super_Strong_Pwd>
  database_name: keycloak

# Configure the Smart Activation System Database
initservice:
  database:
    operational:
      name: <my-mongo-database-name>
      connection_string:
```

Set the ```integrationapi.username``` and ```integrationapi.password``` values to match the service account created in the RPI tenant.

When Smart Activation is enabled, the following services are deployed to your existing RPI namespace.
 
- ```cdp-authservices```
- ```cdp-cache```
- ```cdp-initservice```
- ```keycloak```
- ```cdp-maintenanceservice```
- ```cdp-messageq```
- ```cdp-servicesapi```
- ```cdp-socketio```
- ```cdp-ui```
 
After enabling Smart Activation, verify that all pods have been deployed and initialized successfully. Review the pod logs and address any errors that may occur during startup.

The Smart Activation Web UI is automatically exposed through your existing RPI Ingress configuration. To complete the setup, customize the access endpoint by specifying the desired URL in the same Ingress configuration.

Update your ```values.yaml``` file as shown below

```
ingress:
  hosts:
    smartactivation: rpi-webui
```
### Post Deployment Configuration

To complete the deployment, perform the following steps.  

First, retrieve the ingress host endpoint that was configured for the Smart Activation Web UI during the ingress setup. This endpoint will be used as the Web UI URL in the steps below.

- **Activate the License**

Apply a license activation key using the ```/api/v1/license/activate``` endpoint

```
WEBUI_URL=rpi-webui.example.com
ADMIN_USERNAME=<admin-user@example.com>
ADMIN_PASSWORD=<admin-password>
LICENSE_KEY=<my-license-key>
RPI_CLIENT_ID=<my-rpi-client-id>

# Get Authentication Token
AUTH_TOKEN=$(curl -k -X 'POST' \
    "$WEBUI_URL/api/v1/auth/signon-admin" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
      "username": "'"$ADMIN_USERNAME"'",
      "password": "'"$ADMIN_PASSWORD"'"
    }' | jq -r '.accessToken')

# Activate the license
curl -k -X 'POST' \
  "$WEBUI_URL/api/v1/license/activate" \
  -H 'accept: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "activationKey": "'"$LICENSE_KEY"'"
  }'
```

- **Configure the Web Client**

Add a client using the ```/api/v1/clients/{clientId}/config``` endpoint

```
curl -k -X 'PUT' \
"$WEBUI_URL/api/v1/clients/$RPI_CLIENT_ID/config" \
-H 'accept: application/json' \
-H "Authorization: Bearer $AUTH_TOKEN" \
-H 'Content-Type: application/json' \
-d '{
  "dccEnabled": true,
  "name": "my-smart-activation-client>",
  "abbvName": "my-smart-activation-client>",
  "description": "my-smart-activation-client>",
  "siteUrl": "'"$WEBUI_URL"'",
  "keycloakEnabled": false,
  "models": [
    "Core",
    "Retail",
    "IR"
  ],
  "keycloakRealm": "redpoint-mercury",
  "apps": {
      "campaign_creation": {
          "enabled": true
      },
      "machine_learning": {
          "enabled": false,
          "finiteStateMachineEnabled": false
      },
      "in_situ": {
          "enabled": false,
          "dmConfig": []
      }
  }
}'
```

At this point, the Web UI should be accessible, and you can log in using your credentials.

![smart_activation_webui](../images/smart_activation_webui.png)

### RPI Documentation
To explore in-depth documentation and stay updated with the latest release notes for RPI, be sure to visit the [RPI Documentation Site ](https://docs.redpointglobal.com/rpi/)

### Getting Support 
If you encounter any challenges specific to the RPI application, our dedicated support team is here to assist you. Please reach out to us with details of the issue for prompt and expert help using [support@redpointglobal.com](support@redpointglobal.com)

```Note on Scope of Support```
While we are fully equipped to address issues directly related to the RPI application, please be aware that challenges pertaining to Kubernetes configurations, network connectivity, or other external system issues fall outside our support scope. For these, we recommend consulting with your IT infrastructure team or seeking assistance from relevant technical forums.