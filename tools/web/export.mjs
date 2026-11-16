// The web export: the page (web/shell.src.html with the UNDO bridge, gl-skip and, for UNDO.games,
// the lock), Godot's Web preset into build/web, the page's pictures and the splash beside it, the long
// tracks (web/long-tracks.json) under assets/audio/, everything brotli'd (the host sends the .br).
//   node tools/web/export.mjs [--release] [--debug]
// --release: the build for UNDO.games, locked to its catalogue (web/undo-lock.js); without it the
// test build (the phone and PC test server, tools/web/publish.mjs).

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const GODOT = process.env.GODOT_EXE || 'C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe';
const OUT = path.join(ROOT, 'build/web');
const WEB = path.join(ROOT, 'web');
const release = process.argv.includes('--release');
const debug = process.argv.includes('--debug');
const read = (name) => fs.readFileSync(path.join(WEB, name), 'utf8');

// Long tracks (web/long-tracks.json): the browser plays them off the engine's thread (web/stream-audio.js,
// godot/scripts/audio/long_player.gd), so they stay out of the game's pack (the Web preset's exclude_filter,
// kept in step here) and go beside it as assets/audio/<name>-<print>.<ext>; window.__ccAudio maps their
// res:// paths to those files.
const LONG = JSON.parse(read('long-tracks.json')).tracks;
const audio = Object.fromEntries(LONG.map((res) => {
  const file = path.join(ROOT, 'godot', res.slice('res://'.length));
  const print = createHash('sha256').update(fs.readFileSync(file)).digest('hex').slice(0, 10);
  const ext = path.extname(file);
  return [res, `assets/audio/${path.basename(file, ext)}-${print}${ext}`];
}));
const PRESETS = path.join(ROOT, 'godot/export_presets.cfg');
{
  const cfg = fs.readFileSync(PRESETS, 'utf8');
  const web = cfg.indexOf('name="Web"');
  const line = cfg.slice(web).match(/\nexclude_filter="([^"]*)"/);
  const kept = line[1].split(',').map((x) => x.trim()).filter((x) => x && !x.startsWith('assets/'));
  const want = `exclude_filter="${kept.concat(LONG.map((res) => res.slice('res://'.length))).join(', ')}"`;
  if (line[0].trim() !== want) {
    const at = web + line.index;
    fs.writeFileSync(PRESETS, cfg.slice(0, at) + '\n' + want + cfg.slice(at + line[0].length));
  }
}
const copyAudio = () => {
  for (const [res, file] of Object.entries(audio)) {
    fs.mkdirSync(path.join(OUT, path.dirname(file)), { recursive: true });
    fs.copyFileSync(path.join(ROOT, 'godot', res.slice('res://'.length)), path.join(OUT, file));
  }
};

// The page Godot fills in ($GODOT_URL, $GODOT_CONFIG): a hidden file in the project, so Godot
// neither imports nor exports it (the preset's html/custom_html_shell).
const shell = read('shell.src.html')
  .replace('/*CC_AUDIO*/', () => `window.__ccAudio = ${JSON.stringify(audio)};
window.__ccAudioBytes = ${JSON.stringify(Object.fromEntries(Object.entries(audio).map(([res, url]) => [url, fs.statSync(path.join(ROOT, 'godot', res.slice('res://'.length))).size])))};`)
  .replace('/*STREAM_AUDIO*/', () => read('stream-audio.js'))
  .replace('/*UNDO_LOCK*/', () => (release ? read('undo-lock.js') : ''))
  .replace('/*UNDO_BRIDGE*/', () => read('undo-bridge.js'))
  .replace('/*GL_SKIP*/', () => read('gl-skip.js'))
  .replace('/*SHADER_WARM*/', () => read('shader-warm.js'))
  .replace('/*UNDO_OFFLINE*/', () => read('undo-offline-godot.js'));
fs.writeFileSync(path.join(ROOT, 'godot/.web_shell.html'), shell);

// --shell-only: the page alone again into the last export (its engine config kept), for
// working on the page without exporting the game.
if (process.argv.includes('--shell-only')) {
  const old = fs.readFileSync(path.join(OUT, 'index.html'), 'utf8');
  const config = old.match(/const GODOT_CONFIG = (.*);\r?\n/)[1];
  const page = shell.replace('$GODOT_URL', 'index.js').replace('$GODOT_CONFIG', () => config)
    .replace('$GODOT_THREADS_ENABLED', 'false').replace('$GODOT_HEAD_INCLUDE', '');
  fs.writeFileSync(path.join(OUT, 'index.html'), page);
  fs.writeFileSync(path.join(OUT, 'index.html.br'), zlib.brotliCompressSync(Buffer.from(page)));
  for (const name of ['splash.webm', 'splash.mp4', 'card_logo.png', 'phone_pc.png']) fs.copyFileSync(path.join(WEB, name), path.join(OUT, name));
  copyAudio();
  console.log('page only: build/web/index.html');
  process.exit(0);
}
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
const started = Date.now();
execFileSync(GODOT, ['--headless', '--audio-driver', 'Dummy', '--path', path.join(ROOT, 'godot'), debug ? '--export-debug' : '--export-release', 'Web', path.join(OUT, 'index.html')], { stdio: ['ignore', 'ignore', 'inherit'] });
for (const name of ['splash.webm', 'splash.mp4', 'card_logo.png', 'phone_pc.png']) fs.copyFileSync(path.join(WEB, name), path.join(OUT, name));
copyAudio();
let raw = 0, packed = 0;
for (const file of fs.readdirSync(OUT)) {
  if (!/\.(wasm|pck|js|html)$/.test(file)) continue;
  const data = fs.readFileSync(path.join(OUT, file));
  // The pack is mostly sound and pictures already compressed: a quick pass is as good.
  const quality = data.length > 50e6 ? 5 : data.length > 2e6 ? 9 : 11;
  const br = zlib.brotliCompressSync(data, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: quality, [zlib.constants.BROTLI_PARAM_SIZE_HINT]: data.length } });
  fs.writeFileSync(path.join(OUT, file + '.br'), br);
  raw += data.length; packed += br.length;
  console.log(`  ${file.padEnd(28)} ${(data.length / 1e6).toFixed(1).padStart(7)} MB  brotli ${(br.length / 1e6).toFixed(1).padStart(7)} MB`);
}
console.log(`web export${release ? ' (release, locked)' : ' (test)'}: ${(raw / 1e6).toFixed(1)} MB, brotli ${(packed / 1e6).toFixed(1)} MB, ${((Date.now() - started) / 1000).toFixed(0)} s`);
