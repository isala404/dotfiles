#!/usr/bin/env bash
set -euo pipefail

SECRET_ID="$1"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bws"
CACHE_FILE="$CACHE_DIR/kube-$SECRET_ID"
CACHE_IDLE_TIMEOUT="${BWS_CACHE_IDLE_TIMEOUT_SECONDS:-3600}"

if [[ ! "$CACHE_IDLE_TIMEOUT" =~ ^[0-9]+$ ]] || (( 10#$CACHE_IDLE_TIMEOUT <= 0 )); then
  echo "BWS_CACHE_IDLE_TIMEOUT_SECONDS must be a positive integer" >&2
  exit 1
fi
CACHE_IDLE_TIMEOUT=$(( 10#$CACHE_IDLE_TIMEOUT ))

mkdir -p "$CACHE_DIR"

if [[ -f "$CACHE_FILE" ]]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  if (( age < CACHE_IDLE_TIMEOUT )); then
    touch "$CACHE_FILE"
    cat "$CACHE_FILE"
    exit 0
  fi
fi

export BWS_ACCESS_TOKEN=$("$HOME/.local/bin/keychain-bio" get bws-access-token)
RAW=$(bws secret get "$SECRET_ID" -o json)

OUTPUT=$(/usr/bin/python3 -c "
import sys, json, base64
secret = json.loads(sys.stdin.read())
config = json.loads(secret['value'])
user = config['users'][0]['user']
print(json.dumps({
    'apiVersion': 'client.authentication.k8s.io/v1beta1',
    'kind': 'ExecCredential',
    'status': {
        'clientCertificateData': base64.b64decode(user['client-certificate-data']).decode(),
        'clientKeyData': base64.b64decode(user['client-key-data']).decode()
    }
}))
" <<< "$RAW")

echo "$OUTPUT" > "$CACHE_FILE"
chmod 600 "$CACHE_FILE"
echo "$OUTPUT"
