#!/usr/bin/env bash
# uninstall.sh — remove dsh-plugin-pet from DSH Desktop.
# Restart DSH Desktop (Cmd+Q -> reopen) afterwards to fully unload it.
set -euo pipefail

SHARED_NM="$HOME/.dsh/profiles/node_modules"

rm -rf "$SHARED_NM/dsh-plugin-pet"
echo "unlinked: $SHARED_NM/dsh-plugin-pet"

python3 - <<'PYEOF'
import pathlib, re

def clean(text):
    text = re.sub(
        r"^# dsh-plugin-pet:[^\n]*\n(?:-{1}\s*insert:[^\n]*\n(?:[ \t]+-[^\n]*\n|[ \t]+[A-Za-z_]+:[^\n]*\n){0,4})?",
        "", text, flags=re.M)
    return text

def only_comments(text):
    return all(line.lstrip().startswith('#') or not line.strip() for line in text.splitlines())

for profile in ('desktop', 'web'):
    path = pathlib.Path.home() / '.dsh' / 'profiles' / profile / 'cordis.patch.yml'
    if not path.exists():
        continue
    original = path.read_text()
    cleaned = clean(original)
    if cleaned != original:
        # restore the empty-list document when nothing but comments remains
        if only_comments(cleaned):
            cleaned = '\n'.join(l for l in cleaned.splitlines() if l.strip()) + '\n[]\n'
        path.write_text(cleaned)
        print(f'{profile}: pet block removed')
    else:
        print(f'{profile}: nothing to remove')
PYEOF

echo "done. next: fully quit DSH Desktop (Cmd+Q) and reopen it"
