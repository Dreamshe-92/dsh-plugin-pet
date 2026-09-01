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
command -v sips >/dev/null || { echo "install: macOS sips is required for sprite conversion" >&2; exit 1; }
command -v python3 >/dev/null || echo "install: note — python3 not found, YAML checks will be skipped"
[[ -f "$SRC_DIR/lib/client.js.tpl" ]] || { echo "install: missing template" >&2; exit 1; }

# ── build the client bundle ───────────────────────────────────────────────
TARGET=""
if [[ "${1:-}" == "--pet" && -n "${2:-}" ]]; then TARGET="$2"; fi
if [[ -n "$TARGET" || ! -f "$SRC_DIR/lib/client.js" ]]; then
  if [[ -z "$TARGET" ]]; then
    FIRST=$(ls "$HOME"/.codex/pets/*/spritesheet.webp 2>/dev/null | head -1 || true)
    if [[ -z "$FIRST" ]]; then
      echo "install: no pet found under ~/.codex/pets/ — pass --pet <name-or-path> or create one first (see README)" >&2
      exit 1
    fi
    TARGET="$(basename "$(dirname "$FIRST")")"
    echo "install: auto-selected pet [$TARGET]"
  fi
  node "$ROOT/tools/build_client.js" "$TARGET"
fi

# ── link into the shared hoisted node_modules ─────────────────────────────
mkdir -p "$SHARED_NM"
rm -rf "$SHARED_NM/dsh-plugin-pet"
ln -s "$SRC_DIR" "$SHARED_NM/dsh-plugin-pet"
echo "linked: $SHARED_NM/dsh-plugin-pet -> $SRC_DIR"

# ── patch each DSH profile (YAML-safe text surgery) ───────────────────────
python3 - <<'PYEOF'
import pathlib, re

PET_BLOCK = [
    '# dsh-plugin-pet: session-state pet avatar in the sidebar footer.',
    '- insert:',
    '    - id: pet',
    '      name: dsh-plugin-pet',
]

def clean(text):
    text = re.sub(
        r"^# dsh-plugin-pet:[^\n]*\n(?:-{1}\s*insert:[^\n]*\n(?:[ \t]+-[^\n]*\n|[ \t]+[A-Za-z_]+:[^\n]*\n){0,4})?",
        "", text, flags=re.M)
    body = re.sub(r"^\[\]\s*$", "", text, flags=re.M)
    return body

for profile in ('desktop', 'web'):
    path = pathlib.Path.home() / '.dsh' / 'profiles' / profile / 'cordis.patch.yml'
    if not path.exists():
        print(f'{profile}: no patch file, skipped')
        continue
    original = path.read_text()
    final = clean(original).rstrip() + '\n' + '\n'.join(PET_BLOCK) + '\n'
    if final != original:
        path.write_text(final)
        print(f'{profile}: patch rewritten (pet row present, YAML-valid)')
    else:
        print(f'{profile}: patch already correct')
PYEOF

# ── YAML sanity gate (needs PyYAML; skipped when absent) ──────────────────
python3 - <<'PYEOF'
import pathlib, sys
try:
    import yaml
except ImportError:
    print('note: PyYAML not installed; skipped YAML sanity check')
    sys.exit(0)
ok = True
for profile in ('desktop', 'web'):
    p = pathlib.Path.home() / '.dsh' / 'profiles' / profile / 'cordis.patch.yml'
    if not p.exists():
        continue
    try:
        data = yaml.safe_load(p.read_text())
        assert isinstance(data, list)
        print(f'{profile}: YAML OK ({len(data)} top-level entries)')
    except Exception as e:
        ok = False
        print(f'{profile}: YAML INVALID: {e}')
sys.exit(0 if ok else 1)
PYEOF

echo "done. next: fully quit DSH Desktop (Cmd+Q) and reopen it"
