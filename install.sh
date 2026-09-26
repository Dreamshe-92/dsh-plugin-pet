#!/usr/bin/env bash
# install.sh — install dsh-plugin-pet into DSH Desktop.
#
# Usage:
#   bash install.sh                 # auto-pick the first pet in ~/.codex/pets
#   bash install.sh --pet xiaowa    # pick a specific pet (name or path)
#
# Idempotent. Restart DSH Desktop (Cmd+Q -> reopen) afterwards to load it.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$ROOT/pet-plugin"
SHARED_NM="$HOME/.dsh/profiles/node_modules"

# ── dependencies ──────────────────────────────────────────────────────────
command -v node >/dev/null || { echo "install: node is required" >&2; exit 1; }
[[ -f "$SRC_DIR/lib/client.js.tpl" ]] || { echo "install: missing template" >&2; exit 1; }

# ── build the client bundle ───────────────────────────────────────────────
TARGET=""
if [[ "${1:-}" == "--pet" && -n "${2:-}" ]]; then TARGET="$2"; fi
if [[ -n "$TARGET" || ! -f "$SRC_DIR/lib/client.js" ]]; then
  if [[ -z "$TARGET" ]]; then
    FIRST=$(ls "$HOME"/.codex/pets/*/spritesheet.webp 2>/dev/null | head -1 || true)
    if [[ -z "$FIRST" ]]; then
      FIRST=$(ls "$ROOT"/pets/*/spritesheet.webp 2>/dev/null | head -1 || true)
    fi
    if [[ -z "$FIRST" ]]; then
      echo "install: no pet found under ~/.codex/pets/ or ./pets/ — pass --pet <name-or-path> (see README)" >&2
      exit 1
    fi
    TARGET="$(basename "$(dirname "$FIRST")")"
    echo "install: auto-selected pet [$TARGET]"
  fi
  node "$ROOT/tools/build_client.js" "$TARGET"
fi

# link + patch + validate (node, cross-platform)
node "$ROOT/tools/patch_profiles.js" link "$SRC_DIR"
node "$ROOT/tools/patch_profiles.js" patch

echo "done. next: fully quit DSH Desktop (Cmd+Q) and reopen it"
