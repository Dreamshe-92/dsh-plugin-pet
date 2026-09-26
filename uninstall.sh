#!/usr/bin/env bash
# uninstall.sh — remove dsh-plugin-pet from DSH Desktop.
# Restart DSH Desktop (Cmd+Q -> reopen) afterwards to fully unload it.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node "$ROOT/tools/patch_profiles.js" unlink
node "$ROOT/tools/patch_profiles.js" unpatch

echo "done. next: fully quit DSH Desktop (Cmd+Q) and reopen it"
