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

Publish an attachment (`?filename=` is what triggers file handling — a bare
`-T`/`-d` body is just message text):

```bash
curl -H 'Authorization: Bearer <token>' -T file.zip 'https://ntfy.example.com/topic?filename=file.zip'
```

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
curl -H 'Authorization: Bearer <token>' -d 'hello' https://ntfy.example.com/mytopic
curl -H 'Authorization: Bearer <token>' -T file.zip https://ntfy.example.com/mytopic   ***REMOVED*** attachment
```

Subscribe in the ntfy phone app / web UI against `https://ntfy.example.com`
with the same token.

***REMOVED******REMOVED******REMOVED*** Agent `grizclaw` (zeroclaw notifications)

The zeroclaw agent `grizclaw` sends phone notifications through this ntfy.
Least-privilege setup, provisioned 2026-11-22:

- **User** `grizclaw`, role `user` (non-admin); password random and discarded —
  auth is token-only.
- **Grant**: write-only on topic `grizclaw-alerts` (`ntfy access grizclaw`
  → `grizclaw-alerts: write-only`). It cannot read the topic or anything
  else; the phone reads via the admin `bombom` token (read-all).
- **Token**: `ntfy token add grizclaw`, value lives only in
  `~/.zeroclaw/agents/grizclaw/workspace/.ntfy-token` (mode 600); the
  `bin/ntfy-send` script in that workspace uses it. Never commit it.
- A second, older token labeled `grizclaw-telegram` on the same user is
  unrelated to this setup — leave it alone.

Provisioning / verification:

```bash
kubectl -n ntfy exec deploy/ntfy -- ntfy user add --role=user grizclaw   ***REMOVED*** was already present
kubectl -n ntfy exec deploy/ntfy -- ntfy access grizclaw grizclaw-alerts wo   ***REMOVED*** wo = write-only
kubectl -n ntfy exec deploy/ntfy -- ntfy token add grizclaw              ***REMOVED*** prints token once
kubectl -n ntfy exec deploy/ntfy -- ntfy access grizclaw                 ***REMOVED*** → write-only access to topic grizclaw-alerts
kubectl -n ntfy exec deploy/ntfy -- ntfy user list                       ***REMOVED*** grizclaw: user, write-only on grizclaw-alerts
```

Revocation (independent of everything else):

```bash
kubectl -n ntfy exec deploy/ntfy -- ntfy token remove grizclaw <the-token>
kubectl -n ntfy exec deploy/ntfy -- ntfy access grizclaw reset           ***REMOVED*** drop the grant
kubectl -n ntfy exec deploy/ntfy -- ntfy user del grizclaw               ***REMOVED*** remove the user
```

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
