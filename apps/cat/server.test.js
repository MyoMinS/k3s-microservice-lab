'use strict';

const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const server = require('./server');

server.listen(0, '127.0.0.1');
after(() => server.close());

for (const path of ['/cat', '/cate']) {
  test(`GET ${path} returns ok`, async () => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`);
    assert.equal(response.status, 200);
    assert.equal(await response.text(), 'WatokeMa Daw Win Pa Pa Aung\n');
  });
}

test('unknown path returns 404', async () => {
  const response = await fetch(`http://127.0.0.1:${server.address().port}/dog`);
  assert.equal(response.status, 404);
});