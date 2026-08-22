#!/usr/bin/env bash
set -euo pipefail

SECRET_REF="${1:-}"
if [[ "$SECRET_REF" != secret://*/*/* ]]; then
  echo "usage: $0 secret://BACKEND/VAULT/SECRET_ID" >&2
  exit 2
fi

"@secretctl@" reveal "$SECRET_REF" | /usr/bin/python3 -c '
import sys, json, base64
config = json.load(sys.stdin)
user = config["users"][0]["user"]
print(json.dumps({
    "apiVersion": "client.authentication.k8s.io/v1beta1",
    "kind": "ExecCredential",
    "status": {
        "clientCertificateData": base64.b64decode(user["client-certificate-data"]).decode(),
        "clientKeyData": base64.b64decode(user["client-key-data"]).decode()
    }
}))
'
