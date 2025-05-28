![rp_cdp_logo](https://github.com/RedPointGlobal/redpoint-rpi/assets/42842390/432d779f-de4e-4936-80fe-3caa4d732603)
# RPI Helm Chart - v7.6-RELEASE Notes

### New Features
- **GCP Service Account Support** ([CE-2311](#)):  
  - Added support for mounting Google Cloud Service Account files.
  - Configuration exposed via `values.yaml` to enable or disable as needed.

- **Azure Key Vault & Google Secrets Manager Integration** ([CE-2313](#)):  
  - Extended Helm chart with support for accessing secrets from Azure Key Vault and Google Secrets Manager.
  - Configurations are exposed through `values.yaml`.

- **Support for Auto Scaling** ([CE-2231](#)):  
  - Implemented Horizontal Pod Autoscaling (HPA) and custom metrics support.
  - Added Prometheus annotations for metrics scraping:

- **Support for OAuth authenticaion for RPI Realtime API** ([CE-2437](#)):  
  - Implemented OAuth 2.0 authentication for secure access to the RPI Realtime API.

- **Support for RPI Realtime Multi-tenancy** ([CE-2468](#)):  
  - Enabled multi-tenant support for RPI Realtime by allowing per-tenant deployments through customized values.yaml configurations.

---

### Enhancements
- **Cluster-Level Security & Extensibility** ([CE-2247](#)):  
  - Added support for:
    - Custom Annotations
    - Labels
    - SecurityContext configurations
  - Provided an option for end-users to opt-out of using our default `imagePullSecret`.

- **Container Image Sources** ([CE-2230](#)):  
  - Documented pre-requisites for external container registries during installation.
  - All dependent images are now published to the Redpoint Container Registry (ACR).
  - Image repositories are externalized in `values.yaml` for better governance and security alignment.

- **Configurable Service Port** ([CE-2229](#)):  
  - Exposed service port configuration via `services.port` in `values.yaml`.
  - Default remains as `80`, but can be adjusted for environments where port `80` is restricted.

- **Improved values.yaml Structure**:  
  - The `values.yaml` file has been restructured for better readability and organization.
  - Added detailed comments to explain the purpose and usage of each configuration setting, making it easier for users to understand and customize.