#!/usr/bin/env node
// measure_sheet.js <image.png> [--cols N] [--rows N] [--size PX]
//
// Measures a transparent-background sprite grid by scanning the alpha channel
// for blank rows/columns, then prints JSON: {cols, rows, cellW, cellH,
// displayW, displayH, source}. Manual --cols/--rows override the scan (needed
// for opaque backgrounds, e.g. jpg, where no alpha gaps exist).
const fs = require('fs');
const zlib = require('zlib');

const args = process.argv.slice(2);
const image = args[0];
if (!image) { console.error('usage: measure_sheet.js <image.png> [--cols N] [--rows N] [--size PX]'); process.exit(2); }
function opt(name) { const i = args.indexOf(name); return i >= 0 ? Number(args[i + 1]) : undefined; }
const overrideCols = opt('--cols'), overrideRows = opt('--rows');
const maxSize = opt('--size') || 96;

// ── minimal PNG reader (8-bit RGBA only) ────────────────────────────────────
const data = fs.readFileSync(image);
if (data.readUInt32BE(0) !== 0x89504e47) { console.error('not a png (convert with sips first)'); process.exit(1); }
let pos = 8, width = 0, height = 0;
const idat = [];
while (pos < data.length) {
  const length = data.readUInt32BE(pos);
  const type = data.toString('ascii', pos + 4, pos + 8);
  const body = data.subarray(pos + 8, pos + 8 + length);
  if (type === 'IHDR') { width = body.readUInt32BE(0); height = body.readUInt32BE(4);
    if (body[8] !== 8 || body[9] !== 6) { console.error('expect 8-bit RGBA png (colortype 6)'); process.exit(1); } }
  else if (type === 'IDAT') idat.push(body);
  pos += 12 + length;
}
const raw = zlib.inflateSync(Buffer.concat(idat));
const bpp = 4, stride = width * bpp;
const out = new Uint8Array(width * height * bpp);
let prev = new Uint8Array(stride), p = 0;
for (let y = 0; y < height; y++) {
  const f = raw[p++]; const line = raw.subarray(p, p + stride); p += stride;
  const cur = out.subarray(y * stride, (y + 1) * stride);
  if (f === 0) cur.set(line);
  else if (f === 1) { cur.set(line); for (let i = bpp; i < stride; i++) cur[i] = (cur[i] + cur[i - bpp]) & 255; }
  else if (f === 2) { for (let i = 0; i < stride; i++) cur[i] = (line[i] + prev[i]) & 255; }
  else if (f === 3) { for (let i = 0; i < bpp; i++) cur[i] = (line[i] + (prev[i] >> 1)) & 255;
    for (let i = bpp; i < stride; i++) cur[i] = (line[i] + (((cur[i - bpp] + prev[i]) >> 1))) & 255; }
  else if (f === 4) { for (let i = 0; i < stride; i++) {
    const a = i >= bpp ? cur[i - bpp] : 0, b = prev[i], c = i >= bpp ? prev[i - bpp] : 0;
    const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c);
    cur[i] = (line[i] + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c)) & 255; } }
  else { console.error('bad filter ' + f); process.exit(1); }
  prev = cur;
}

// ── alpha occupancy scan ────────────────────────────────────────────────────
const THRESH = 16;
const colCounts = new Uint32Array(width), rowCounts = new Uint32Array(height);
for (let y = 0; y < height; y++) { const base = y * stride;
  for (let x = 0; x < width; x++) if (out[base + x * bpp + 3] > THRESH) { colCounts[x]++; rowCounts[y]++; } }

function contentRuns(counts, minGap = 2) {
  const runs = []; let start = -1, gap = 0;
  for (let i = 0; i < counts.length; i++) {
    if (counts[i] > 0) { if (start < 0) start = i; gap = 0; }
    else if (start >= 0) { if (++gap >= minGap) { runs.push([start, i - gap]); start = -1; gap = 0; } }
  }
  if (start >= 0) runs.push([start, counts.length - 1]);
  return runs;
}

function uniform(runs) {
  if (runs.length < 2) return false;
  const ws = runs.map(([a, b]) => b - a + 1);
  const mean = ws.reduce((s, w) => s + w, 0) / ws.length;
  const varr = ws.reduce((s, w) => s + (w - mean) ** 2, 0) / ws.length;
  return Math.sqrt(varr) / mean < 0.2;
}

const colRuns = contentRuns(colCounts), rowRuns = contentRuns(rowCounts);
let cols = overrideCols, rows = overrideRows, scanNote = 'manual';
if (!cols && !rows) {
  if (colRuns.length >= 1 && rowRuns.length >= 1 && uniform(colRuns) && uniform(rowRuns)) {
    cols = colRuns.length; rows = rowRuns.length; scanNote = 'alpha-scan';
  } else {
    // fallback: single static frame
    cols = 1; rows = 1; scanNote = 'fallback-single-frame (no uniform grid found; pass --cols/--rows)';
  }
}
cols = cols || 1; rows = rows || 1;
const cellW = Math.floor(width / cols), cellH = Math.floor(height / rows);
// scale so the longest display side is maxSize, aspect preserved
const scale = maxSize / Math.max(cellW, cellH);
const displayW = Math.max(1, Math.round(cellW * scale));
const displayH = Math.max(1, Math.round(cellH * scale));

// ── Codex pet contract detection (hatch-pet / codex-pet-contract) ───────────
// 1536x1872 atlas is BY CONTRACT an 8x9 grid of 192x208 cells with fixed
// animation-row semantics; trust the contract over the scan.
const CONTRACT_DIMS = width === 1536 && height === 1872;
let mode = 'simple';
if (CONTRACT_DIMS && !overrideCols && !overrideRows) { mode = 'contract'; cols = 8; rows = 9; scanNote = 'codex-pet-contract'; }

const CONTRACT_ROW_ANIM =
  'const ROW_ANIM = {' +
  ' sleep: { row: 0, cols: [0,1,2,3,4,5], durations: [840,330,330,420,420,960] },' +
  ' idle: { row: 0, cols: [0,1,2,3,4,5], durations: [280,110,110,140,140,320] },' +
  ' working: { row: 7, cols: [0,1,2,3,4,5], durations: [120,120,120,120,120,220] },' +
  ' waiting: { row: 6, cols: [0,1,2,3,4,5], durations: [150,150,150,150,150,260] },' +
  ' notify: { row: 4, cols: [0,1,2,3,4], durations: [140,140,140,140,280] },' +
  ' waving: { row: 3, cols: [0,1,2,3], durations: [140,140,140,280] },' +
  ' running_right: { row: 1, cols: [0,1,2,3,4,5,6,7], durations: [120,120,120,120,120,120,120,220] },' +
  ' running_left: { row: 2, cols: [0,1,2,3,4,5,6,7], durations: [120,120,120,120,120,120,120,220] }' +
  ' };';

console.log(JSON.stringify({ source: image, width, height, cols, rows, cellW, cellH,
  displayW, displayH, note: scanNote, mode,
  rowAnim: mode === 'contract' ? CONTRACT_ROW_ANIM : 'const ROW_ANIM = null;',
  scannedCols: colRuns.length, scannedRows: rowRuns.length,
  sheet: '{ cols: ' + cols + ', rows: ' + rows + ', displayW: ' + displayW + ', displayH: ' + displayH + ' };' }));
