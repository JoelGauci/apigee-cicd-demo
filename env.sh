#!/usr/bin/env bash
# ==============================================================================
# Environment Configuration for Apigee CI/CD Pipeline & Helper Scripts
# ==============================================================================
# This file centralizes all environment variables for the deployment workflow,
# test executions, and provisioning/cleanup scripts.
# It can be sourced directly (source env.sh) or executed in CI (./env.sh).
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load overrides from .env if present
if [ -f "${SCRIPT_DIR}/.env" ]; then
  # shellcheck disable=SC1090
  set -a
  source "${SCRIPT_DIR}/.env"
  set +a
fi

# ------------------------------------------------------------------------------
# Default Configuration
# ------------------------------------------------------------------------------
export GCP_PROJECT="${GCP_PROJECT:-apigee-x-jog}"
export APIGEE_ORG="${APIGEE_ORG:-apigee-x-jog}"
export APIGEE_ENV="${APIGEE_ENV:-prod}"
export APIGEE_HOSTNAME="${APIGEE_HOSTNAME:-34.54.8.132.nip.io}"
export PROXY_NAME="${PROXY_NAME:-apigee-cicd-v1}"
export KVM_NAME="${KVM_NAME:-apigee_secrets}"
export KVM_KEY="${KVM_KEY:-secret_demo}"
export SECRET_NAME="${SECRET_NAME:-secret_demo}"
export WIF_PROVIDER="${WIF_PROVIDER:-projects/1014194238001/locations/global/workloadIdentityPools/github-pool/providers/github-provider}"
export WIF_SERVICE_ACCOUNT="${WIF_SERVICE_ACCOUNT:-apigee-deployer-sa@apigee-x-jog.iam.gserviceaccount.com}"
export DEPLOYMENT_MAX_ATTEMPTS="${DEPLOYMENT_MAX_ATTEMPTS:-30}"
export DEPLOYMENT_DELAY_SECONDS="${DEPLOYMENT_DELAY_SECONDS:-5}"
export NODE_VERSION="${NODE_VERSION:-20}"

# ------------------------------------------------------------------------------
# Propagate to GitHub Actions Environment ($GITHUB_ENV)
# ------------------------------------------------------------------------------
if [ -n "${GITHUB_ENV:-}" ]; then
  cat <<EOF >> "$GITHUB_ENV"
GCP_PROJECT=${GCP_PROJECT}
APIGEE_ORG=${APIGEE_ORG}
APIGEE_ENV=${APIGEE_ENV}
APIGEE_HOSTNAME=${APIGEE_HOSTNAME}
PROXY_NAME=${PROXY_NAME}
KVM_NAME=${KVM_NAME}
KVM_KEY=${KVM_KEY}
SECRET_NAME=${SECRET_NAME}
WIF_PROVIDER=${WIF_PROVIDER}
WIF_SERVICE_ACCOUNT=${WIF_SERVICE_ACCOUNT}
DEPLOYMENT_MAX_ATTEMPTS=${DEPLOYMENT_MAX_ATTEMPTS}
DEPLOYMENT_DELAY_SECONDS=${DEPLOYMENT_DELAY_SECONDS}
NODE_VERSION=${NODE_VERSION}
EOF
fi
