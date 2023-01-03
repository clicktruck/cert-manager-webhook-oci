#!/usr/bin/env bash

# Build, tag and push image to GCR (these are sample values, replace with your own)
## You'll need to host your own image

export IMAGE_PREFIX=pacphi
export GOOGLE_PROJECT_ID=fe-cphillipson
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.ssh/terraform@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com.json

## Authenticate to container registry
cat $GOOGLE_APPLICATION_CREDENTIALS | docker login -u _json_key --password-stdin https://us.gcr.io

## Clone
cd /tmp
git clone https://gitlab.com/jcotton/cert-manager-webhook-oci.git
cd cert-manager-webhook-oci
git checkout fix_and_update

## Build image
docker build -t ${IMAGE_PREFIX}/cert-manager-webhook-oci .

## Tag image
docker tag ${IMAGE_PREFIX}/cert-manager-webhook-oci us.gcr.io/${GOOGLE_PROJECT_ID}/cert-manager-webhook-oci:latest

## Push image
docker push us.gcr.io/${GOOGLE_PROJECT_ID}/cert-manager-webhook-oci:latest

## Cleanup
rm -Rf /tmp/cert-manager-webhook-oci