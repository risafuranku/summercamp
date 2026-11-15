// The web export in a muted headless Chromium: the console (all of it), shots at given
// seconds, frames per second, clicks and keys at given seconds.
//   node tools/web/qa.mjs --out=DIR [--seconds=60] [--shots=20,40,60] [--size=1280x720]
//        [--do="30:click:640,360;34:key:Enter;40:type:Camp"] [--dir=build/web]

import { chromium } from 'file:///C:/grimroot/undocord/node_modules/playwright/index.mjs';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const args = Object.fromEntries(process.argv.slice(2).map((a) => { const [k, ...v] = a.replace(/^--/, '').split('='); return [k, v.join('=') || '1']; }));
const PORT = Number(args.port || 5397);
const CHROME = process.env.CHROME_EXE || path.join(process.env.LOCALAPPDATA, 'ms-playwright/chromium-1234/chrome-win64/chrome.exe');
const out = path.resolve(args.out || path.join(ROOT, 'build/qa'));
fs.mkdirSync(out, { recursive: true });
const seconds = Number(args.seconds || 60);
const shots = String(args.shots || '').split(',').filter(Boolean).map(Number);
const steps = String(args.do || '').split(';').filter(Boolean).map((s) => { const [t, kind, ...rest] = s.split(':'); return { t: Number(t), kind, arg: rest.join(':') }; });

const server = spawn(process.execPath, [path.join(ROOT, 'tools/web/serve.mjs'), String(PORT), args.dir || 'build/web'], { stdio: 'ignore' });
await new Promise((resolve) => setTimeout(resolve, 700));
const launch = { executablePath: CHROME, headless: true, args: ['--mute-audio', '--use-angle=' + (args.angle || 'd3d11'), '--enable-gpu', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] };
// --profile=DIR: a browser profile kept between runs (its GPU cache: a second visit).
const context = args.profile ? await chromium.launchPersistentContext(path.resolve(args.profile), launch) : null;
const browser = context ? null : await chromium.launch(launch);
const log = [];
const errors = [];
try {
  const [w, h] = (args.size || '1280x720').split('x').map(Number);
  const page = context ? (context.pages()[0] || await context.newPage()) : await browser.newPage({ viewport: { width: w, height: h } });
  if (context) await page.setViewportSize({ width: w, height: h });
  const t0 = Date.now();
  const stamp = () => ((Date.now() - t0) / 1000).toFixed(1).padStart(6);
  page.on('console', (m) => { const t = m.text(); log.push(`${stamp()} [${m.type()}] ${t}`); if (m.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(t)) errors.push(t.slice(0, 400)); });
  page.on('pageerror', (e) => { log.push(`${stamp()} [pageerror] ${e.message}`); errors.push(e.message); });
  await page.addInitScript(() => {
    window.__frames = [];
    const tick = (t) => { window.__frames.push(t); requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  });
  // --inject=a.js,b.js: scripts run before the page's own (as the shell will carry them).
  for (const file of String(args.inject || '').split(',').filter(Boolean)) await page.addInitScript({ path: path.resolve(file) });
  if (args.gl) {
    // Every program's link timed (the first status query waits for the compile): the slow
    // ones logged with the uniforms that tell which shader it is.
    await page.addInitScript(() => {
      const P = WebGL2RenderingContext.prototype;
      const src = new WeakMap();
      const shaders = new WeakMap();
      const shaderSource = P.shaderSource;
      P.shaderSource = function (sh, text) { src.set(sh, text); return shaderSource.call(this, sh, text); };
      const binds = new WeakMap();
      const bind = P.bindAttribLocation;
      P.bindAttribLocation = function (pr, i, name) { const l = binds.get(pr) || []; l.push([i, name]); binds.set(pr, l); return bind.call(this, pr, i, name); };
      const tfv = P.transformFeedbackVaryings;
      const tf = new WeakMap();
      P.transformFeedbackVaryings = function (pr, names, mode) { tf.set(pr, [names.slice(), mode]); return tfv.call(this, pr, names, mode); };
      // --capture: every linked program's sources (shared texts once), its bindings.
      window.__cap = { texts: [], index: new Map(), programs: [], seen: new Set() };
      const textId = (t) => { const c = window.__cap; if (!c.index.has(t)) { c.index.set(t, c.texts.length); c.texts.push(t); } return c.index.get(t); };
      const link = P.linkProgram;
      P.linkProgram = function (pr) {
        const sh = shaders.get(pr) || [];
        const ids = sh.map((x) => [this.getShaderParameter(x, this.SHADER_TYPE), textId(src.get(x) || '')]);
        const vs = (ids.find((x) => x[0] === this.VERTEX_SHADER) || [0, -1])[1];
        const fs = (ids.find((x) => x[0] === this.FRAGMENT_SHADER) || [0, -1])[1];
        const rec = [vs, fs, binds.get(pr) || [], tf.get(pr) || null];
        const key = JSON.stringify(rec);
        if (!window.__cap.seen.has(key)) { window.__cap.seen.add(key); window.__cap.programs.push(rec); }
        return link.call(this, pr);
      };
      const attach = P.attachShader;
      P.attachShader = function (pr, sh) { const l = shaders.get(pr) || []; l.push(sh); shaders.set(pr, l); return attach.call(this, pr, sh); };
      const get = P.getProgramParameter;
      window.__glSlow = [];
      window.__glTotal = { n: 0, ms: 0 };
      P.getProgramParameter = function (pr, pname) {
        const t = performance.now();
        const r = get.call(this, pr, pname);
        const ms = performance.now() - t;
        if (pname === this.LINK_STATUS) {
          window.__glTotal.n++; window.__glTotal.ms += ms;
          if (ms > 150) {
            const text = (shaders.get(pr) || []).map((sh) => src.get(sh) || '').join(' ');
            const names = [...new Set((text.match(/uniform\s+(?:highp\s+|mediump\s+|lowp\s+)?\w+\s+(m_\w+)/g) || []).map((u) => u.split(/\s+/).pop()))].slice(0, 8);
            console.log(`GLSLOW ${ms.toFixed(0)} ms len ${text.length} ${names.join(',')}`);
          }
        }
        return r;
      };
    });
  }
  await page.goto(`http://127.0.0.1:${PORT}/${args.page || 'index.html'}${args.query || ''}`);
  const events = [...shots.map((t) => ({ t, kind: 'shot' })), ...steps].sort((a, b) => a.t - b.t);
  for (const e of events) {
    const wait = e.t * 1000 - (Date.now() - t0);
    if (wait > 0) await page.waitForTimeout(wait);
    if (e.kind === 'shot') {
      const fps = await page.evaluate(() => { const f = window.__frames; const last = f[f.length - 1]; const recent = f.filter((x) => x > last - 3000); window.__frames = recent; return recent.length > 1 ? ((recent.length - 1) * 1000 / (recent[recent.length - 1] - recent[0])).toFixed(1) : '0'; });
      const curtain = await page.evaluate(() => { const c = document.getElementById('curtain'); const v = document.getElementById('splash'); return (c ? c.className || 'splash' : 'gone') + (v ? ` video ${v.currentTime.toFixed(1)}s${v.error ? ' error ' + v.error.code : ''}` : ''); }).catch(() => '?');
      log.push(`${stamp()} [curtain] ${curtain}`);
      const file = path.join(out, `t${String(e.t).padStart(3, '0')}.png`);
      await page.screenshot({ path: file, timeout: 180000 });
      log.push(`${stamp()} [shot] ${file} fps ${fps}`);
      console.log(`shot ${e.t}s fps ${fps}`);
    } else if (e.kind === 'click') {
      const [x, y] = e.arg.split(',').map(Number);
      await page.mouse.click(x, y);
    } else if (e.kind === 'key') {
      await page.keyboard.press(e.arg);
    } else if (e.kind === 'down' || e.kind === 'up') {
      await (e.kind === 'down' ? page.keyboard.down(e.arg) : page.keyboard.up(e.arg));
    } else if (e.kind === 'type') {
      await page.keyboard.type(e.arg, { delay: 60 });
    } else if (e.kind === 'move') {
      const [x, y] = e.arg.split(',').map(Number);
      await page.mouse.move(x, y, { steps: 8 });
    }
  }
  const rest = seconds * 1000 - (Date.now() - t0);
  if (rest > 0) await page.waitForTimeout(rest);
  if (args.capture) {
    const n = await page.evaluate(() => window.__cap.texts.length);
    const parts = [];
    for (let i = 0; i < n; i += 20) parts.push(...await page.evaluate(([a, b]) => window.__cap.texts.slice(a, b), [i, i + 20]));
    const programs = await page.evaluate(() => window.__cap.programs);
    fs.writeFileSync(path.resolve(args.capture), JSON.stringify({ texts: parts, programs }));
    console.log(`captured ${programs.length} programs, ${parts.length} shader texts -> ${args.capture}`);
  }
  if (args.gl) {
    const total = await page.evaluate(() => window.__glTotal).catch(() => null);
    if (total) { log.push(`GLTOTAL ${total.n} programs ${total.ms.toFixed(0)} ms`); console.log(`GL programs ${total.n}, ${total.ms.toFixed(0)} ms in their links`); }
  }
} finally {
  fs.writeFileSync(path.join(out, 'console.txt'), log.join('\n'));
  await (context || browser).close();
  server.kill();
}
console.log(`console ${log.length} lines, ${errors.length} errors -> ${path.join(out, 'console.txt')}`);
for (const e of [...new Set(errors)].slice(0, 25)) console.log('  ' + e);
