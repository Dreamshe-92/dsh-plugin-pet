#!/usr/bin/env node
// build_client.js — resolve a pet sprite, measure its grid, and render
// pet-plugin/lib/client.js from the template. Shared by install.sh and
// switch_pet.sh so there is exactly one build path.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const target = args[0];
if (!target) { console.error('usage: build_client.js <pet-name|image-path|dir> [options]'); process.exit(2); }
function opt(name, fallback) { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; }
const petsDir = opt('--pets-dir', path.join(os.homedir(), '.codex', 'pets'));
const tplPath = opt('--tpl', path.join(ROOT, 'pet-plugin', 'lib', 'client.js.tpl'));
const outPath = opt('--out', path.join(ROOT, 'pet-plugin', 'lib', 'client.js'));
const gridArgs = [];
for (const flag of ['--cols', '--rows', '--size']) {
  const i = args.indexOf(flag);
  if (i >= 0) gridArgs.push(flag, args[i + 1]);
}

function resolveImage(t) {
  if (fs.existsSync(t) && fs.statSync(t).isFile()) return t;
  if (fs.existsSync(t) && fs.statSync(t).isDirectory()) {
    for (const name of ['spritesheet.webp', 'spritesheet.png', 'spritesheet.jpg']) {
      const c = path.join(t, name);
      if (fs.existsSync(c)) return c;
    }
    throw new Error('no spritesheet.* in ' + t);
  }
  if (fs.existsSync(petsDir)) {
    for (const entry of fs.readdirSync(petsDir).sort()) {
      if (!entry.toLowerCase().includes(t.toLowerCase())) continue;
      for (const name of ['spritesheet.webp', 'spritesheet.png', 'spritesheet.jpg']) {
        const c = path.join(petsDir, entry, name);
        if (fs.existsSync(c)) return c;
      }
    }
  }
  throw new Error('no pet matching [' + t + '] under ' + petsDir);
}
const img = resolveImage(target);

const png = path.join(os.tmpdir(), 'dsh_pet_sheet_' + process.pid + '.png');
const conv = spawnSync('sips', ['-s', 'format', 'png', img, '--out', png], { stdio: 'pipe' });
if (conv.status !== 0) throw new Error('PNG conversion failed (needs macOS sips, or convert the sheet to PNG first): ' + (conv.stderr || '').toString().slice(0, 200));

const measured = spawnSync(process.execPath, [path.join(ROOT, 'tools', 'measure_sheet.js'), png].concat(gridArgs), {
  stdio: ['ignore', 'pipe', 'inherit'],
});
if (measured.status !== 0) throw new Error('measure_sheet.js failed');
const m = JSON.parse(measured.stdout.toString());
console.log('sprite : ' + img);
console.log('grid   : ' + m.cols + 'x' + m.rows + ' cells ' + m.cellW + 'x' + m.cellH + ' (' + m.note + ')');
console.log('display: ' + m.displayW + 'x' + m.displayH);

let petName = 'Pet';
const manifest = path.join(path.dirname(img), 'pet.json');
if (fs.existsSync(manifest)) {
  try { petName = JSON.parse(fs.readFileSync(manifest, 'utf8')).displayName || petName; } catch {}
}
console.log('pet    : ' + petName);

const payload = fs.readFileSync(img).toString('base64');
const tpl = fs.readFileSync(tplPath, 'utf8');
const substitutions = {
  __PET_SPRITE_B64__: payload,
  __PET_SHEET__: m.sheet,
  __PET_NAME__: petName,
  __PET_MODE__: m.mode,
  __PET_ROW_ANIM__: m.rowAnim,
};
let out = tpl;
for (const token of Object.keys(substitutions)) {
  if (!out.includes(token)) throw new Error('template missing placeholder ' + token);
  out = out.split(token).join(substitutions[token]);
}
for (const token of Object.keys(substitutions)) {
  if (out.includes(token)) throw new Error('unfilled placeholder ' + token);
}
fs.writeFileSync(outPath, out);

const check = spawnSync(process.execPath, ['--check', outPath], { stdio: 'inherit' });
if (check.status !== 0) throw new Error('generated client.js failed node --check');

const probeScript = [
  "const fs = require('fs');",
  "const src = fs.readFileSync(" + JSON.stringify(outPath) + ", 'utf8');",
  "const start = src.indexOf('const css = ');",
  "const end = src.indexOf('\\n', start);",
  "const expr = src.slice(start + 'const css = '.length, end).replace(/;$/, '');",
  "const SHEET = " + m.sheet + ";",
  "const SPRITE_URL = 'data:image/webp;base64,PROBE';",
  "const css = Function('SHEET', 'SPRITE_URL', 'return (' + expr + ')')(SHEET, SPRITE_URL);",
  "const q = String.fromCharCode(39);",
  "if (!css.includes('url(' + q + SPRITE_URL + q + ')')) { console.error('css url is not a real concatenation'); process.exit(1); }",
].join(String.fromCharCode(10));
const probeFile = path.join(os.tmpdir(), 'dsh_pet_css_probe_' + process.pid + '.js');
fs.writeFileSync(probeFile, probeScript);
const cssProbe = spawnSync(process.execPath, [probeFile], { stdio: 'inherit' });
fs.unlinkSync(probeFile);
if (cssProbe.status !== 0) throw new Error('generated css failed the runtime url gate');

fs.unlinkSync(png);
console.log('built   : ' + outPath + ' (' + out.length + ' bytes, mode=' + m.mode + ')');
