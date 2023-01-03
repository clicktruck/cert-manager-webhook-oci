OS ?= $(shell go env GOOS)
ARCH ?= $(shell go env GOARCH)

IMAGE_NAME := "cert-manager-webhook-oci"
IMAGE_TAG := "latest"

OUT := $(shell pwd)/deploy

KUBE_VERSION=1.24.9

$(shell mkdir -p "$(OUT)")
export TEST_ASSET_ETCD=_test/kubebuilder/bin/etcd
export TEST_ASSET_KUBE_APISERVER=_test/kubebuilder/bin/kube-apiserver
export TEST_ASSET_KUBECTL=_test/kubebuilder/bin/kubectl

test: _test/kubebuilder
	/usr/local/opt/go@1.19.4/bin/go test -timeout 30s -v .

_test/kubebuilder:
	curl -fsSL https://go.kubebuilder.io/test-tools/$(KUBE_VERSION)/$(OS)/$(ARCH) -o kubebuilder-tools.tar.gz
	mkdir -p _test/kubebuilder
	tar -xvf kubebuilder-tools.tar.gz
	mv kubebuilder/bin _test/kubebuilder/
	rm kubebuilder-tools.tar.gz
	rm -R kubebuilder

clean: clean-kubebuilder

clean-kubebuilder:
	rm -Rf _test/kubebuilder

build:
	docker build -t "$(IMAGE_NAME):$(IMAGE_TAG)" .

.PHONY: rendered-manifest.yaml
rendered-manifest.yaml:
	helm template \
	    cert-manager-webhook-oci \
        --set image.repository=$(IMAGE_NAME) \
        --set image.tag=$(IMAGE_TAG) \
		--namespace cert-manager \
        deploy/cert-manager-webhook-oci > "$(OUT)/rendered-manifest.yaml"
