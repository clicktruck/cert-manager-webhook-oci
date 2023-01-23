#!/usr/bin/env bash
set -eox pipefail

# Uninstall the resources supporting cert-manager deployed on OKE
# vending valid certificate via a Let's Encrypt ClusterIssuer

cd /tmp

kubectl delete -f oci/

rm -Rf /tmp/oci
rm -Rf /tmp/cert-manager-webhook-oci

# Delete namespace used to store secret
kubectl delete secret --all -n contour-tls
kubectl delete ns contour-tls

# Uninstall cert-manager OCI webhook
helm uninstall --namespace cert-manager cert-manager-webhook-oci
#helm repo remove cert-manager-webhook-oci

# Uninstall cert-manager
helm uninstall --namespace cert-manager cert-manager
helm repo remove jetstack

kubectl delete secret --all -n cert-manager
kubectl delete namespace cert-manager

# Uninstall Contour ingress
kubectl delete -f https://projectcontour.io/quickstart/contour.yaml
