#!/usr/bin/env bash
set -eox pipefail

# Build, tag and push image to OCIR (these are sample values, replace with your own)
## Note: you may pull pre-built image from a public Oracle Container Image repository or host your own
## If you choose to host your own image then you must update the exported variables below to match your environment

on_ocir() {
  export IMAGE_PREFIX=pacphi
  export EMAIL_ADDRESS=you@yourdomain.com
  export COMPARTMENT_OCID=ocid1.compartment.oc1..aaaaaaaa_
  export REPOSITORY_NAME=cert-manager-webhook-oci
  export TENANCY_OCID=ocid1.tenancy.oc1..aaaaaaaa_
  export USER_OCID=ocid1.user.oc1..aaaaaaaa_
  export REGION=us-phoenix-1
  export REGION_KEY=phx
  export FINGERPRINT=47:5f:c7:0d:a3:a5:ac:d6:53:41:d2:23:c6:c9:24:a2

  # Oracle Cloud credentials
  export OCI_CONFIG_HOME=$HOME/.oci
  export OCI_PEM_PRIVATE_KEY_FILE_PATH=$OCI_CONFIG_HOME/oci_api_key.pem

  ## Check to see if registry repository exists
  DOES_REPO_EXIST=$(oci artifacts container repository list --compartment-id $COMPARTMENT_OCID | yq -p=json -M '.data.items[] | select(.display-name == env(REPOSITORY_NAME)) | has("display-name")')

  ## Create repository; if it does not exist
  if [ -z "$DOES_REPO_EXIST" ]; then
    oci artifacts container repository create --compartment-id $COMPARTMENT_OCID --display-name $REPOSITORY_NAME --is-public true --is-immutable false
  fi

  ## Obtain repository id and namespace
  REPOSITORY_ID=$(oci artifacts container repository list --compartment-id $COMPARTMENT_OCID | yq -p=json -M '.data.items[] | select(.display-name == env(REPOSITORY_NAME))' | yq '.id')
  TENANCY_NAMESPACE=$(echo "$REPOSITORY_ID" | cut -d '.' -f6)

  ## Obtain temporary auth token; we'll delete it after image is published
  AUTH_TOKEN_JSON=$(oci iam auth-token create --user-id $USER_OCID --description "Auth token (password) for use with OCIR")
  AUTH_TOKEN_ID=$(echo "$AUTH_TOKEN_JSON" | yq -p=json -M '.data.id')

  ## Wait a bit; auth token is not available immediately
  sleep 15

  ## Set Docker credentials
  DOCKER_USERNAME="$TENANCY_NAMESPACE/oracleidentitycloudservice/$EMAIL_ADDRESS"
  DOCKER_PASSWORD=$(echo "$AUTH_TOKEN_JSON" | yq -p=json -M '.data.token')

  ## Authenticate to container registry
  cat $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin $REGION_KEY.ocir.io

  ## Build image
  docker build -t ${IMAGE_PREFIX}/cert-manager-webhook-oci .

  ## Tag image
  docker tag ${IMAGE_PREFIX}/cert-manager-webhook-oci $REGION_KEY.ocir.io/${TENANCY_NAMESPACE}/cert-manager-webhook-oci:latest

  ## Push image
  docker push $REGION_KEY.ocir.io/${TENANCY_NAMESPACE}/cert-manager-webhook-oci:latest

  ## Delete auth token
  oci iam auth-token delete --user-id $USER_OCID --auth-token-id $AUTH_TOKEN_ID --force
}

## Clone
cd /tmp
git clone https://gitlab.com/jcotton/cert-manager-webhook-oci.git
cd cert-manager-webhook-oci
git checkout fix_and_update

on_ocir

## Cleanup
rm -Rf /tmp/cert-manager-webhook-oci