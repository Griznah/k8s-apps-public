***REMOVED*** Velero (backup)

Backs up Kubernetes objects **and** persistent-volume data for the portable
workloads on bifrost, so apps can be restored with full data into another
cluster.

***REMOVED******REMOVED*** What this backs up

| Schedule | Scope | Cadence | TTL |
|---|---|---|---|
| `apps-daily` | namespaces `audiobookshelf`, `downloads`, `starrs` (objects + **config PVC only**) | daily 02:00 | 7 d |
| `apps-weekly` | same | Sun 02:30 | 4 w |
| `apps-monthly` | same | 1st 03:00 | 6 mo |
| `infra-secrets-daily` | `secrets` only in `cert-manager`, `csi-proxmox`, `gateway`, `argo-system`, `kube-system` | daily 03:30 | 14 d |

Excluded by design: `absa-ac`, `absa-ac-dev`, `app-beta`. Infra beyond its
runtime Secrets is rebuilt from git + Helm values.

***REMOVED******REMOVED*** PV data path: Kopia file-system backup (opt-in)

CSI snapshots are **not** used — the Proxmox CSI driver declares no snapshot
capability and the VolumeSnapshot CRDs aren't installed. PVCs are instead copied
at the file level by the `node-agent` DaemonSet (Kopia).

FS backup is **opt-in** (`defaultVolumesToFsBackup: false`): only each app's
small `config` PVC is backed up, selected by the `backup.velero.io/backup-volumes`
annotation on each StatefulSet pod template. The large read-only NFS media
mounts (movies, series, audiobooks, podcasts, ebooks, download dumps) are
deliberately **not** backed up — including them ballooned the Kopia repos to
multi-TB and filled `storage-s3`. Only `flaresolverr` and `unpackerr` have no
opt-in volume (no config PVC), so they are backed up at the object level only.

The target apps already write their own consistent on-disk backups (*arr
scheduled DB backups, audiobookshelf DB backups); Kopia captures those folders
alongside live config, so SQLite consistency is handled at the application layer.

***REMOVED******REMOVED*** Object storage

Locally hosted S3-compatible host `storage-s3.lan.example.com`, bucket `backups`,
prefix `velero/bifrost`, region `us-east-1`, path-style addressing.

***REMOVED******REMOVED*** Credentials

The `cloud-credentials` Secret in `velero` is **created manually** (not rendered
by the chart, not ArgoCD-managed — same pattern as the proxmox-csi-plugin
Secret). See `secrets/cloud-credentials.yaml.example`.

```bash
kubectl apply -f backup/velero/secrets/cloud-credentials.yaml
```

***REMOVED******REMOVED*** Deploy / bootstrap

This app is wired through `backup/applicationset.yaml` (AppProject `backup`).
ArgoCD does not auto-discover new top-level applicationsets, so apply it once:

```bash
kubectl apply -f backup/applicationset.yaml
```

ArgoCD then renders `backup/velero` (kustomize + Helm, CRDs included) and syncs
it. The `cloud-credentials` Secret must exist before the Velero pods will start.

***REMOVED******REMOVED*** Verify

```bash
export KUBECONFIG=~/.kube/config-bifrost
kubectl -n velero get pods                      ***REMOVED*** velero + node-agent (3/3)
kubectl -n velero get backupstoragelocation     ***REMOVED*** default = Available
kubectl -n velero get schedules
***REMOVED*** trigger an ad-hoc run of the apps backup:
kubectl -n velero create backup --from-schedule apps-daily apps-daily-manual
kubectl -n velero get backup
kubectl -n velero describe backup apps-daily-manual
```

***REMOVED******REMOVED*** Restore (into another cluster)

```bash
***REMOVED*** On the target cluster (same velero install, same bucket/credentials):
velero backup-location create default ...   ***REMOVED*** point at the same BSL
velero restore create --from-backup apps-daily-manual
***REMOVED*** or restore just one namespace:
velero restore create --from-backup apps-daily-manual --include-namespaces starrs
```

PV data is restored via Kopia regardless of the target storage driver, so the
target cluster does **not** need Proxmox CSI — only a StorageClass to bind the
re-created PVCs.

***REMOVED******REMOVED*** Not covered by Velero

- **etcd** (whole-cluster DR): add a separate scheduled `talosctl etcd snapshot`
  into the same S3 host. TODO.
- **Infra manifests**: already in git (ArgoCD) — that IS the infra backup.
