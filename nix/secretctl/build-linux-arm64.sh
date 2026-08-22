#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output="${1:-${source_dir}/dist/secretctl-linux-arm64}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/secretctl-build.XXXXXX")"

cleanup() {
  rm -rf "$build_dir"
}
trap cleanup EXIT

mkdir -p "$(dirname "$output")"

cd "$source_dir"
ZIG_LOCAL_CACHE_DIR="$build_dir/zig-local" \
  ZIG_GLOBAL_CACHE_DIR="$build_dir/zig-global" \
  GOCACHE="$build_dir/go" \
  CGO_ENABLED=1 \
  GOOS=linux \
  GOARCH=arm64 \
  CC="zig cc -target aarch64-linux-musl" \
  go build \
    -trimpath \
    -ldflags '-s -w -linkmode external -extldflags "-static -lunwind"' \
    -o "$output" \
    ./cmd/secretctl

file "$output"
