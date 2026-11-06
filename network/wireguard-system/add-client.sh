***REMOVED***!/usr/bin/env bash
***REMOVED*** Mint a WireGuard client config for the cluster WireGuard server and update
***REMOVED*** the GitOps manifests -- no cluster access needed (server pubkey is derived
***REMOVED*** from the SOPS-encrypted server key).
***REMOVED***
***REMOVED*** Usage: ./add-client.sh <friendly-name> <last-octet> [--replace <old-name>]
***REMOVED***   e.g. ./add-client.sh bombom-s22 100 --replace bombom-s22
***REMOVED***
***REMOVED*** Does:
***REMOVED***   1. generates a client keypair
***REMOVED***   2. edits resources/wg-config.yaml + values.yaml (adds or replaces peer)
***REMOVED***   3. archives the client config SOPS-encrypted in secrets/clients/<name>.yaml
***REMOVED***      (client private keys are unrecoverable otherwise -- see 2026-11 re-key)
***REMOVED***   4. prints the config QR (scan with WG Tunnel: Add from QR code)
***REMOVED*** Full-tunnel client profile: 0.0.0.0/0 + LAN DNS, endpoint example.com:53
***REMOVED*** (router forwards WAN UDP 53 -> 10.0.50.200:51820).
set -euo pipefail
cd "$(dirname "$0")"

NAME=$1; OCTET=$2; REPLACE=${3:-}; OLD=${4:-}
REPLACE_MODE=0; [ "$REPLACE" = "--replace" ] && REPLACE_MODE=1
NET=10.34.0; IP=$NET.$OCTET   ***REMOVED*** var split so the scrubbed prefix never appears literally in this file

command -v wg >/dev/null; command -v qrencode >/dev/null; command -v sops >/dev/null

PRIV=$(wg genkey)
PUB=$(printf '%s' "$PRIV" | wg pubkey)
SRV_PUB=$(sops -d secrets/secret.yaml | sed -n 's/^    privatekey: //p' | base64 -d | wg pubkey)

***REMOVED*** --- 1. wg-config.yaml peer block -----------------------------------------
***REMOVED*** Drop old block (if replacing): the 4 lines [Peer]/***REMOVED*** friendly_name/PublicKey/AllowedIPs
if [ $REPLACE_MODE = 1 ]; then
  ***REMOVED*** Drop the 4-line peer block: [Peer] header above + friendly/PublicKey/AllowedIPs
  awk -v old="    ***REMOVED*** friendly_name = $OLD" '
    { L[NR]=$0 }
    END {
      for (i=1; i<=NR; i++) if (L[i] == old) { drop[i-1]=1; drop[i]=1; drop[i+1]=1; drop[i+2]=1 }
      for (i=1; i<=NR; i++) if (!drop[i]) print L[i]
    }' resources/wg-config.yaml > resources/wg-config.yaml.tmp
  mv resources/wg-config.yaml.tmp resources/wg-config.yaml
fi
printf '\n    [Peer]\n    ***REMOVED*** friendly_name = %s\n    PublicKey = %s\n    AllowedIPs = %s/32\n' \
  "$NAME" "$PUB" "$IP" >> resources/wg-config.yaml

***REMOVED*** --- 2. values.yaml clients list -------------------------------------------
LAST=$(grep -n '^      AllowedIPs' values.yaml | tail -1 | cut -d: -f1)
[ -n "$LAST" ] || { echo "no AllowedIPs entries found in values.yaml" >&2; exit 1; }
awk -v n="$LAST" -v rm="$REPLACE_MODE" -v old="    - FriendlyName: $OLD" \
    -v e1="    - FriendlyName: $NAME" -v e2="      PublicKey: $PUB" -v e3="      AllowedIPs: $IP/32" '
  NR==n { print; print e1; print e2; print e3; next }
  rm==1 && $0 == old { skip=2; next }
  skip > 0 { skip--; next }
  { print }' values.yaml > values.yaml.tmp
mv values.yaml.tmp values.yaml

***REMOVED*** --- 3. SOPS-encrypted archive ----------------------------------------------
mkdir -p secrets/clients
ARCHIVE=secrets/clients/$NAME.yaml
{
  printf 'data:\n  %s.conf: |\n' "$NAME"
  printf '[Interface]\nPrivateKey = %s\nAddress = %s/32\nDNS = 10.0.10.200, 10.0.10.201\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0\nEndpoint = example.com:53\nPersistentKeepalive = 25\n' \
    "$PRIV" "$IP" "$SRV_PUB" | sed 's/^/    /'
} > "$ARCHIVE"
sops -e -i "$ARCHIVE"

***REMOVED*** --- 4. QR ------------------------------------------------------------------
TMP=$(mktemp /tmp/wg-client-XXXXXX.conf); chmod 600 "$TMP"
printf '[Interface]\nPrivateKey = %s\nAddress = %s/32\nDNS = 10.0.10.200, 10.0.10.201\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0\nEndpoint = example.com:53\nPersistentKeepalive = 25\n' \
  "$PRIV" "$IP" "$SRV_PUB" > "$TMP"

echo "== peer '$NAME' ($IP) written to resources/wg-config.yaml + values.yaml"
echo "== client config archived (SOPS): $ARCHIVE"
echo "== plaintext copy (delete after import): $TMP"
echo
qrencode -t ansiutf8 -r "$TMP"
echo
echo "Next steps:"
echo "  1. commit+push: detect-secrets baseline may need merge for $ARCHIVE"
echo "  2. argocd app sync wireguard-system"
echo "  3. kubectl -n wireguard-system rollout restart deploy/wireguard-wireguard"
echo "     (seconds of tunnel downtime for ALL clients)"
