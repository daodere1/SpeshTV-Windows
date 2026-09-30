import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(process.env.WEB_ROOT || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/web'));
const port = Number(process.env.PORT || 8098);
const base = '/web/speshtv-0.1.0/moonfin/';
const types = {'.html':'text/html', '.js':'application/javascript', '.mjs':'text/javascript',
  '.wasm':'application/wasm', '.json':'application/json', '.svg':'image/svg+xml',
  '.png':'image/png', '.woff2':'font/woff2', '.ttf':'font/ttf', '.otf':'font/otf'};
http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  if (url.pathname === '/') {
    res.writeHead(302, {Location:base}).end(); return;
  }
  if (url.pathname === `${base}config.json`) {
    res.writeHead(200, {'Content-Type':'application/json', 'Cache-Control':'no-store'});
    res.end(JSON.stringify({schemaVersion:1, pluginMode:true, enableWebRtcScan:false,
      brandingName:'SpeshTV', defaultServerUrl:`http://127.0.0.1:${port}`})); return;
  }
  if (url.pathname.startsWith(base)) {
    let name;
    try { name = decodeURIComponent(url.pathname.slice(base.length)) || 'index.html'; }
    catch { res.writeHead(400).end(); return; }
    const file = path.resolve(root, name);
    if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
    if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
    try {
      const stat = fs.statSync(file);
      if (!stat.isFile()) { res.writeHead(404).end(); return; }
      res.writeHead(200, {'Content-Type':types[path.extname(file)] || 'application/octet-stream',
        'Content-Length':stat.size, 'Cache-Control':'no-store'});
      if (req.method === 'HEAD') res.end(); else fs.createReadStream(file).pipe(res);
    } catch { res.writeHead(404).end(); }
    return;
  }
  // Fixed loopback target; never log authentication headers or request bodies.
  const upstream = http.request({hostname:'127.0.0.1', port:8097, path:req.url,
    method:req.method, headers:{...req.headers, host:'127.0.0.1:8097'}}, response => {
    res.writeHead(response.statusCode, response.headers); response.pipe(res);
  });
  upstream.on('error', () => { if (!res.headersSent) res.writeHead(502); res.end(); });
  req.pipe(upstream);
}).listen(port, '127.0.0.1', () => console.log(`SpeshTV preview: http://127.0.0.1:${port}${base}`));
