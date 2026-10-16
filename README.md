# Apigee CI/CD Demo

This project demonstrates an automated CI/CD pipeline for deploying Apigee X API proxies using GitHub Actions, integrated with Google Cloud Secret Manager, Apigee Key-Value Maps (KVM), and BDD integration testing with Apickli.

---

## Architecture & Workflow Overview

```mermaid
flowchart TD
    Dev[Developer] -->|Push code to main| GitHub[GitHub Repository]
    subgraph CI/CD [GitHub Actions Pipeline]
        Auth[1. Authenticate via Workload Identity Federation]
        FetchSecret[2. Fetch Secret from GCP Secret Manager]
        SyncKVM[3. Check & Synchronize Apigee KVM & Key Entry]
        Package[4. Package apiproxy bundle]
        Import[5. Import API Proxy Revision]
        Deploy[6. Deploy Revision to Environment]
        Wait[7. Wait until State is READY]
    end
    GitHub --> CI/CD
    CI/CD -->|gcloud secrets versions access| GSM[(GCP Secret Manager)]
    CI/CD -->|Apigee Management API| Apigee[(Apigee X Org: apigee-x-jog / Env: prod)]
    Apigee -->|Runtime KVM Read| Proxy[API Proxy: apigee-cicd-v1]
```

---

## Project Roadmap

| Step | Status | Description |
| :--- | :---: | :--- |
| **Step 0** | **Completed** | Project workspace initialization & documentation baseline |
| **Step 1** | **Completed** | GitHub Actions pipeline for Apigee API proxy deployment on push (using WIF) |
| **Step 2** | **Completed** | Secret Manager provisioning script & KVM synchronization (`apigee_secrets` / `secret_demo`) |
| **Step 3** | *Pending* | Apickli BDD integration test suite setup |
| **Step 4** | *Pending* | Integration of BDD tests into the CI/CD pipeline |
| **Step 5** | *Pending* | End-to-end execution, validation, and final wrap-up |

---

## Project Structure

```text
apigee-cicd-demo/
├── .github/
│   └── workflows/
│       └── deploy.yml      # CI/CD deployment pipeline with Secret Manager & KVM sync
├── apiproxy/               # Apigee API Proxy source code (apigee-cicd-v1)
│   ├── apigee-cicd-v1.xml
│   ├── policies/
│   │   └── KVM-GetSecret.xml
│   ├── proxies/
│   │   └── default.xml
│   └── targets/
│       └── default.xml
├── scripts/
│   └── create_secret.sh    # Shell script to create GCP secret and grant CI/CD access
├── tests/                  # Apickli BDD test suite
└── README.md               # Project documentation
```

---

## Workload Identity Federation (WIF) & Security Hardening

In traditional CI/CD setups, integrating GitHub Actions with Google Cloud relies on **downloadable Service Account JSON keys** stored as static repository secrets (`GCP_SA_KEY`). 

However, static service account keys introduce major security liabilities:
- **Credential leakage risks**: Keys stored long-term in GitHub Secrets, CI logs, or developer machines can be compromised or exfiltrated.
- **No automatic rotation**: Keys rarely get rotated regularly, increasing exposure time.
- **Enterprise restrictions**: Enterprise GCP organizations routinely enforce the constraint `constraints/iam.disableServiceAccountKeyCreation`, which strictly blocks the creation of service account keys.

### How Workload Identity Federation Works

Workload Identity Federation eliminates service account keys entirely by establishing a federated trust relationship between **GitHub Actions (OIDC Provider)** and **Google Cloud IAM (Security Token Service - STS)**.

```mermaid
sequenceDiagram
    autonumber
    participant GHA as GitHub Actions Runner
    participant GHOIDC as GitHub OIDC Token Service
    participant GCPSTS as GCP Security Token Service (STS)
    participant GCPIAM as GCP IAM Service Account
    participant GSM as GCP Secret Manager
    participant Apigee as Apigee X Management API

    GHA->>GHOIDC: 1. Request signed OIDC JWT token (repo & actor claims)
    GHOIDC-->>GHA: 2. Return short-lived GitHub JWT token
    GHA->>GCPSTS: 3. Exchange JWT token with WIF Provider
    Note over GCPSTS: Validates against token.actions.githubusercontent.com<br/>Checks assertion.repository == 'JoelGauci/apigee-cicd-demo'
    GCPSTS-->>GHA: 4. Return federated STS token
    GHA->>GCPIAM: 5. Impersonate apigee-deployer-sa using STS token
    GCPIAM-->>GHA: 6. Return short-lived Google OAuth2 Access Token
    GHA->>GSM: 7. Access secret version (secret_demo)
    GHA->>Apigee: 8. Sync KVM entry (apigee_secrets / secret_demo) & Deploy proxy
```

### Security Benefits of WIF

1. **Keyless Authentication (Zero Secrets)**: No static credentials stored in GitHub Secrets or disk.
2. **Strict Attribute Mapping & Scoping**: Only repository `JoelGauci/apigee-cicd-demo` can authenticate.
3. **Short-Lived Ephemeral Tokens**: Temporary tokens valid $\le$ 1 hour minimize the attack surface.
4. **Enhanced Auditability & Compliance**: Full traceability in Google Cloud Audit Logs.

---

## Step 2: Secret Manager & KVM Synchronization

### 1. Provision Secret in GCP Secret Manager

Run the helper script [`scripts/create_secret.sh`](file:///usr/local/google/home/joelgauci/repo/apigee-cicd-demo/scripts/create_secret.sh) from your local terminal:

```bash
# Basic usage (uses default secret name 'secret_demo')
./scripts/create_secret.sh

# Or specify custom secret name and value:
./scripts/create_secret.sh "secret_demo" "MySecureSecretValue2026!"
```

The script performs the following actions:
1. Enables the `secretmanager.googleapis.com` API if not yet enabled.
2. Creates the secret `secret_demo` with automatic replication.
3. Adds a new version containing the secret value.
4. Grants `roles/secretmanager.secretAccessor` on the secret to the Service Account `apigee-deployer-sa@apigee-x-jog.iam.gserviceaccount.com`.

### 2. CI/CD Pipeline KVM Synchronization

During each CI/CD execution:
1. **Secret Retrieval**: The pipeline fetches the latest version of `secret_demo` from Secret Manager using `gcloud secrets versions access`.
2. **Log Masking**: The value is registered with `::add-mask::` so that it will never appear in GitHub Actions console logs.
3. **KVM Creation**: The pipeline queries `GET /v1/organizations/apigee-x-jog/environments/prod/keyvaluemaps/apigee_secrets`. If it does not exist (HTTP 404), it creates the encrypted KVM.
4. **Key Entry Upsert**: The pipeline queries `GET .../keyvaluemaps/apigee_secrets/entries/secret_demo`. If present, it sends a `PUT` request to update the value; if absent, it sends a `POST` request to create the entry.
5. **Proxy Execution**: At runtime, the policy [`KVM-GetSecret.xml`](file:///usr/local/google/home/joelgauci/repo/apigee-cicd-demo/apiproxy/policies/KVM-GetSecret.xml) retrieves the value from `apigee_secrets` under key `secret_demo` and populates `private.flow.secret`.

---

## How to Test and Deploy Step 2

1. Execute the secret creation script locally:
   ```bash
   ./scripts/create_secret.sh secret_demo "MySuperSecretValue123!"
   ```
2. Commit and push the changes:
   ```bash
   git add scripts/create_secret.sh .github/workflows/deploy.yml README.md
   git commit -m "feat: add Secret Manager script and KVM sync to CI/CD pipeline"
   git push origin main
   ```
3. Watch the workflow execution in GitHub Actions:
   - Check the `Fetch Secret from Secret Manager` step output.
   - Check the `Synchronize Apigee KVM & Secret Entry` step output.
   - Confirm proxy deployment.
