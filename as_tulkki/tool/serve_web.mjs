import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/web');
const types = {'.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8',
  '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png',
  '.ico':'image/x-icon', '.ttf':'font/ttf', '.otf':'font/otf', '.svg':'image/svg+xml'};
http.createServer((request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = path.resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
    if (!file.startsWith(`${root}${path.sep}`) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      response.writeHead(404); response.end('Ei löydy'); return;
    }
    response.writeHead(200, {'Content-Type': types[path.extname(file)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'});
    if (request.method === 'HEAD') { response.end(); return; }
    fs.createReadStream(file).pipe(response);
  } catch { response.writeHead(400); response.end('Virheellinen pyyntö'); }
}).on('error', error => {
  if (error.code === 'EADDRINUSE') console.log('AS tulkin selainpalvelin on jo käynnissä: http://127.0.0.1:18765');
  else { console.error(error.message); process.exitCode = 1; }
})
  .listen(18765, '127.0.0.1', () => console.log('AS tulkki: http://127.0.0.1:18765'));
