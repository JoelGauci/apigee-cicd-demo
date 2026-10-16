#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/cleanup.sh
# Purpose: Clean up all resources created on GCP for the Apigee CI/CD demo:
#          1. Undeploy and delete the Apigee API Proxy (apigee-cicd-v1)
#          2. Delete the Apigee KVM (apigee_secrets)
#          3. Delete the Secret in Secret Manager (secret_demo)
# ==============================================================================

set -uo pipefail

# Configuration defaults
GCP_PROJECT="${GCP_PROJECT:-apigee-x-jog}"
APIGEE_ORG="${APIGEE_ORG:-apigee-x-jog}"
APIGEE_ENV="${APIGEE_ENV:-prod}"
PROXY_NAME="${PROXY_NAME:-apigee-cicd-v1}"
KVM_NAME="${KVM_NAME:-apigee_secrets}"
SECRET_NAME="${SECRET_NAME:-secret_demo}"

echo "============================================================"
echo " GCP & Apigee Resource Cleanup"
echo "============================================================"
echo " GCP Project  : ${GCP_PROJECT}"
echo " Apigee Org   : ${APIGEE_ORG}"
echo " Apigee Env   : ${APIGEE_ENV}"
echo " API Proxy    : ${PROXY_NAME}"
echo " Apigee KVM   : ${KVM_NAME}"
echo " Secret Name  : ${SECRET_NAME}"
echo "============================================================"

# Obtain access token using gcloud
echo "Obtaining GCP access token..."
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "${ACCESS_TOKEN}" ]; then
  echo "Error: Failed to obtain GCP access token. Please run 'gcloud auth login' or configure credentials."
  exit 1
fi

# ------------------------------------------------------------------------------
# 1. Undeploy & Delete Apigee API Proxy
# ------------------------------------------------------------------------------
echo ""
echo "[1/3] Cleaning up Apigee API Proxy '${PROXY_NAME}'..."

# Check existing deployments in target environment
DEPLOYMENTS_JSON=$(curl --silent -X GET \
  "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/${APIGEE_ENV}/apis/${PROXY_NAME}/deployments" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

REVISIONS=$(echo "${DEPLOYMENTS_JSON}" | jq -r '.deployments[]?.revision // empty')

if [ -n "${REVISIONS}" ]; then
  for REV in ${REVISIONS}; do
    echo "  Undeploying revision ${REV} from environment '${APIGEE_ENV}'..."
    UNDEPLOY_RES=$(curl --silent -X DELETE \
      "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/${APIGEE_ENV}/apis/${PROXY_NAME}/revisions/${REV}/deployments" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}")
    echo "  Undeploy response: ${UNDEPLOY_RES}"
  done
else
  echo "  No active deployments found for '${PROXY_NAME}' in environment '${APIGEE_ENV}'."
fi

# Delete the API proxy from the organization
echo "  Deleting API proxy '${PROXY_NAME}' from organization '${APIGEE_ORG}'..."
DELETE_PROXY_CODE=$(curl --silent -o /dev/null -w "%{http_code}" -X DELETE \
  "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/apis/${PROXY_NAME}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

if [ "${DELETE_PROXY_CODE}" -eq 200 ]; then
  echo "  API Proxy '${PROXY_NAME}' successfully deleted."
elif [ "${DELETE_PROXY_CODE}" -eq 404 ]; then
  echo "  API Proxy '${PROXY_NAME}' does not exist (HTTP 404). Nothing to delete."
else
  echo "  Warning: Unexpected HTTP status deleting proxy: ${DELETE_PROXY_CODE}"
fi

# ------------------------------------------------------------------------------
# 2. Delete Apigee Key-Value Map (KVM)
# ------------------------------------------------------------------------------
echo ""
echo "[2/3] Cleaning up Apigee KVM '${KVM_NAME}' in environment '${APIGEE_ENV}'..."

DELETE_KVM_CODE=$(curl --silent -o /dev/null -w "%{http_code}" -X DELETE \
  "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/${APIGEE_ENV}/keyvaluemaps/${KVM_NAME}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

if [ "${DELETE_KVM_CODE}" -eq 200 ]; then
  echo "  KVM '${KVM_NAME}' successfully deleted."
elif [ "${DELETE_KVM_CODE}" -eq 404 ]; then
  echo "  KVM '${KVM_NAME}' does not exist (HTTP 404). Nothing to delete."
else
  echo "  Warning: Unexpected HTTP status deleting KVM: ${DELETE_KVM_CODE}"
fi

# ------------------------------------------------------------------------------
# 3. Delete Secret Manager Secret
# ------------------------------------------------------------------------------
#echo ""
#echo "[3/3] Cleaning up GCP Secret Manager secret '${SECRET_NAME}'..."

#if gcloud secrets describe "${SECRET_NAME}" --project="${GCP_PROJECT}" >/dev/null 2>&1; then
#  gcloud secrets delete "${SECRET_NAME}" \
#    --project="${GCP_PROJECT}" \
#    --quiet
#  echo "  Secret '${SECRET_NAME}' deleted successfully from Secret Manager."
#else
#  echo "  Secret '${SECRET_NAME}' does not exist in project '${GCP_PROJECT}'. Nothing to delete."
#fi

echo ""
echo "============================================================"
echo " Cleanup completed successfully!"
echo "============================================================"
