***REMOVED*** ntfy (notifications)

Self-hosted [ntfy](https://ntfy.sh) pub/sub notification server — HTTP-based
push to phones (ntfy app), browsers and scripts. Serves
`ntfy(.k8s)?.example.com` via the consolidated gateway.

***REMOVED******REMOVED*** Layout

| File | What |
|---|---|
| `resources/ntfy-deployment.yaml` | Deployment (Recreate, **replicas=1** — SQLite single-writer) + `ntfy-cache` PVC |
| `resources/ntfy-service.yaml` | ClusterIP :80 |
| `resources/ntfy-gateway-route.yaml` | HTTPRoute `ntfy(.k8s)?.example.com` |
| `secrets/ntfy-secret.yaml` | SOPS: whole `server.yml` (contains S3 credentials) |
| `secrets/ntfy-secret.yaml.example` | plaintext template |

Image digest-pinned (`images:` override in `kustomization.yaml`) — bump tag +
digest there.

***REMOVED******REMOVED*** Storage split

- **PVC `ntfy-cache` (1Gi, `storage-fast`)** — `cache.db` (12h message
  cache) **and `user.db` (auth DB)**. Velero FS-backup via the
  `backup.velero.io/backup-volumes: cache` annotation: users/tokens survive
  restores.
- **S3 bucket `ntfy` on storage SeaweedFS** (`storage-s3.lan.example.com:8333`) —
  attachments, `registry` user, full URL in `server.yml`.

⚠ **ntfy owns that bucket outright**: it deletes objects it doesn't know about
(3h attachment expiry sweeper). Never point anything else at bucket `ntfy`.

⚠ **Known broken (2026-10-11):** `PutObject` to bucket `ntfy` returns
`InternalError` storage-side (velero user PUTs to `backups` fine, so the gateway
and write path are healthy — the bucket config itself is faulty). Messages,
auth and the web UI all work; attachment uploads 500 until the bucket is
fixed/recreated on storage (`weed shell`: `s3.bucket.configure -bucket ntfy …`,
compare against `backups`). No cluster change needed once fixed.

***REMOVED******REMOVED*** Auth

`auth-default-access: deny-all` — anonymous gets nothing (403). Users/tokens
live in `user.db` on the PVC, managed via CLI:

```bash
kubectl -n ntfy exec deploy/ntfy -- ntfy user list
kubectl -n ntfy exec deploy/ntfy -- ntfy user add --role=admin NAME   ***REMOVED*** interactive pw prompt
kubectl -n ntfy exec deploy/ntfy -- ntfy token add bombom             ***REMOVED*** access token for scripts/phone
```

Publish with a token:

```bash
curl -H 'Authorization: Bearer tk_…' -d 'hello' https://ntfy.example.com/mytopic
curl -H 'Authorization: Bearer tk_…' -T file.zip https://ntfy.example.com/mytopic   ***REMOVED*** attachment
```

Subscribe in the ntfy phone app / web UI against `https://ntfy.example.com`
with the same token.

***REMOVED******REMOVED*** Config changes

`server.yml` is mounted subPath from the SOPS secret — **no hot reload**:

```bash
sops -e -i div/ntfy/secrets/ntfy-secret.yaml   ***REMOVED*** after editing
kubectl -n ntfy delete pod -l app=ntfy         ***REMOVED*** restart to pick it up
```

New SOPS-file keys or flagged patterns: update `.secrets.baseline`
(`detect-secrets scan <files>`, mark `is_secret: false`) or the commit is
blocked. Watch for hook `Passed`/`Failed` lines — a failed commit hides
behind `| tail`.
