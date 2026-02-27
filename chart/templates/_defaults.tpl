{{/*
============================================================
  INTERNAL DEFAULTS
============================================================
  These values are managed by the chart and should NOT be
  exposed in values.yaml. Users can override any default via
  the `advanced:` block in their overrides file.

  Each component has a named template that returns YAML.
  Use with fromYaml + mustMergeOverwrite in templates:

    {{- $defaults := fromYaml (include "rpi.defaults.realtimeapi" .) -}}
    {{- $advanced := .Values.advanced.realtimeapi | default dict -}}
    {{- $user := .Values.realtimeapi | default dict -}}
    {{- $cfg := mustMergeOverwrite $defaults $advanced $user -}}
============================================================
*/}}

{{/* ======================================================
     GLOBAL DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.global" -}}
application:
  name: redpoint-interaction
  version: 7
deployment:
  images:
    imagePullPolicy: IfNotPresent
{{- end -}}

{{/* ======================================================
     SHARED COMPONENT DEFAULTS
     ======================================================
     Common boilerplate applied to all service components.
     Individual component defaults merge on top of this.
     ====================================================== */}}
{{- define "rpi.defaults.component.common" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: false
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     SHARED ROLLING UPDATE DEFAULTS
     ======================================================
     Used by Smart Activation Java components.
     ====================================================== */}}
{{- define "rpi.defaults.rollingUpdate" -}}
rollingUpdate:
  maxUnavailable: "25%"
  maxSurge: "25%"
  progressDeadlineSeconds: 600
{{- end -}}

{{/* ======================================================
     SECURITY CONTEXT DEFAULTS
     ====================================================== */}}

{{/* Global security context (.NET services) */}}
{{- define "rpi.defaults.securityContext" -}}
enabled: true
runAsUser: 7777
runAsGroup: 7777
fsGroup: 7777
runAsNonRoot: true
readOnlyRootFilesystem: true
privileged: false
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
supplementalGroups:
  - 4000
  - 5000
{{- end -}}

{{/* Smart Activation security context (Java services, uid 7777) */}}
{{- define "rpi.defaults.securityContext.smartactivation" -}}
enabled: true
runAsUser: 7777
runAsGroup: 7777
fsGroup: 7777
runAsNonRoot: true
readOnlyRootFilesystem: false
privileged: false
appArmorProfile: runtime/default
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}

{{/* Keycloak security context (uid 1001) */}}
{{- define "rpi.defaults.securityContext.keycloak" -}}
enabled: true
runAsUser: 1001
runAsGroup: 1001
fsGroup: 1001
runAsNonRoot: true
readOnlyRootFilesystem: false
privileged: false
appArmorProfile: runtime/default
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}

{{/* ======================================================
     HEALTH PROBE DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.livenessProbe" -}}
enabled: true
httpGet:
  path: /health/live
  port: 8080
  scheme: HTTP
initialDelaySeconds: 60
periodSeconds: 15
timeoutSeconds: 3
failureThreshold: 3
successThreshold: 1
{{- end -}}

{{- define "rpi.defaults.readinessProbe" -}}
enabled: true
httpGet:
  path: /health/ready
  port: 8080
  scheme: HTTP
initialDelaySeconds: 20
periodSeconds: 10
timeoutSeconds: 2
failureThreshold: 3
successThreshold: 1
{{- end -}}

{{- define "rpi.defaults.startupProbe" -}}
enabled: true
httpGet:
  path: /health/ready
  port: 8080
  scheme: HTTP
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 2
failureThreshold: 30
successThreshold: 1
{{- end -}}

{{/* ======================================================
     TOPOLOGY SPREAD CONSTRAINTS DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.topologySpreadConstraints" -}}
enabled: true
maxSkew: 1
topologyKey: kubernetes.io/hostname
whenUnsatisfiable: ScheduleAnyway
{{- end -}}

{{/* ======================================================
     NETWORK POLICY DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.networkPolicy" -}}
allowDNS: true
{{- end -}}

{{/* ======================================================
     INGRESS DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.ingress" -}}
className: nginx-redpoint-rpi
internalImageOverride:
  enabled: false
  image: registry.k8s.io/ingress-nginx/controller:v1.14.3@sha256:82917be97c0939f6ada1717bb39aa7e66c229d6cfb10dcfc8f1bd42f9efe0f81
service:
  port: 80
annotations:
  nginx.ingress.kubernetes.io/proxy-body-size: 4096m
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/enable-access-log: "true"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
{{- end -}}

{{/* ======================================================
     DATABASE DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.databases.operational" -}}
databaseSchema: dbo
encrypt: true
dateTimeSource: OperatingSystem
{{- end -}}

{{/* ======================================================
     REALTIME API DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.realtimeapi" -}}
multitenant: false
name: rpi-realtimeapi
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
enableHelpPages: true
enableEventListening: true
realtimeProcessingEnabled: true
ThresholdBetweenSiteVisitsMinutes: 120
ThresholdBetweenPageVisitsMinutes: 1
CacheWebFormData: false
decisionCacheDuration: 60
enableAuditMetricsInHeaders: true
cacheOutputQueueEnabled: true
RealtimeServerCookieEnabled: false
RealtimeServerCookieName: rg-visitor
RealtimeServerCookieExpires: 60
RealtimeServerCookieDomain: ""
RealtimeServerCookieHttpOnly: false
CacheOutputCollectIPAddress: true
HashVisitorID: false
EventListeningLocalCacheDuration: 60
dataMaps:
  visitorProfile:
    DaysToPersist: 365
    CompressData: true
  visitorHistory:
    DaysToPersist: 365
    CompressData: true
  nonVisitorData:
    DaysToPersist: 365
    CompressData: true
  productRecommendation:
    DaysToPersist: 365
    CompressData: true
  offerHistory:
    DaysToPersist: 365
    CompressData: true
  messageHistory:
    DaysToPersist: 365
    CompressData: true
idValidation:
  enableVisitorIDValidation: true
  visitorID:
    minimumLength: 1
    maximumLength: 36
    enableLetters: true
    enableNumbers: true
    permittedCharacters:
      - "-"
      - "_"
      - "/"
      - "."
      - "@"
      - "#"
      - "&"
      - "?"
  enableDeviceIDValidation: true
  deviceID:
    minimumLength: 1
    maximumLength: 36
    enableLetters: true
    enableNumbers: true
    permittedCharacters:
      - "-"
      - "_"
      - "/"
      - "."
      - "@"
      - "#"
      - "&"
      - "?"
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: true
terminationGracePeriodSeconds: 120
logging:
  realtimeagent:
    default: Error
    database: Error
    rpiTrace: Error
    rpiError: Error
    console: Error
  realtimeapi:
    default: Error
    endpoint: Error
    shared: Error
    plugins: Error
    other: Error
    console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
queueProvider:
  amazonsqs:
    visibilityTimeout: "301"
  azurestorage:
    sendVisibilityTimeout: 1
    receiveVisibilityTimeout: 1
  azureeventhubs:
    SendMessageBatchSize: 200
    ReceiveMessageBatchSize: 200
  amazonmsk:
    Acks: None
    CompressionType: Snappy
    MaxRetryAttempt: 10
    BatchSize: "1000000"
    LingerTime: 0
    UseAwsMsk: "True"
  rabbitmq:
    rabbitmqSettings:
      hostname: "rpi-realtimeapi-rabbitmq"
      username: redpointrpi
      virtualhost: /
      resources:
        enabled: true
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 1
          memory: 1Gi
      volumeClaimTemplates:
        enabled: true
        storage: 100Gi
      volumes:
        enabled: false
        claimName: rpi-realtimeapi-rabbitmq-data
      podDisruptionBudget:
        enabled: false
        minAvailable: 1
cacheProvider:
  redis:
    redisSettings:
      resources:
        enabled: true
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          memory: 3Gi
      volumeClaimTemplates:
        enabled: true
        storage: 50Gi
      podDisruptionBudget:
        enabled: false
        minAvailable: 1
{{- end -}}

{{/* ======================================================
     CALLBACK API DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.callbackapi" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: true
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     EXECUTION SERVICE DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.executionservice" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: false
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
  kedaScaledObject:
    serverAddress: ""
    useTriggerAuthentication: true
    authenticationRef: rpi-executionservice
    identityId: ""
    metricName: execution_max_thread_count
    query: ""
    threshold: "80"
    pollingInterval: 30
    minReplicaCount: 2
    maxReplicaCount: 10
    fallback:
      failureThreshold: 3
      replicas: 2
    behavior:
      scaleUp:
        stabilizationWindowSeconds: 300
        policies:
          type: Percent
          value: 100
          periodSeconds: 60
      scaleDown:
        stabilizationWindowSeconds: 300
        policies:
          type: Percent
          value: 50
          periodSeconds: 60
    terminationGracePeriodSeconds: 120
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
jobExecution:
  internalAddress: ""
  auditTaskEvents: true
  maxThreadsPerExecutionService: 100
  executionShutdownWaitForActivity: "00:08:00"
  overrideCustomSQLReservedWords: false
  maxSmartAssetInstancesForOfferCodes: "100000"
  rpdmOApiPrefixUri: /v1/
  rpdmOApiRequestTimeout: "200"
  taskTimeout: 60
  triggerCheckCriteriaInterval: 60
  triggersMaxDaysInactive: 180
  defaultMaintenanceModeBufferTime: "00:05:00"
  workflowPrioritization:
    enabled: true
    maxConcurrentWorkflowActivities: 100
    maximumQueueTime: "24:00:00"
internalCache:
  overrideDirectoryPath: true
  directoryPathOverride: StateCache
  backupToOpsDBInterval: "00:00:20"
  maxNumberRetries: "100"
  maxRetryDelay: "00:01:00"
  failOnPrimaryDataLoss: true
  failOnCacheConnectionError: true
  redisSettings:
    replicas: 1
    resources:
      enabled: true
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        memory: 3Gi
    volumeClaimTemplates:
      enabled: true
      storage: 100Gi
    podDisruptionBudget:
      enabled: false
      minAvailable: 1
seedService:
  memoryCacheSize: "10"
  maxNumberRetries: "100"
  maxRetryDelay: "00:01:00"
extraEnvs:
  - name: Plugins__LuxSci__IsSandboxMode
    enabled: false
    value: "true"
  - name: Plugins__SendGrid__EnableSandBoxMode
    enabled: false
    value: "true"
  - name: Plugins__Twilio__DisableSendSMSCampaign
    enabled: false
    value: "true"
  - name: RPI_MPULSE_UPSERT_CONTACT_DEBUG
    enabled: false
    value: "1"
  - name: RPI_MPULSE_EVENT_UPLOAD_DEBUG
    enabled: false
    value: "1"
  - name: LC_ALL
    enabled: false
    value: "en_US.UTF-8"
  - name: LANG
    enabled: false
    value: "en_US.UTF-8"
  - name: LANGUAGE
    enabled: false
    value: "en_US.UTF-8"
  - name: RPI_MPULSE_EVENT_UPLOAD_FAIL_DEBUG
    enabled: false
    value: "0"
  - name: RPI_MPULSE_EVENT_UPLOAD_SCENARIO
    enabled: false
    value: "1,5,2,3,5,7"
  - name: RPI_MPULSE_SAVE_MPULSE_EVENT_CONTENT_DEBUG
    enabled: false
    value: "1"
  - name: RPI_MPULSE_UPSERT_CONTACT_IMPORT_PATH_DEBUG
    enabled: false
    value: "/rpifileoutputdir/mpulse-debug-path"
{{- end -}}

{{/* ======================================================
     INTERACTION API DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.interactionapi" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
authMetaHttpEnabled: true
enableSwagger: true
allowSavingLoginDetails: true
alwaysShowClientsAtLogin: true
useExternalUserManagement: false
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: false
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     INTEGRATION API DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.integrationapi" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
enableSwagger: true
authMetaHttpEnabled: false
read_timeout: "300000"
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: true
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     NODE MANAGER DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.nodemanager" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: false
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     DEPLOYMENT API DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.deploymentapi" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: false
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     QUEUE READER DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.queuereader" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
isFormProcessingEnabled: true
isEventProcessingEnabled: true
isCacheProcessingEnabled: true
queueListenerEnabled: true
isCallbackServiceProcessingEnabled: true
listenerQueueNonActiveQueuePath: listenerQueueNonActive
listenerQueueNonActiveTTLDays: 14
listenerQueueErrorQueuePath: listenerQueueError
listenerQueueErrorTTLDays: 14
threadPoolSize: 10
timeoutMinutes: 60
maxBatchSize: 50
useMessageLocks: true
realtimeConfiguration:
  distributedCache:
    redisSettings:
      replicas: 1
      resources:
        enabled: true
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          memory: 3Gi
      volumeClaimTemplates:
        enabled: true
        storage: 100Gi
      podDisruptionBudget:
        enabled: false
        minAvailable: 1
  distributedQueue:
    rabbitmqSettings:
      virtualhost: /
      resources:
        enabled: true
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          memory: 3Gi
      volumeClaimTemplates:
        enabled: true
        storage: 100Gi
      volumes:
        enabled: false
        claimName: rpi-queuereader-rabbitmq-data
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: true
terminationGracePeriodSeconds: 120
logging:
  default: Error
  database: Error
  rpiTrace: Error
  rpiError: Error
  Console: Error
autoscaling:
  type: hpa
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: false
  minAvailable: 1
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     REBRANDLY DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.rebrandly" -}}
baseUrl: https://api.rebrandly.com
enterpriseBaseUrl: https://enterprise-api.rebrandly.com
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
replicas: 1
serviceAccount:
  enabled: true
redisSettings:
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      memory: 3Gi
      cpu: 3000m
  volumeClaimTemplates:
    enabled: false
    type: dynamic
    size: 50Gi
    storageClassName: default
    accessModes: ReadWriteOnce
service:
  port: 80
customMetrics:
  enabled: false
  prometheus_scrape: false
terminationGracePeriodSeconds: 120
logging:
  default: Error
  aspNetCore: Error
resources:
  enabled: true
{{- end -}}

{{/* ======================================================
     DIAGNOSTICS MODE DEFAULTS
     ====================================================== */}}
{{- define "rpi.defaults.diagnosticsMode" -}}
dotNetTools:
  enabled: false
  useGcDump: false
  useCounters: false
  path: /app/dotnet-tools
  extractionBaseDir: /tmp
netutils:
  enabled: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 7777
    runAsGroup: 7777
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    privileged: false
    appArmorProfile:
      type: RuntimeDefault
    capabilities:
      drop:
        - ALL
      add: ["NET_ADMIN", "NET_RAW"]
{{- end -}}

{{/* ======================================================
     AUTH SERVICE DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.authservice" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
logging:
  verbosity: DEBUG
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
terminationGracePeriodSeconds: 120
resources:
  enabled: true
  java_options: "-Xmx1536m"
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
rollingUpdate:
  maxUnavailable: "25%"
  maxSurge: "25%"
  progressDeadlineSeconds: 600
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     KEYCLOAK DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.keycloak" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
resources:
  enabled: true
securityContext:
  enabled: true
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
rollingUpdate:
  maxUnavailable: "25%"
  maxSurge: "25%"
  progressDeadlineSeconds: 600
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     INIT SERVICE DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.initservice" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
resources:
  enabled: true
  java_opts: "-Xmx2150m"
logging:
  verbosity: DEBUG
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
rollingUpdate:
  maxUnavailable: "25%"
  maxSurge: "25%"
  progressDeadlineSeconds: 600
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     MESSAGE QUEUE DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.messageq" -}}
type: StatefulSet
port: 5672
serviceAccount:
  enabled: true
resources:
  enabled: true
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
podDisruptionBudget:
  enabled: false
  minAvailable: 1
volumeClaimTemplates:
  storage: 100Gi
{{- end -}}

{{/* ======================================================
     MAINTENANCE SERVICE DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.maintenanceservice" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
port: 80
resources:
  enabled: true
  java_opts: "-Xmx1536m"
logging:
  verbosity: DEBUG
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
rollingUpdate:
  maxUnavailable: "25%"
  maxSurge: "25%"
  progressDeadlineSeconds: 600
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     SERVICES API DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.servicesapi" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
resources:
  enabled: true
  java_opts: "-Xmx2150m"
logging:
  verbosity: DEBUG
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     SOCKET.IO DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.socketio" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
keycloak_realm: "redpoint-mercury"
service:
  port: 80
resources:
  enabled: true
  java_opts: "-Xmx1536m"
logging:
  verbosity: DEBUG
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     UI SERVICE DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.uiservice" -}}
type: deployment
rollout:
  autoPromotionEnabled: true
  revisionHistoryLimit: 3
serviceAccount:
  enabled: true
service:
  port: 80
resources:
  enabled: true
  java_opts: "-Xmx2150m"
logging:
  verbosity: DEBUG
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
podDisruptionBudget:
  enabled: false
  minAvailable: 1
{{- end -}}

{{/* ======================================================
     CDP CACHE DEFAULTS (Smart Activation)
     ====================================================== */}}
{{- define "rpi.defaults.cdpcache" -}}
type: StatefulSet
serviceAccount:
  enabled: true
service:
  port: 6379
resources:
  enabled: true
securityContext:
  enabled: true
  runAsUser: 7777
  runAsGroup: 7777
  fsGroup: 7777
  runAsNonRoot: true
  readOnlyRootFilesystem: false
  privileged: false
  appArmorProfile: runtime/default
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
podDisruptionBudget:
  enabled: false
  minAvailable: 1
volumeClaimTemplates:
  storage: 100Gi
{{- end -}}
