# Single Sign-On (SSO)

RPI supports single sign-on through two authentication methods:

- **Microsoft Entra ID** (formerly Azure AD) — native integration for organizations using Microsoft identity
- **OpenID Connect (OIDC)** — standards-based SSO supporting Keycloak, Okta, and other OIDC providers

You can enable one or both methods depending on your identity requirements.

---

## Microsoft Entra ID

### Prerequisites

Before enabling Entra ID in the Helm chart, you need to register two applications in Microsoft Entra ID. You can do this via the **Azure CLI** (recommended) or manually through the **Azure Portal**.

### Option A: Azure CLI (Recommended)

Use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Entra ID Setup** to generate and download a setup script. The script creates both app registrations using the Azure CLI and outputs the exact Helm values at the end.

### Option B: Azure Portal

#### 1. Register the Interaction Client

1. In the Azure Portal, navigate to **Microsoft Entra ID** > **App registrations**
2. Click **New registration**
3. Name the app `interaction-client` and note the **Client ID** and **Tenant ID**
4. Go to the **Authentication** section
5. Under **Redirect URIs**, add a new entry of type **Mobile & Desktop** with the value:
   ```
   ms-appx-web://Microsoft.AAD.BrokerPlugin/{Client ID}
   ```
   Replace `{Client ID}` with the Application ID from the `interaction-client` app registration.

#### 2. Register the Interaction API

1. Create another **New registration**
2. Name the app `interaction-api` and note the **Client ID** and **Tenant ID**
3. Select **Add Application ID URI**, then create a custom scope named `Interaction.Clients`:
   - **Name/Description:** Access RPI
   - **Who can consent:** Admins and users
4. Under **Authorized client applications**, add the Interaction Client's **Client ID**

### Enable in the Helm Chart

Update your `values.yaml` with the IDs from either method above:

```yaml
MicrosoftEntraID:
  enabled: true
  interaction_client_id: <interaction-client Client ID>
  interaction_api_id: <interaction-api Client ID>
  tenant_id: <Azure Tenant ID>
```

> **Note:** To sign in with Microsoft Entra ID, each RPI user account must use the same email address as their Entra ID username (e.g., `first.last@example.com`).

---

## OpenID Connect (OIDC)

RPI supports any OpenID Connect-compliant identity provider. The chart includes built-in templates for **Keycloak** and **Okta**.

### Keycloak

```yaml
OpenIdProviders:
  enabled: true
  name: keycloak
  authorizationHost: https://<keycloak-host>/realms/<realm>
  clientID: <keycloak-client-id>
  audience: <keycloak-client-id>
  redirectURL: https://<rpi-interactionapi-host>
  enableRefreshTokens: true
  validateIssuer: false
  validateAudience: true
  logoutIdTokenParameter: id_token_hint
  customScopes:
    - openid
    - profile
  supportsUserManagement: false
```

### Okta

```yaml
OpenIdProviders:
  enabled: true
  name: Okta
  authorizationHost: https://<okta-domain>/oauth2/default
  clientID: <okta-client-id>
  audience: api://<okta-client-id>
  redirectURL: https://<rpi-interactionapi-host>
  enableRefreshTokens: true
  validateIssuer: false
  validateAudience: true
  logoutIdTokenParameter: id_token_hint
  customScopes:
    - api://<okta-client-id>/Interaction.Clients
  supportsUserManagement: false
```

### Configuration Reference

| Key | Description |
|-----|-------------|
| `name` | Provider name — must be `keycloak` or `Okta` (maps to the chart template) |
| `authorizationHost` | The OIDC issuer/authorization endpoint URL |
| `clientID` | The application/client ID registered with the identity provider |
| `audience` | The expected audience claim in the token |
| `redirectURL` | The Interaction API URL that receives the authentication callback |
| `enableRefreshTokens` | Allow token refresh for long-lived sessions |
| `validateIssuer` | Validate the token issuer claim against the authorization host |
| `validateAudience` | Validate the token audience claim |
| `logoutIdTokenParameter` | Parameter name used to pass the ID token during logout |
| `customScopes` | Additional OAuth scopes to request during authentication |
| `supportsUserManagement` | Whether the provider handles user provisioning |

---

## Using Both Methods

You can enable both Microsoft Entra ID and an OIDC provider simultaneously. Users will see multiple sign-in options in the RPI client. This is useful when migrating between identity providers or supporting users from different identity systems.

```yaml
MicrosoftEntraID:
  enabled: true
  interaction_client_id: <interaction-client Client ID>
  interaction_api_id: <interaction-api Client ID>
  tenant_id: <Azure Tenant ID>

OpenIdProviders:
  enabled: true
  name: keycloak
  authorizationHost: https://keycloak.example.com/realms/rpi
  clientID: <keycloak-client-id>
  audience: <keycloak-client-id>
  redirectURL: https://rpi-interactionapi.example.com
  enableRefreshTokens: true
  validateIssuer: false
  validateAudience: true
  logoutIdTokenParameter: id_token_hint
  customScopes:
    - openid
  supportsUserManagement: false
```
