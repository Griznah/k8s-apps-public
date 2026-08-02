***REMOVED*** k8s - Kubernetes GitOps Repository

Repository for managing a home Kubernetes cluster using GitOps principles with Argo CD.

***REMOVED******REMOVED*** Overview

This repository contains Kubernetes manifests and Helm chart configurations for a personal/home cluster. The GitOps workflow is managed by Argo CD, which automatically syncs the cluster state with the definitions in this repository.

Argo CD ApplicationSets scan the directory structure and deploy applications to the cluster. Changes are deployed manually through Argo CD (no auto-sync) for safer control.

***REMOVED******REMOVED*** Directory Structure

| Directory | Description |
|-----------|-------------|
| `argo/` | Argo CD GitOps controller |
| `base/` | Base cluster infrastructure (currently empty — no live apps) |
| `observability/` | Monitoring (VictoriaMetrics, Grafana, node-exporter, kube-state-metrics) |
| `starrs/` | Media management suite (Sonarr, Radarr, Prowlarr, etc.) |
| `network/` | Networking (Cilium CNI, LB-IPAM, Gateway API) |
| `security/` | Security services (cert-manager for TLS certificates) |
| `storage/` | Storage provisioning (Proxmox CSI) |
| `downloads/` | Download managers (qBittorrent) |
| `media/` | Media servers (Audiobookshelf) |
| `div/` | Miscellaneous applications (metrics-server, etc.) |
| `backup/` | Backup (Velero) |

Each top-level directory contains an `applicationset.yaml` defining its AppProject +
ApplicationSet; apps under it typically ship a `kustomization.yaml` and Helm `values.yaml`.

***REMOVED******REMOVED*** Prerequisites

- Kubernetes cluster on Talos OS
- Argo CD installed and configured
- `kubectl` configured to access the cluster
- Helm v3+

***REMOVED******REMOVED*** Bootstrap: SOPS Age Key

Argo CD's repo-server decrypts SOPS-encrypted manifests at `kustomize build` time via the
ksops plugin. It needs the age private key mounted as a Secret — this is the one resource
that lives outside GitOps (ksops needs it to decrypt, so it can't be encrypted itself).

```bash
kubectl -n argo-system create secret generic sops-age-key --from-file=keys.txt=$HOME/.config/sops/age/keys.txt
```

> The Secret name (`sops-age-key`) and key (`keys.txt`) must match the values in
> `argo/argo-cd/values.yaml` (`repoServer.volumes[].secret.secretName` and
> `repoServer.extraEnv[].SOPS_AGE_KEY_FILE`). Only run this once; re-run if you rotate
> the age key.

***REMOVED******REMOVED*** Quick Start

1. Install Argo CD on your cluster: [Argo CD Documentation](https://argo-cd.readthedocs.io/en/stable/getting_started/)
2. Configure Argo CD to point to this repository
3. Create ApplicationSets or let the Git directory generator scan for applications
4. Sync applications manually through the Argo CD UI or CLI

***REMOVED******REMOVED*** Maintenance

Dependency updates are automated by [Renovate Bot](https://github.com/renovatebot/renovate). Pull requests are automatically created when new Helm chart versions are available.

***REMOVED******REMOVED*** External Documentation

- [Argo CD](https://argo-cd.readthedocs.io/) - GitOps continuous delivery
- [Cilium](https://docs.cilium.io/) - CNI, load balancing, Gateway API
- [VictoriaMetrics](https://docs.victoriametrics.com/) - Time-series metrics
- [Grafana](https://grafana.com/docs/) - Visualization and dashboards
- [cert-manager](https://cert-manager.io/docs/) - TLS certificate management
- [Helm](https://helm.sh/docs/) - Kubernetes package manager

***REMOVED******REMOVED*** Notes

- Directories ending in `.disabled` are excluded from deployment
- Server-side apply is enabled for all applications (handles large CRDs)
- Applications retain 5 revisions for rollback capability
- Sync is manual by design (auto-sync disabled) for some repos — changes are reviewed then synced
