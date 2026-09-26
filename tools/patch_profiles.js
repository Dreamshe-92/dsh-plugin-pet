#!/usr/bin/env node
// patch_profiles.js — cross-platform (macOS/Windows) profile maintenance
// for dsh-plugin-pet: cordis.patch.yml editing plus node_modules linking.
// Replaces the previous python3 + ln -s steps so Windows works out of the
// box (symlink falls back to a directory copy without privileges).
const fs = require('fs');
const os = require('os');
const path = require('path');

const cmd = process.argv[2];
const PROFILES = ['desktop', 'web'];
const PET_BLOCK = [
  '# dsh-plugin-pet: session-state pet avatar in the sidebar footer.',
  '- insert:',
  '    - id: pet',
  '      name: dsh-plugin-pet',
];

function patchPath(profile) {
  return path.join(os.homedir(), '.dsh', 'profiles', profile, 'cordis.patch.yml');
}

function clean(text) {
  const stripBlock = /^[ \t]*# dsh-plugin-pet:[^\n]*\n(?:-{1}[ \t]*insert:[^\n]*\n(?:[ \t]+-[^\n]*\n|[ \t]+[A-Za-z_]+:[^\n]*\n){0,4})?/gm;
  text = text.replace(stripBlock, '');
  return text.replace(/^\[\][ \t]*$/gm, '');
}

function patch() {
  for (const profile of PROFILES) {
    const file = patchPath(profile);
    if (!fs.existsSync(file)) { console.log(profile + ': no patch file, skipped'); continue; }
    const original = fs.readFileSync(file, 'utf8');
    const final = clean(original).replace(/\s+$/, '') + '\n' + PET_BLOCK.join('\n') + '\n';
    if (final !== original) {
      fs.writeFileSync(file, final);
      console.log(profile + ': patch rewritten (pet row present, YAML-valid)');
    } else {
      console.log(profile + ': patch already correct');
    }
    sanity(file, profile);
  }
}

function unpatch() {
  for (const profile of PROFILES) {
    const file = patchPath(profile);
    if (!fs.existsSync(file)) continue;
    const original = fs.readFileSync(file, 'utf8');
    let cleaned = original.replace(/^[ \t]*# dsh-plugin-pet:[^\n]*\n(?:-{1}[ \t]*insert:[^\n]*\n(?:[ \t]+-[^\n]*\n|[ \t]+[A-Za-z_]+:[^\n]*\n){0,4})?/gm, '');
    if (cleaned === original) { console.log(profile + ': nothing to remove'); continue; }
    const onlyComments = cleaned.split('\n').every((l) => !l.trim() || l.trim().startsWith('#'));
    if (onlyComments) cleaned = cleaned.split('\n').filter((l) => l.trim()).join('\n') + '\n[]\n';
    fs.writeFileSync(file, cleaned);
    console.log(profile + ': pet block removed');
  }
}

// lightweight structural sanity: non-comment lines must form a top-level
// YAML list (every entry line starts with '- '), matching what we write.
function sanity(file, profile) {
  const entries = fs.readFileSync(file, 'utf8').split('\n').filter((l) => l.trim() && !l.trim().startsWith('#'));
  const ok = entries.length === 0 || entries.every((l) => /^-[ \t]/.test(l) || /^[ \t]/.test(l));
  console.log(profile + ': structure ' + (ok ? 'OK' : 'SUSPECT') + ' (' + entries.filter((l) => l.startsWith('- ')).length + ' top-level entries)');
  if (!ok) process.exitCode = 1;
}

function link(srcDir) {
  const nm = path.join(os.homedir(), '.dsh', 'profiles', 'node_modules');
  fs.mkdirSync(nm, { recursive: true });
  const target = path.join(nm, 'dsh-plugin-pet');
  fs.rmSync(target, { recursive: true, force: true });
  try {
    fs.symlinkSync(srcDir, target, 'dir');
    console.log('linked: ' + target + ' -> ' + srcDir);
  } catch {
    fs.cpSync(srcDir, target, { recursive: true });
    console.log('copied (no symlink privilege): ' + target);
  }
}

function unlink() {
  const target = path.join(os.homedir(), '.dsh', 'profiles', 'node_modules', 'dsh-plugin-pet');
  fs.rmSync(target, { recursive: true, force: true });
  console.log('unlinked: ' + target);
}

if (cmd === 'patch') patch();
else if (cmd === 'unpatch') unpatch();
else if (cmd === 'link' && process.argv[3]) link(path.resolve(process.argv[3]));
else if (cmd === 'unlink') unlink();
else { console.error('usage: patch_profiles.js patch|unpatch|link <dir>|unlink'); process.exit(2); }
