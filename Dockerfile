ARG ARCH="amd64"
ARG TAG="v0.9.1"
ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.16.10b7

### Build the cni-plugins ###
FROM ${GO_IMAGE} as cni_plugins
ARG ARCH
ARG TAG
RUN git clone --depth=1 https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && git fetch --all --tags --prune \
    && git checkout tags/${TAG} -b ${TAG} \
    && sh -ex ./build_linux.sh -v \
    -gcflags=-trimpath=/go/src \
    -ldflags " \
        -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=${TAG} \
        -linkmode=external -extldflags \"-static -Wl,--fatal-warnings\" \
    "
WORKDIR $GOPATH/src/github.com/containernetworking/plugins
RUN go-assert-static.sh bin/* \
    && if [ "${ARCH}" != "s390x" ]; then \
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
           fi \
    && mkdir -vp /opt/cni/bin \
    && install -D -s bin/* /opt/cni/bin

# Create image with the cni-plugins
FROM ${UBI_IMAGE}
COPY --from=cni_plugins /opt/cni/ /opt/cni/
WORKDIR /
COPY install-cnis.sh .
ENTRYPOINT ["./install-cnis.sh"]
