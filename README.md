# ACME webhook for Oracle Cloud Infrastructure

This solver can be used when you want to use cert-manager with Oracle Cloud Infrastructure as a DNS provider.

## Requirements
-   [go](https://golang.org/) >= 1.19.4 *only for development*
-   [helm](https://helm.sh/) >= v3.10.2
-   [kubernetes](https://kubernetes.io/) >= v1.24.0
-   [cert-manager](https://cert-manager.io/) >= 1.10.1

## Clone

```bash
git clone https://github.com/pacphi/cert-manager-webhook-oci
```

## Installation

### cert-manager

Follow the [instructions](https://cert-manager.io/docs/installation/) using the cert-manager documentation to install it within your cluster.

### Webhook

#### From local checkout

```bash
helm install --namespace cert-manager cert-manager-webhook-oci deploy/cert-manager-webhook-oci
```
**Note**: The kubernetes resources used to install the Webhook should be deployed within the same namespace as the cert-manager.

To uninstall the webhook run
```bash
helm uninstall --namespace cert-manager cert-manager-webhook-oci
```

## Issuer

Create a `ClusterIssuer` or `Issuer` resource as following:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/directory

    # Email address used for ACME registration
    email: mail@example.com # REPLACE THIS WITH YOUR EMAIL!!!

    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-staging

    solvers:
      - dns01:
          webhook:
            groupName: acme.d-n.be
            solverName: oci
            config:
              ociProfileSecretName: oci-profile
              compartmentOCID: ocid-of-compartment-to-use
```

### Credentials

In order to access the Oracle Cloud Infrastructure API, the webhook needs an OCI profile configuration.

If you choose another name for the secret than `oci-profile`, ensure you modify the value of `ociProfileSecretName` in the `[Cluster]Issuer`.

The secret for the example above will look like this:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oci-profile
type: Opaque
stringData:
  tenancy: "your tenancy ocid"
  user: "your user ocid"
  region: "your region"
  fingerprint: "your key fingerprint"
  privateKey: |
    -----BEGIN RSA PRIVATE KEY-----
    ...KEY DATA HERE...
    -----END RSA PRIVATE KEY-----
  privateKeyPassphrase: "private keys passphrase or empty string if none"
```

### Create a certificate

Finally you can create certificates, for example:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: cert-manager
spec:
  commonName: example.com
  dnsNames:
    - example.com
  issuerRef:
    name: letsencrypt-staging
  secretName: example-cert
```

## Scripts

A collection of BaSH scripts is available in the [scripts](scripts) directory.  These are meant to help you prepare, install, and uninstall this webhook.

1. [Prepare](scripts/prepare-cert-manager-webhook-oci.sh)
  * Builds, tags, and pushes container image to a container image repository
  * Target repository provider is [OCIR](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm#Overview_of_Registry)
  * Update environment variables
  * Run this script only if you choose to host your own version of this webhook image in a private container image repository
2. [Install](scripts/install-cert-manager-webhook-oci.sh)
  * Helm chart local install
  * Update environment variables
  * Uncomment lines for pull secret creation only if you are hosting your own version of this webhook image
3. [Uninstall](scripts/uninstall-cert-manager-webhook-oci.sh)
  * Helm chart local uninstall

## Development

### Updating dependencies

Update the version of `go` in `go.mod` (currently 1.19), then:

```
go get -u
go mod tidy
```

### Running the test suite

All DNS providers **must** run the DNS01 provider conformance testing suite,
else they will have undetermined behaviour when used with cert-manager.

**It is essential that you configure and run the test suite when creating a
DNS01 webhook.**

First, create an Oracle Cloud Infrastructure account and ensure you have a DNS zone set up.
Next, create config files based on the `*.sample` files in the `testdata/oci` directory.

You can then run the test suite with:

```bash
TEST_ZONE_NAME=example.com. make test
```

## Credits

* Original repository - https://gitlab.com/dn13/cert-manager-webhook-oci/
* Fixes and updates - https://gitlab.com/jcotton/cert-manager-webhook-oci/-/tree/fix_and_update
* Gist - https://gist.github.com/pacphi/05e6bd49b312bb92b2db1d70beb5c69c