import http from 'node:http';
import {readFileSync} from 'node:fs';
const web = new URL('../web/', import.meta.url);
const server = http.createServer((request, response) => {
  if (request.url.startsWith('/startup-recovery.js')) {
    response.setHeader('Content-Type', 'text/javascript');
    response.end(readFileSync(new URL('startup-recovery.js', web)));
    return;
  }
  response.setHeader('Content-Type', 'text/html');
  response.end(readFileSync(new URL('index.html', web), 'utf8')
    .replace('$FLUTTER_BASE_HREF', '/')
    .replace(/<script src="flutter_bootstrap.js" async><\/script>/, '')
    .replace(/<script defer src="https:[^"]+"><\/script>/, ''));
});
server.listen(0, '127.0.0.1', () => console.log('PreviewPort=' + server.address().port));
