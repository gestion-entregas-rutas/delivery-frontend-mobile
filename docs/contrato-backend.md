# Contrato del backend usado por la app móvil

Confirmado por el equipo de backend el 2026-11-19. Es la fuente de verdad: si
algo aquí no coincide con el código, se corrige el código, no se supone.
Si el backend cambia, actualiza este archivo en el mismo cambio.

## Ruta activa

`GET /api/repartidores/{id}/ruta?fecha=YYYY-MM-DD`

- `{id}` debe ser el `repartidorId` del token de conductor; si no, **403**.
- **404 sin cuerpo** si ese día no hay ruta `Planificada` ni `EnCurso` (por
  ejemplo, una ruta ya `Completada` deja de devolverse).
- La app envía siempre `fecha` explícita. Sin ella, el servidor calcula "hoy"
  con su zona horaria local, que en un servidor UTC (Render) cambia de día a
  las 19:00 de Ecuador.

Forma de la respuesta (resumida): `id`, `fecha`, `zonaId`, `repartidorId`,
`capacidad`, `estado`, `version`, `paradas[] { orden, pedido }`.

Cada `pedido`: `id`, `clienteNombre`, `clienteTelefono`, `direccion`,
`ubicacion { latitud, longitud }`, `zonaId`, `fechaEntrega`, `horaEntrega`,
`estado`, `rutaId`, `registradoEn`, `entregadoEn`, `detalles`, `version`,
`destinatarioNombre`, `destinatarioTelefono`.

## `detalles`

El objeto `detalles` puede venir `null` (pedidos históricos). Si viene, todos
sus campos son nullable:

| Campo | Tipo | Notas |
|---|---|---|
| `remitenteNombre`, `remitenteTelefono` | texto (máx. 150 / 30) | vienen los dos o ninguno |
| `remitenteCorreo`, `destinatarioCorreo` | texto con formato de correo | |
| `observaciones` | texto, máx. 2000 | vacío o solo espacios se guarda como `null` |
| `tipoCarga` | `General`, `Documento`, `Alimentos`, `Medicamentos`, `Otro` | enum como texto |
| `pesoKg` | decimal en kg, > 0 y hasta 10000, máx. 3 decimales | |
| `fragil` | booleano | |
| `prioridad` | `Baja`, `Normal`, `Alta`, `Urgente` | enum como texto |

### `observaciones`

- Pedidos de la **tienda** (checkout): `"{cantidad}x {producto}"` separados por
  `", "`. Ejemplo: `"2x Audífonos, 1x Mouse"`. El backend **no escapa** comas:
  un producto con coma en el nombre no se puede separar con seguridad solo por
  coma. La app corta únicamente en `", "` seguido de `"{n}x "`.
- Pedidos creados **a mano** (panel): texto libre sin formato. La app no lo
  parte en artículos; lo muestra entero como "Observaciones".
- Lo que escribe el cliente en `datosDomicilio.observaciones` se guarda en la
  orden, no en el pedido: no llega a la app.

## Estados (exactos, sensibles a mayúsculas)

- Pedido: `Pendiente`, `AsignadoARuta`, `EnCamino`, `Entregado`, `Cancelado`.
- Ruta: `Planificada`, `EnCurso`, `Completada`, `Cancelada`.
- Repartidor: `Disponible`, `EnRuta`, `NoDisponible`.

Un pedido `Cancelado` puede seguir dentro de la ruta: la app no lo trata como
parada actual, no lo cuenta en el avance y no lo dibuja en el mapa.

## Fechas y horas

- `fechaEntrega`: `yyyy-MM-dd`; `horaEntrega`: `HH:mm:ss`. Sin zona horaria.
- `registradoEn` y `entregadoEn`: ISO 8601 en UTC (`+00:00`).

## `clienteTelefono`

Texto libre, obligatorio, máx. 30 caracteres. **No se normaliza**: puede traer
espacios, `+593`, etc. No asumir solo dígitos.

## Iniciar ruta

`POST /api/rutas/{id}/iniciar`

- **El backend no valida la fecha**: acepta una ruta `Planificada` de cualquier
  día. La app lo bloquea comparando `ruta.fecha` con el día local
  (`lib/utils/route_day.dart`); es un control de la app, no de seguridad.
- Rechaza: ruta no `Planificada` → **409** ("Transición de estado inválida");
  ruta sin paradas → **422** ("No se puede iniciar una ruta sin pedidos.");
  ruta de otro repartidor → **403**; ruta inexistente → **404**.
- Los errores vienen como ProblemDetails (RFC 7807):
  `{ status, title, detail, instance, traceId }`.

## Reportar ubicación

`POST /api/repartidores/me/ubicacion` (token de conductor con credenciales ya
cambiadas; si no, **403**).

```json
{ "rutaId": "…", "latitud": -1.23436, "longitud": -78.61547,
  "precisionMetros": 12.5, "capturadaEn": "2026-11-20T10:05:00-05:00" }
```

- `capturadaEn`: ISO 8601 **con offset** (`-05:00` o `Z`); sin offset lo
  rechaza. La app envía siempre UTC (`Z`).
- Rangos: latitud −90 a 90, longitud −180 a 180, `precisionMetros` 0 a 1000.
- La ruta debe estar `EnCurso`; si no, **422** ("Solo se publica GPS durante
  una ruta en curso.").
- Ruta de otro repartidor → **403**; inexistente → **404**; datos inválidos →
  **400**.
- La respuesta indica si la posición se actualizó y la ubicación guardada; una
  posición más antigua que la guardada no la actualiza. **Pendiente de
  confirmar:** nombres exactos de esos campos (la app no los usa).

## Preguntas abiertas para el backend

1. Cuando `clienteNombre`/`clienteTelefono` y `destinatarioNombre`/
   `destinatarioTelefono` difieren, ¿a quién debe llamar o escribir el
   repartidor? Hoy la app usa `cliente*` y solo lee `destinatario*`.
2. ¿Se puede validar en el backend que una ruta de otro día no se inicie?
3. Nombres exactos de los campos de la respuesta de ubicación.
