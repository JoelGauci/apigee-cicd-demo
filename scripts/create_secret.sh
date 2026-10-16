#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/create_secret.sh
# Purpose: Provision a secret in GCP Secret Manager and grant access to the
#          Apigee deployer Service Account used by GitHub Actions CI/CD.
# ==============================================================================

set -euo pipefail

# Configuration defaults (can be overridden by environment variables or CLI arguments)
GCP_PROJECT="${GCP_PROJECT:-apigee-x-jog}"
SECRET_NAME="${1:-secret_demo}"
SECRET_VALUE="${2:-DemoSecretValueFromSecretManager2026!}"
SA_EMAIL="${SA_EMAIL:-apigee-deployer-sa@${GCP_PROJECT}.iam.gserviceaccount.com}"

echo "============================================================"
echo " Google Cloud Secret Manager Provisioning"
echo "============================================================"
echo " Project ID       : ${GCP_PROJECT}"
echo " Secret Name      : ${SECRET_NAME}"
echo " Service Account  : ${SA_EMAIL}"
echo "============================================================"

# 1. Enable Secret Manager API if not already enabled
echo "[1/4] Ensuring Secret Manager API is enabled in project ${GCP_PROJECT}..."
gcloud services enable secretmanager.googleapis.com --project="${GCP_PROJECT}"

# 2. Check if secret exists; if not, create it
echo "[2/4] Checking if secret '${SECRET_NAME}' exists..."
if gcloud secrets describe "${SECRET_NAME}" --project="${GCP_PROJECT}" >/dev/null 2>&1; then
  echo " Secret '${SECRET_NAME}' already exists."
else
  echo " Creating secret '${SECRET_NAME}'..."
  gcloud secrets create "${SECRET_NAME}" \
    --project="${GCP_PROJECT}" \
    --replication-policy="automatic"
  echo " Secret '${SECRET_NAME}' created successfully."
fi

# 3. Add new secret version with payload
echo "[3/4] Adding new version with the secret value..."
printf "%s" "${SECRET_VALUE}" | gcloud secrets versions add "${SECRET_NAME}" \
  --project="${GCP_PROJECT}" \
  --data-file=-
echo " Secret version added successfully."

# 4. Grant Secret Accessor role to the CI/CD Service Account
echo "[4/4] Granting 'roles/secretmanager.secretAccessor' on '${SECRET_NAME}' to ${SA_EMAIL}..."
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
  --project="${GCP_PROJECT}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

echo "============================================================"
echo " Secret '${SECRET_NAME}' provisioned and accessible by CI/CD!"
echo " Verification: latest secret version value is:"
gcloud secrets versions access latest --secret="${SECRET_NAME}" --project="${GCP_PROJECT}"
echo ""
echo "============================================================"
