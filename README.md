# image-build-cni-plugins

This image deploys the CNI plugin binaries. The binaries are: bandwidth,bridge,dhcp,firewall,flannel,host-device,host-local,ipvlan,loopback,macvlan,portmap,ptp,sbr,static,tuning,vlan,vrf

There are two important env variables:
* `SKIP_CNI_BINARIES`: specifies what cni binaries not to deploy
* `UPDATE_CNI_BINARIES`: true/false. In case the binary already exists, should it overwrite it?

Example how to use it:

```
  containers:
    - name: install-cnis
      image: rancher/hardened-cni-plugins:v1.0.1-build20221011
      volumeMounts:
      - mountPath: /host/opt/cni/bin
        name: cni-path
      env:
      - name: SKIP_CNI_BINARIES
        value: "firewall,flannel,host-device,ipvlan,macvlan,ptp,sbr,tuning,vlan,vrf"
  volumes:
  - hostPath:
      path: /opt/cni/bin
      type: DirectoryOrCreate
    name: cni-path


This image is being used by hardened-calico (to deploy all cni binaries) and cilium (to deploy portmap)
