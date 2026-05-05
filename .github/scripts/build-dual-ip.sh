#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MODULES=(
  extensions/dual-ip/00-env-utils.sh
  extensions/dual-ip/01-read-existing.sh
  extensions/dual-ip/02-server-config.sh
  extensions/dual-ip/03-client-config.sh
  extensions/dual-ip/04-subscription-output.sh
)

build_one() {
  local output="$1"
  local tmp module

  tmp="$(mktemp)"
  cat > "$tmp" <<'SCRIPTHEADER'
#!/bin/bash
set -e
SCRIPTHEADER

  for module in "${MODULES[@]}"; do
    cat "$ROOT_DIR/$module" >> "$tmp"
    printf '\n' >> "$tmp"
  done

  mv "$tmp" "$output"
  chmod +x "$output"
}

OUT_DIR="${OUT_DIR:-$ROOT_DIR/dist}"
mkdir -p "$OUT_DIR"

build_one "$OUT_DIR/add-dual-ip.sh"

echo "Generated $OUT_DIR/add-dual-ip.sh"
