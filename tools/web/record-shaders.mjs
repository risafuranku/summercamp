// The list of shader programs for the page's precompile (web/shader-warm.js): build/web played in a muted headless
// Chromium through the boot, the warden card, the guest book, a new camp (the stamp), the camp at the PC and a short
// walk outside, every linked program's sources kept in the order the game first needs them (tools/web/qa.mjs
// --capture). Output build/web/shaders.json; tools/web/deploy.mjs refuses to deploy without a fresh one.
// ANGLE on Vulkan boots in ~40 s instead of minutes: Godot's sources are the same (17. 11.: the 376 programs to the
// title on D3D11 all in the Vulkan list). The clicks go by the clock: on a much slower machine look at the shots.
//   node tools/web/record-shaders.mjs [--port=5399]

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const port = (process.argv.find((a) => a.startsWith('--port=')) || '--port=5399').slice(7);
const out = path.join(ROOT, 'build/qa-shaders');
const list = path.join(ROOT, 'build/web/shaders.json');
// The warden's name, DONE, NEW CAMP, the stamp; out of the PC and a few steps in the camp.
const steps = '66:click:470,236;67:type:Tester;70:click:958,538;78:click:898,477;84:click:880,410;'
  + '140:key:Escape;145:down:w;152:up:w;153:down:d;156:up:d;157:down:w;163:up:w';
execFileSync(process.execPath, [path.join(ROOT, 'tools/web/qa.mjs'), `--port=${port}`, '--angle=vulkan', `--out=${out}`, '--seconds=215',
  '--shots=88,150,212', '--gl=1', `--capture=${list}`, `--do=${steps}`], { stdio: 'inherit' });
const { programs } = JSON.parse(fs.readFileSync(list, 'utf8'));
console.log(`build/web/shaders.json: ${programs.length} programs; shots in build/qa-shaders (t212 must be the camp)`);
