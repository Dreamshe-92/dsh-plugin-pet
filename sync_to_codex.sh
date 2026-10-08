#!/usr/bin/env bash
# sync_to_codex.sh — copy the bundled pets into the local Codex pets
# directory (~/.codex/pets/<name>/{pet.json, spritesheet.webp}).
#
# Usage:
#   bash sync_to_codex.sh            # copy pets that are missing or changed
#   bash sync_to_codex.sh --force    # overwrite even if identical
#
# previews/ are NOT copied: the Codex pet contract expects exactly
# pet.json + spritesheet.webp. Existing pets are preserved unless changed
# (or --force). boostr or other pre-existing pets are never touched.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.codex/pets"
FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1

mkdir -p "$DEST"

ADDED=0; UPDATED=0; SKIPPED=0
for SRC in "$ROOT"/pets/*/; do
  NAME="$(basename "$SRC")"
  [[ -f "$SRC/pet.json" && -f "$SRC/spritesheet.webp" ]] || continue
  TARGET="$DEST/$NAME"
  if [[ -d "$TARGET" && -f "$TARGET/spritesheet.webp" ]]; then
    if [[ "$FORCE" == 1 ]] || ! cmp -s "$SRC/spritesheet.webp" "$TARGET/spritesheet.webp"; then
      cp "$SRC/pet.json" "$TARGET/pet.json"
      cp "$SRC/spritesheet.webp" "$TARGET/spritesheet.webp"
      echo "updated : $NAME"
      UPDATED=$((UPDATED+1))
    else
      echo "skip    : $NAME (identical)"
      SKIPPED=$((SKIPPED+1))
    fi
  else
    mkdir -p "$TARGET"
    cp "$SRC/pet.json" "$TARGET/pet.json"
    cp "$SRC/spritesheet.webp" "$TARGET/spritesheet.webp"
    echo "added   : $NAME"
    ADDED=$((ADDED+1))
  fi
done

echo
echo "codex pets now available ($HOME/.codex/pets):"
ls "$DEST"
echo
echo "select one in the Codex app pet picker, or set in ~/.codex/config.toml:"
echo "  [desktop]"
echo "  selected-avatar-id = \"custom:<name>\""
