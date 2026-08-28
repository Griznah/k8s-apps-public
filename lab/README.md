***REMOVED*** lab/ — bifrost upgrade-rehearsal mirror

Single-node Talos cluster (`k8s-lab-1` @ 10.0.50.141, tofu root
`bifrost/tofu/lab/`) running an explicit subset of k8s-apps for rehearsing
upgrades (Talos / K8s / Cilium / platform charts) before bifrost.

Wrappers reference the parent apps across directories (`../../<dir>/<app>`) —
ArgoCD builds kustomize with load-restrictor none, so this works in-cluster.
Local renders: `kubectl kustomize --load-restrictor LoadRestrictionsNone lab/<app>`.

***REMOVED******REMOVED*** Apps (lab/applications.yaml — apply manually after edits)

| App | Parent | Diffs |
|---|---|---|
| lab-cilium-cni | network/cilium | no hubble-ui route; manual sync, SSA |
| lab-argo-cd | argo/argo-cd | HA off (redis-ha/dex/appSet off, 1 replica); no gateway routes |
| lab-victoria-metrics | observability/victoria-metrics | no ksm/node-exporter scrapes |
| lab-cert-manager | security/cert-manager | no ClusterIssuers, no ksops |
| lab-proxmox-csi-plugin | storage/proxmox-csi-plugin | no ksops (Secret manual) |

Excluded entirely: downloads/*arr/qbt (storage NFS double-download), wireguard,
velero, cilium-lb (LB-IPAM pools/L2 policy — would ARP-collide with bifrost
VIPs), gateway routes, grafana/ksm/node-exporter.

***REMOVED******REMOVED*** One-time bootstrap

```bash
***REMOVED*** 1. ArgoCD itself (renders helm+ksops — needs local sops age key)
kubectl --kubeconfig ~/.kube/config-lab apply -k lab/argo-cd \
  --enable-helm --enable-alpha-plugins --enable-exec   ***REMOVED*** kustomize 5.21+: kubectl kustomize variant below

***REMOVED*** 2. Secrets ArgoCD needs before first sync
kubectl --kubeconfig ~/.kube/config-lab -n argo-system create secret generic sops-age-key \
  --from-file=keys.txt=<path-to-age-key>          ***REMOVED*** same key as bifrost's argo-system
kubectl --kubeconfig ~/.kube/config-lab -n csi-proxmox create -f <proxmox-csi secret>  ***REMOVED*** same token as bifrost

***REMOVED*** 3. App list
kubectl --kubeconfig ~/.kube/config-lab apply -f lab/applications.yaml
```

Wait for lab-argo-cd/lab-cert-manager/lab-victoria-metrics/lab-proxmox-csi-plugin
Healthy, then manually sync lab-cilium-cni (adopts the bootstrap cilium-cli
release in place, SSA — no reinstall).

***REMOVED******REMOVED*** Upgrade rehearsal

`bifrost/scripts/lab-upgrade.sh` — tofu apply, talosctl upgrade + upgrade-k8s,
cilium sync, health printout. Then apply the same versions to bifrost by hand
(see bifrost memory.md runbook).
