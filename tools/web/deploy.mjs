// The web demo onto Vercel (project cursed-camp-demo in team UNDO Collective,
// https://cursed-camp-demo.vercel.app). Vercel can not build Godot: the finished export goes up.
//   1. the release export, locked to the UNDO.games catalogue (node tools/web/export.mjs --release),
//   2. build/release: the engine and the game's data under /assets/ with a print of their content in
//      the name (/assets/index.<hash>.wasm, .pck, .js, the audio worklets), index.html pointing at
//      them; the page keeps them in the browser itself (web/undo-offline-godot.js, the UNDO.games kit),
//      so a player downloads the 300 MB once per version (undogames docs: OFFLINE_GAMES.md); at the
//      old worker's address (/undo-offline-sw.js) the kit's empty worker that unregisters itself;
//      web/vercel.json (frame-ancestors, noindex, /assets/ cached for a year); no .br (Vercel
//      compresses itself),
//      Beside the engine the shader programs for the page's precompile (build/web/shaders.json from
//      tools/web/record-shaders.mjs, in chunks assets/shaders.<hash>.<n>.json, their addresses in
//      window.__undoShaders, web/shader-warm.js),
//   3. .vercel/project.json written by hand (vercel link would pull env files),
//   4. vercel deploy --prod and the live address checked.
// The catalogue points at this address: only on Richard's word once players are in.
//   node tools/web/deploy.mjs [--skip-export] [--stage-only]

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const WEB = path.join(ROOT, 'build/web');
const OUT = path.join(ROOT, 'build/release');
// The kit's empty worker at the old worker's address (16. 11.): browsers that registered that one swap it and it
// unregisters itself. The page keeps the data itself now (web/undo-offline-godot.js).
const KIT_WORKER = `${process.env.UNDO_OFFLINE_KIT || 'C:/grimroot/undogames/docs/offline-kit'}/undo-offline-sw-retire.js`;
const PROJECT = { projectId: 'prj_N7WT2rOrN5qkb1RbTponm7Ozbw4Z', orgId: 'team_cgugJ8lxk1eNvjsulOTv8OZ3', projectName: 'cursed-camp-demo' };
const LIVE = 'https://cursed-camp-demo.vercel.app';
const ENGINE = ['js', 'wasm', 'pck', 'audio.worklet.js', 'audio.position.worklet.js'];

if (!process.argv.includes('--skip-export')) {
  execFileSync(process.execPath, [path.join(ROOT, 'tools/web/export.mjs'), '--release'], { stdio: 'inherit' });
}
let html = fs.readFileSync(path.join(WEB, 'index.html'), 'utf8');
if (!html.includes('__undoLocked')) throw new Error('build/web is not the release (no UNDO lock): node tools/web/export.mjs --release');
// The shader programs from a playthrough of this very build (web/shader-warm.js).
const SHADERS = path.join(WEB, 'shaders.json');
if (!fs.existsSync(SHADERS) || fs.statSync(SHADERS).mtimeMs < fs.statSync(path.join(WEB, 'index.pck')).mtimeMs) {
  throw new Error('build/web/shaders.json missing or older than the build: node tools/web/record-shaders.mjs');
}

// One print for the whole set: the engine's files belong together.
const hash = createHash('sha256');
for (const ext of ENGINE) hash.update(fs.readFileSync(path.join(WEB, `index.${ext}`)));
const stamp = hash.digest('hex').slice(0, 12);
const base = `assets/index.${stamp}`;

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(path.join(OUT, 'assets'), { recursive: true });
fs.mkdirSync(path.join(OUT, '.vercel'), { recursive: true });
for (const ext of ENGINE) fs.copyFileSync(path.join(WEB, `index.${ext}`), path.join(OUT, `${base}.${ext}`));
for (const name of fs.readdirSync(WEB)) {
  if (name.endsWith('.br') || name === 'index.html' || name === 'shaders.json' || /^index_/.test(name) || ENGINE.some((ext) => name === `index.${ext}`)) continue;
  if (fs.statSync(path.join(WEB, name)).isDirectory()) continue;
  fs.copyFileSync(path.join(WEB, name), path.join(OUT, name));
}
// The long tracks the browser plays (tools/web/export.mjs, web/long-tracks.json): their names carry their print.
if (fs.existsSync(path.join(WEB, 'assets/audio'))) fs.cpSync(path.join(WEB, 'assets/audio'), path.join(OUT, 'assets/audio'), { recursive: true });
fs.copyFileSync(KIT_WORKER, path.join(OUT, 'undo-offline-sw.js'));
// The list in chunks of CHUNK programs, each with the texts it uses: the page parses one at a time (80 MB at once
// would stop it); in the order of the recording, so the programs the game needs first come first.
const CHUNK = 48;
const capture = JSON.parse(fs.readFileSync(SHADERS, 'utf8'));
const shaderHash = createHash('sha256').update(fs.readFileSync(SHADERS)).digest('hex').slice(0, 12);
const shaderFiles = [];
for (let at = 0; at < capture.programs.length; at += CHUNK) {
  const texts = [], index = new Map();
  const id = (i) => { if (!index.has(i)) { index.set(i, texts.length); texts.push(capture.texts[i] ?? ''); } return index.get(i); };
  const programs = capture.programs.slice(at, at + CHUNK).map(([vs, fs_, binds, tf]) => [id(vs), id(fs_), binds, tf]);
  const file = `assets/shaders.${shaderHash}.${shaderFiles.length}.json`;
  fs.writeFileSync(path.join(OUT, file), JSON.stringify({ texts, programs }));
  shaderFiles.push(file);
}
// The index of the whole list (a print of each program's two texts -> its place), so the page knows where the game
// is in the list before it has read the chunk (the same print as web/shader-warm.js `key`).
const print = (vs, fs_) => {
  let h = 2166136261;
  for (const t of [vs, fs_]) for (let i = 0; i < t.length; i += 7) h = Math.imul(h ^ t.charCodeAt(i), 16777619);
  return `${vs.length}:${fs_.length}:${h >>> 0}`;
};
const keysFile = `assets/shaders.${shaderHash}.keys.json`;
fs.writeFileSync(path.join(OUT, keysFile), JSON.stringify(capture.programs.map(([vs, fs_]) => print(capture.texts[vs] ?? '', capture.texts[fs_] ?? ''))));

// The page: its script and the engine's config at the printed names.
const match = html.match(/const GODOT_CONFIG = (.*);\r?\n/);
const config = JSON.parse(match[1]);
config.executable = base;
config.fileSizes = Object.fromEntries(Object.entries(config.fileSizes).map(([name, size]) => [name.replace(/^index\./, `${base}.`), size]));
html = html.replace(match[0], () => `window.__undoShaders = ${JSON.stringify(shaderFiles)};\nwindow.__undoShaderKeys = ${JSON.stringify(keysFile)};\nwindow.__undoShadersTotal = ${capture.programs.length};\nconst GODOT_CONFIG = ${JSON.stringify(config)};\n`);
html = html.replace('<script src="index.js"></script>', `<script src="${base}.js"></script>`);
if (!html.includes(`${base}.js`)) throw new Error('the page has no engine script to point at');
fs.writeFileSync(path.join(OUT, 'index.html'), html);
fs.copyFileSync(path.join(ROOT, 'web/vercel.json'), path.join(OUT, 'vercel.json'));
fs.writeFileSync(path.join(OUT, '.vercel/project.json'), JSON.stringify(PROJECT));
console.log(`staged build/release, version ${stamp}, ${capture.programs.length} shader programs in ${shaderFiles.length} chunks`);
if (process.argv.includes('--stage-only')) process.exit(0);

execFileSync('vercel', ['deploy', '--prod', '--yes', '--scope', 'undocollective'], { cwd: OUT, stdio: 'inherit', shell: process.platform === 'win32' });

// The address switches to the new deployment a little after `vercel deploy`: tried for a minute.
let live = '';
let pck = null;
for (let i = 0; i < 20; i++) {
  live = await (await fetch(`${LIVE}/index.html?check=${Date.now()}`, { cache: 'no-store' })).text();
  pck = await fetch(`${LIVE}/${base}.pck`, { method: 'HEAD' });
  if (live === html && pck.ok) break;
  await new Promise((resolve) => setTimeout(resolve, 3000));
}
const ok = live === html && pck.ok;
console.log(`${LIVE}: index.html ${live === html ? 'new' : 'OLD'}, ${base}.pck ${pck.status} ${pck.headers.get('cache-control')}, ${ok ? 'deployed' : 'NOT VERIFIED'}`);
if (!ok) process.exit(1);
