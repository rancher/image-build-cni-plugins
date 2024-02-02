ARG ARCH="amd64"
ARG TAG=v1.4.0
ARG FLANNEL_TAG="v1.4.0-flannel1"
ARG BCI_IMAGE=registry.suse.com/bci/bci-busybox
ARG GO_IMAGE=rancher/hardened-build-base:v1.20.7b3
ARG GOEXPERIMENT=boringcrypto

### Build the cni-plugins ###
FROM ${GO_IMAGE} as cni_plugins
ARG ARCH
ARG TAG=v1.4.0
ARG FLANNEL_TAG
ARG GOEXPERIMENT
RUN git clone --depth=1 https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins && \
    cd $GOPATH/src/github.com/containernetworking/plugins && \
    git fetch --all --tags --prune && \
    git checkout tags/${TAG} -b ${TAG} && \
    sh -ex ./build_linux.sh -v \
        -gcflags=-trimpath=/go/src \
        -ldflags " \
            -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=${TAG} \
            -linkmode=external -extldflags \"-static -Wl,--fatal-warnings\" \
        "
RUN git clone --depth=1 https://github.com/flannel-io/cni-plugin $GOPATH/src/github.com/flannel-io/cni-plugin && \
    cd $GOPATH/src/github.com/flannel-io/cni-plugin && \
    git fetch --all --tags --prune && \
    git checkout tags/${FLANNEL_TAG} -b ${FLANNEL_TAG} && \
    make build_linux && \
    mv $GOPATH/src/github.com/flannel-io/cni-plugin/dist/flannel-${ARCH} $GOPATH/src/github.com/containernetworking/plugins/bin/flannel

WORKDIR $GOPATH/src/github.com/containernetworking/plugins
RUN go-assert-static.sh bin/* && \
    if [ "${ARCH}" = "amd64" ]; then \
        go-assert-boring.sh bin/bandwidth \
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
    install -D -s bin/* /opt/cni/bin

# Create image with the cni-plugins
FROM ${BCI_IMAGE}
COPY --from=cni_plugins /opt/cni/ /opt/cni/
WORKDIR /
COPY install-cnis.sh .
ENTRYPOINT ["./install-cnis.sh"]
