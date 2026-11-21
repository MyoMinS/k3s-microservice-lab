'use strict';

const http = require('node:http');

const server = http.createServer((request, response) => {
  const path = new URL(request.url, 'http://localhost').pathname;
  if (request.method !== 'GET') {
    response.writeHead(405, { 'content-type': 'text/plain', allow: 'GET' });
    response.end('Method Not Allowed\n');
    return;
  }
  if (path === '/healthz' || path === '/cat' || path === '/cate') {
    response.writeHead(200, { 'content-type': 'text/plain' });
    response.end('WatokeMa Daw Win Pa Pa Aung\n');
    return;
  }
  response.writeHead(404, { 'content-type': 'text/plain' });
  response.end('Not Found\n');
});

if (require.main === module) {
  server.listen(Number(process.env.PORT || 3000), '0.0.0.0');
}

module.exports = server;