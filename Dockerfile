ARG BCI_IMAGE=registry.suse.com/bci/bci-busybox
ARG GO_IMAGE=rancher/hardened-build-base:v1.24.11b1
ARG GOEXPERIMENT=boringcrypto

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

### Build the cni-plugins ###
FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base_builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld
ARG TARGETPLATFORM
# setup required packages
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc 

FROM base_builder AS cni_plugins_builder
ARG TAG=v1.9.0
ARG FLANNEL_TAG=v1.8.0-flannel2
ARG BOND_COMMIT=dac19eb61de885201cec210573d333cf236274b4
ARG GOEXPERIMENT
#clone and get dependencies
RUN git clone --depth=1 https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins && \
    cd $GOPATH/src/github.com/containernetworking/plugins && \
    git fetch --all --tags --prune && \
    git checkout tags/${TAG} -b ${TAG} &&\
    go mod download

RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/bond-cni.git $GOPATH/src/github.com/k8snetworkplumbingwg/bond-cni && \
    cd $GOPATH/src/github.com/k8snetworkplumbingwg/bond-cni && \
    git fetch --unshallow --all --tags --prune && \
    git checkout ${BOND_COMMIT}

RUN git clone --depth=1 https://github.com/flannel-io/cni-plugin $GOPATH/src/github.com/flannel-io/cni-plugin && \
    cd $GOPATH/src/github.com/flannel-io/cni-plugin && \
    git fetch --all --tags --prune && \
    git checkout tags/${FLANNEL_TAG} -b ${FLANNEL_TAG} && \
    go mod download 
ARG TARGETPLATFORM
ENV CGO_ENABLED=1
# cross-compile cni-plugins
RUN cd $GOPATH/src/github.com/containernetworking/plugins && \
    GO=xx-go sh -ex ./build_linux.sh -v \
    -gcflags=-trimpath=/go/src \
    -ldflags " \
        -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=${TAG} \
        -linkmode=external -extldflags \"-static -Wl,--fatal-warnings\" \
    "
# cross-compile flannel
RUN cd $GOPATH/src/github.com/flannel-io/cni-plugin && \
    export GOOS=$(xx-info os) &&\
    export GOARCH=$(xx-info arch) &&\
    export ARCH=$(xx-info arch) &&\
    make build_linux && \
    mkdir -p $GOPATH/src/github.com/containernetworking/plugins/bin && \
    mv $GOPATH/src/github.com/flannel-io/cni-plugin/dist/flannel-${ARCH} $GOPATH/src/github.com/containernetworking/plugins/bin/flannel
# cross-compile bond
RUN cd $GOPATH/src/github.com/k8snetworkplumbingwg/bond-cni && \
    export GOOS=$(xx-info os) &&\
    export GOARCH=$(xx-info arch) &&\
    export ARCH=$(xx-info arch) &&\
    xx-go build -ldflags "-linkmode=external -extldflags \"-static -Wl,--fatal-warnings\"" -mod=vendor -o ./bin/bond ./bond/ && \
    mkdir -p $GOPATH/src/github.com/containernetworking/plugins/bin && \
    mv $GOPATH/src/github.com/k8snetworkplumbingwg/bond-cni/bin/bond $GOPATH/src/github.com/containernetworking/plugins/bin/bond

WORKDIR $GOPATH/src/github.com/containernetworking/plugins
RUN xx-verify --static bin/*
RUN go-assert-static.sh bin/* && \
    export ARCH=$(xx-info arch) && \
    if [ "${ARCH}" = "amd64" ]; then \
        go-assert-boring.sh bin/bandwidth \
        bin/bond \
        bin/bridge \
        bin/dhcp \
        bin/firewall \
        bin/host-device \
        bin/host-local \
        bin/ipvlan \
        bin/macvlan \
        bin/portmap \
        bin/ptp \
        bin/vlan ; \
    fi && \
    mkdir -vp /opt/cni/bin && \
    install -D bin/* /opt/cni/bin

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=cni_plugins_builder /opt/cni/ /opt/cni/
RUN for plugin in $(ls /opt/cni/bin); do \
        strip /opt/cni/bin/${plugin}; \
    done


# Create image with the cni-plugins
FROM ${BCI_IMAGE}
COPY --from=strip_binary /opt/cni/ /opt/cni/
WORKDIR /
COPY install-cnis.sh .
ENTRYPOINT ["./install-cnis.sh"]
