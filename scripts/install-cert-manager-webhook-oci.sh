#!/usr/bin/env bash

indent4() { sed 's/^/    /'; }

# Install the necessary resources to support cert-manager deployed on OKE
# vending valid certificate via a Let's Encrypt ClusterIssuer

# Set environemnt variables (these are sample values, please replace with your own)
export DOMAIN=foo.me
export EMAIL_ADDRESS=any@valid.email
export COMPARTMENT_OCID=ocid1.compartment.oc1..aaaaaaaa_
export TENANCY_OCID=ocid1.tenancy.oc1..aaaaaaaa_
export USER_OCID=ocid1.user.oc1..aaaaaaaa_
export REGION=us-phoenix-1
export FINGERPRINT=47:5f:c7:0d:a3:a5:ac:d6:53:41:d2:23:c6:c9:24:a2

# Oracle Cloud credentials
export OCI_CONFIG_HOME=$HOME/.oci
export OCI_PEM_PRIVATE_KEY_FILE_PATH=$OCI_CONFIG_HOME/oci_api_key.pem

# Google Cloud credentials (where I've decided to host updated webhook container image)
export GOOGLE_PROJECT_ID=fe-cphillipson
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.ssh/terraform@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com.json

# Convert PEM private key to RSA
openssl rsa -in $OCI_PEM_PRIVATE_KEY_FILE_PATH -out $OCI_CONFIG_HOME/oci_api_rsa_key
export RSA_PRIVATE_KEY=$(cat $OCI_CONFIG_HOME/oci_api_rsa_key | indent4)

# Install Contour ingress
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.10.1 \
  --set installCRDs=true \
  --set prometheus.enabled=false \
  --set webhook.timeoutSeconds=30

# Install cert-manager OCI webhook
# This is from a fork of https://gitlab.com/dn13/cert-manager-webhook-oci
# @see https://gitlab.com/jcotton/cert-manager-webhook-oci.git
git clone https://gitlab.com/jcotton/cert-manager-webhook-oci.git
cd cert-manager-webhook-oci
git checkout fix_and_update
helm install --namespace cert-manager cert-manager-webhook-oci ./deploy/cert-manager-webhook-oci \
  --set image.repository=us.gcr.io/$GOOGLE_PROJECT_ID/cert-manager-webhook-oci

# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=us.gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat $GOOGLE_APPLICATION_CREDENTIALS)" \
  --docker-email=${EMAIL_ADDRESS} \
  --namespace cert-manager

# Create namespace to store secret
kubectl create ns contour-tls

mkdir -p /tmp/oci
cd /tmp/oci

# Define ClusterIssuer
cat << EOF > cluster-issuer-oci.yml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory

    # Email address used for ACME registration
    email: $EMAIL_ADDRESS

    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod

    solvers:
      - dns01:
          webhook:
            groupName: acme.d-n.be
            solverName: oci
            config:
              ociProfileSecretName: oci-profile
              compartmentOCID: $COMPARTMENT_OCID
EOF

# Define Secret with OCI credentials
cat << EOF > secret-oci.yml
apiVersion: v1
kind: Secret
metadata:
  name: oci-profile
  namespace: cert-manager
type: Opaque
stringData:
  tenancy: "$TENANCY_OCID"
  user: "$USER_OCID"
  region: "$REGION"
  fingerprint: "$FINGERPRINT"
  privateKey: |
$RSA_PRIVATE_KEY
  privateKeyPassphrase: ""
EOF

# Define Certificate
cat << EOF > certificate-oci.yml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tls
  namespace: contour-tls
spec:
  commonName: $DOMAIN
  dnsNames:
    - $DOMAIN
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: tls
EOF

cd ..

# Let it rip!
kubectl apply -f oci/