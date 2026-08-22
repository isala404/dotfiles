#!/usr/bin/env bash
set -euo pipefail

SECRET_REF="${1:-}"
if [[ "$SECRET_REF" != secret://*/*/* ]]; then
  echo "usage: $0 secret://BACKEND/VAULT/SECRET_ID" >&2
  exit 2
fi

"@secretctl@" reveal "$SECRET_REF" | /usr/bin/python3 -c '
import json
import sys

fields = dict(field.split("=", 1) for field in sys.stdin.read().split())
print(json.dumps({
    "Version": 1,
    "AccessKeyId": fields["AccessKeyId"],
    "SecretAccessKey": fields["SecretAccessKey"],
}))
'
