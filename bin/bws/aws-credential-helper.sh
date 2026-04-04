#!/usr/bin/env bash
set -euo pipefail

SECRET_ID="$1"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bws"
CACHE_FILE="$CACHE_DIR/aws-$SECRET_ID"
CACHE_TTL=3600

mkdir -p "$CACHE_DIR"

if [[ -f "$CACHE_FILE" ]]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  if (( age < CACHE_TTL )); then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

export BWS_ACCESS_TOKEN=$("$HOME/.local/bin/keychain-bio" get bws-access-token)
RAW=$(bws secret get "$SECRET_ID" -o json)
VALUE=$(echo "$RAW" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin)['value'])")

ACCESS_KEY=$(echo "$VALUE" | tr ' ' '\n' | grep AccessKeyId | cut -d= -f2)
SECRET_KEY=$(echo "$VALUE" | tr ' ' '\n' | grep SecretAccessKey | cut -d= -f2)

OUTPUT=$(cat <<EOF
{
  "Version": 1,
  "AccessKeyId": "$ACCESS_KEY",
  "SecretAccessKey": "$SECRET_KEY"
}
EOF
)

echo "$OUTPUT" > "$CACHE_FILE"
chmod 600 "$CACHE_FILE"
echo "$OUTPUT"
