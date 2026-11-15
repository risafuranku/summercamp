// Static server for the web export (build/web) for the browser checks and the phone.
//   node tools/web/serve.mjs [port] [folder]
// Godot's single-threaded export needs no COOP/COEP; .wasm must go as application/wasm.
// A file with a .br beside it goes compressed (as on the real host).

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const port = Number(process.argv[2] || 5187);
const dir = path.resolve(ROOT, process.argv[3] || 'build/web');
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json',
  '.webp': 'image/webp', '.webm': 'video/webm', '.mp4': 'video/mp4', '.ico': 'image/x-icon', '.css': 'text/css; charset=utf-8', '.woff2': 'font/woff2',
};

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://local');
  let file = path.join(dir, decodeURIComponent(url.pathname));
  if (!file.startsWith(dir)) { res.writeHead(403).end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { res.writeHead(404).end('not found'); return; }
  const headers = {
    'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
    // The export changes under the same names: no cache, so the phone never plays an old one.
    'Cache-Control': 'no-cache',
    'Access-Control-Allow-Origin': '*',
  };
  let body = file;
  if (String(req.headers['accept-encoding'] || '').includes('br') && fs.existsSync(file + '.br')) {
    body = file + '.br';
    headers['Content-Encoding'] = 'br';
  }
  headers['Content-Length'] = fs.statSync(body).size;
  res.writeHead(200, headers);
  if (req.method === 'HEAD') { res.end(); return; }
  fs.createReadStream(body).pipe(res);
}).listen(port, '0.0.0.0', () => console.log(`Cursed Camp (web) ${dir} at http://127.0.0.1:${port}`));
