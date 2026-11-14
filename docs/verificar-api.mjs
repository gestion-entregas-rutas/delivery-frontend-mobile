// Prueba HTTP sin dependencias y sin cambios en datos. Requiere Node con fetch.
// Uso: node docs/frontend/verificar-api.mjs [http://localhost:5289]
import assert from 'node:assert/strict';

const base = (process.argv[2] ?? 'http://localhost:5289').replace(/\/$/, '');
const request = (path, options = {}) => fetch(base + path, {
  ...options, signal: AbortSignal.timeout(15000),
});

const swagger = await request('/swagger');
assert.equal(swagger.status, 200);
const openapi = await request('/openapi/v1.json');
assert.equal(openapi.status, 200);
const contrato = await openapi.json();
const operaciones = Object.values(contrato.paths)
  .flatMap(path => Object.keys(path))
  .filter(metodo => ['get', 'post', 'put', 'delete', 'patch'].includes(metodo));
assert.equal(operaciones.length, 21);
console.log('Swagger y OpenAPI: 200; 21 operaciones REST.');

for (const origen of ['http://localhost:4200', 'http://192.168.1.25:4300']) {
  for (const metodo of ['GET', 'POST', 'PUT', 'DELETE']) {
    const preflight = await request('/api/pedidos', {
      method: 'OPTIONS',
      headers: {
        Origin: origen,
        'Access-Control-Request-Method': metodo,
        'Access-Control-Request-Headers': 'content-type',
      },
    });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-allow-origin'), origen);
    assert.equal(preflight.headers.get('access-control-allow-credentials'), 'true');
    assert.ok(preflight.headers.get('access-control-allow-methods')?.includes(metodo));
  }
  console.log(`Preflight CORS: correcto para ${origen}.`);
}

const negociacion = await request('/hubs/seguimiento/negotiate?negotiateVersion=1', {
  method: 'POST', headers: { Origin: 'http://localhost:4200' },
});
assert.equal(negociacion.status, 200);
assert.ok((await negociacion.json()).connectionToken);
assert.equal(negociacion.headers.get('access-control-allow-origin'), 'http://localhost:4200');
console.log('SignalR: negociacion 200 sin autenticacion.');

const invalido = await request('/api/rutas/armar', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Origin: 'http://localhost:4200' },
  body: JSON.stringify({ fecha: '0001-01-01' }),
});
assert.equal(invalido.status, 400);
const problema = await invalido.json();
assert.equal(problema.status, 400);
assert.ok(problema.errors.Fecha);
assert.equal(invalido.headers.get('access-control-allow-origin'), 'http://localhost:4200');
console.log('POST REST: acceso anonimo, validacion 400 y CORS de error correctos.');
