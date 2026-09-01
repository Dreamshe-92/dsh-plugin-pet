#!/usr/bin/env bash
# switch_pet.sh — swap the pet sprite and rebuild the client bundle.
#
# Usage:
#   bash switch_pet.sh <pet-name>            # match ~/.codex/pets/*<pet-name>*
#   bash switch_pet.sh /path/to/sheet.webp   # any transparent sprite grid
#   bash switch_pet.sh /path/to/dir          # dir containing spritesheet.*
#   optional: --cols N --rows N --size PX    # manual grid / size override
#
# HMR picks the rebuilt bundle up automatically; press Cmd+R in DSH Desktop.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec node "$ROOT/tools/build_client.js" "$@"
