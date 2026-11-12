# Integración del panel Angular con Delivery API

## Arranque y acceso

Desde la raíz del backend:

```powershell
dotnet run --project Api --launch-profile http
```

Se requiere PostgreSQL con PostGIS y la cadena de conexión del entorno configurada
por el equipo backend. Las operaciones de datos requieren las migraciones aplicadas.
No compartir contraseñas en el código Angular.

| Recurso | URL local |
| --- | --- |
| Servidor | `http://localhost:5289` |
| Base REST | `http://localhost:5289/api` |
| Swagger interactivo | `http://localhost:5289/swagger` |
| Contrato OpenAPI | `http://localhost:5289/openapi/v1.json` |
| Hub SignalR | `http://localhost:5289/hubs/seguimiento` |

Todos los endpoints REST y el hub permiten acceso anónimo en esta etapa: no se
envía token ni cabecera Authorization. En Development, CORS admite cualquier
origen, método y cabecera, incluidas conexiones SignalR con credenciales. El
perfil HTTP no redirige a HTTPS en Development. Fuera de Development se mantiene
la lista `Cors:Origenes`; la apertura de CORS no se activa fuera de ese entorno.
La API sigue siendo anónima fuera de Development; CORS no equivale a autenticación.
Swagger y OpenAPI se publican solamente en Development. Swagger UI carga sus
recursos visuales desde CDN; el JSON OpenAPI se sirve localmente.

Para otro equipo en la misma red, el backend puede arrancarse con:

```powershell
dotnet run --project Api --launch-profile http --urls http://0.0.0.0:5289
```

El frontend debe usar `http://IP_DEL_BACKEND:5289`, nunca `0.0.0.0` ni su propio
localhost. La conectividad depende de la red y las reglas del firewall del equipo.

## Archivos para entregar al equipo frontend

- `logistica.models.ts`: tipos exactos de las solicitudes y respuestas actuales.
- `logistica-api.service.ts`: servicio Angular con los 21 endpoints REST actuales.
- `../../Api/Api.http`: ejemplos de peticiones, errores y negociación SignalR.
- `verificar-api.mjs`: comprobación HTTP de documentación, CORS, validación y hub.
- El JSON de `/openapi/v1.json` es la referencia generada por el backend en ejecución.

Estructura sugerida dentro del proyecto Angular:

```text
src/app/
  core/api/logistica.models.ts
  core/api/logistica-api.service.ts
  core/realtime/seguimiento.service.ts
  features/zonas/
  features/repartidores/
  features/pedidos/
  features/rutas/
  features/seguimiento/
```

Los dos archivos TypeScript adjuntos son una base para copiar al proyecto Angular;
este repositorio no contiene la aplicación Angular ni sus dependencias.

Con la API en Development, verificar la conexión sin modificar datos:

```powershell
node docs/frontend/verificar-api.mjs
```

El script requiere Node con fetch integrado y acepta otra URL como argumento.
No comprueba persistencia, entregas completas ni clientes Angular en ejecución.

Registrar en los providers de `app.config.ts`, conservando los existentes:

```typescript
import { provideHttpClient } from '@angular/common/http';
import { LOGISTICA_SERVER_URL } from './core/api/logistica-api.service';

// Dentro de providers:
provideHttpClient(),
{ provide: LOGISTICA_SERVER_URL, useValue: 'http://localhost:5289' },
```

Llamada desde un componente o servicio:

```typescript
private readonly api = inject(LogisticaApiService);

cargar(fecha: string) {
  this.api.listarPedidos({ fecha, pagina: 1, tamano: 50 }).subscribe({
    next: pagina => { this.pedidos = pagina.items; this.total = pagina.total; },
    error: error => { /* Mostrar error.error.detail o error.error.errors. */ },
  });
}
```

## Convenciones JSON

- Propiedades en camelCase; identificadores GUID como strings.
- Fechas: `yyyy-MM-dd`. Horas: `HH:mm:ss`. Timestamps: ISO 8601 con offset.
- Enviar la fecha del selector tal cual; convertirla a UTC puede cambiar el día.
- Estados como strings, respetando los valores de `logistica.models.ts`.
- Los listados de zonas, repartidores y rutas devuelven arrays.
- Pedidos devuelve `{ items, total, pagina, tamano }`: página desde 1, tamaño
  por defecto 50, mínimo 1 y máximo 200. `total` es el número filtrado de pedidos.
- `posicion` para insertar es base 0; `orden` en las paradas devueltas empieza en 1.
- Un parámetro opcional no utilizado debe omitirse; no enviar strings vacíos para GUID o fechas.

## Endpoints REST

Las rutas de esta tabla son relativas a `/api`. Los nombres de entrada y salida
corresponden a las interfaces adjuntas. Todas las operaciones aceptan JSON.

| Método | Ruta | Entrada | Respuesta exitosa |
| --- | --- | --- | --- |
| GET | `/zonas` | — | 200 `ZonaDto[]` |
| GET | `/zonas/{id}` | GUID | 200 `ZonaDto` |
| POST | `/zonas` | `CrearZonaRequest` | 201 `ZonaDto` |
| PUT | `/zonas/{id}` | `ActualizarZonaRequest` completo | 200 `ZonaDto` |
| GET | `/repartidores` | query `soloDisponibles`, opcional | 200 `RepartidorDto[]` |
| POST | `/repartidores` | `CrearRepartidorRequest` | 201 `RepartidorDto` |
| PUT | `/repartidores/{id}/disponibilidad` | `{ "disponible": true }` | 200 `RepartidorDto` |
| GET | `/repartidores/{id}/ruta` | query `fecha`, requerida | 200 `RutaDto`; 404 si no hay ruta activa |
| GET | `/pedidos` | query `fecha`, `zonaId`, `estado`, `pagina`, `tamano` | 200 `PaginaDto<PedidoDto>` |
| GET | `/pedidos/{id}` | GUID | 200 `PedidoDto` |
| POST | `/pedidos` | `RegistrarPedidoRequest` | 201 `RegistroPedidoDto` |
| POST | `/pedidos/{id}/cancelar` | Sin cuerpo | 200 `PedidoDto` |
| POST | `/rutas/armar` | `ArmarRutasRequest` | 200 `ArmadoRutasDto` |
| GET | `/rutas` | query `fecha` requerida, `zonaId` opcional | 200 `RutaDto[]` |
| GET | `/rutas/{id}` | GUID | 200 `RutaDto` |
| POST | `/rutas/{id}/pedidos` | `AgregarPedidoARutaRequest` | 200 `RutaDto` |
| DELETE | `/rutas/{id}/pedidos/{pedidoId}` | Sin cuerpo | 204 sin JSON |
| POST | `/rutas/{id}/iniciar` | Sin cuerpo | 200 `RutaDto` |
| POST | `/rutas/{id}/cancelar` | Sin cuerpo | 200 `RutaDto` |
| POST | `/seguimiento/pedidos/{pedidoId}/en-camino` | Sin cuerpo | 200 `PedidoDto` |
| POST | `/seguimiento/pedidos/{pedidoId}/entregado` | Sin cuerpo | 200 `PedidoDto` |

## Validaciones y reglas que debe reflejar la interfaz

- Zona: nombre obligatorio de hasta 100 caracteres, al menos 3 vértices y capacidad
  entera positiva. No repetir el primer vértice al final. Latitud de -90 a 90 y
  longitud de -180 a 180. Desactivar mediante PUT completo con `activa: false`.
- Repartidor: nombre hasta 150 caracteres, teléfono hasta 30, ambos obligatorios;
  capacidad entera positiva. No se puede cambiar disponibilidad si está EnRuta.
  `soloDisponibles` filtra su estado; tener una ruta planificada no cambia ese estado.
- Pedido: nombre hasta 150, teléfono hasta 30 y dirección hasta 300, obligatorios;
  fecha de hoy o futura. La ubicación debe pertenecer a una zona activa. Si se omite
  zonaId se intenta resolver automáticamente. En la solicitud las coordenadas son
  planas; en la respuesta están dentro de `ubicacion`.
- El alta devuelve `{ pedido, asignacion }`, no un PedidoDto directo. Para fecha
  futura, asignacion es null. Para hoy puede ser RutaExistente, RutaNueva o EnEspera.
  EnEspera es un alta exitosa: conservar el pedido y mostrar que falta asignación.
- El armado devuelve `{ fecha, rutas, pedidosSinAsignar }`; cero rutas no implica
  un error HTTP. Mostrar pedidosSinAsignar y consultar los pedidos pendientes.
- Cancelar pedido requiere Pendiente. Si está asignado, retirarlo primero cuando
  su estado lo permita. El DELETE de la tabla retira una asignación; no elimina el pedido.
- Cancelar ruta requiere Planificada y devuelve sus pedidos a Pendiente. Iniciar
  requiere pedidos y repartidor disponible. No se permite agregar otra zona/fecha
  ni superar capacidad. Una ruta admite cambios si está Planificada o EnCurso,
  respetando las paradas que ya avanzaron.
- Flujo actual: Pendiente → AsignadoARuta → EnCamino → Entregado. Para en-camino
  se requiere ruta EnCurso. La última entrega completa la ruta y libera repartidor.
- No hay todavía endpoints de recogida, reportes ni baja lógica de repartidores.
  Tampoco hay endpoints para borrar pedidos, zonas o rutas completas.
- La optimización actual no garantiza horarios de entrega ni rutas por calles.

## Errores

| Código | Tratamiento frontend |
| --- | --- |
| 400 | Revisar JSON, parámetros y validaciones de campos. |
| 404 | Recurso inexistente o repartidor sin ruta activa en esa fecha. |
| 409 | Conflicto de concurrencia o transición inválida. Recargar estado antes de volver a actuar; no repetir POST automáticamente. |
| 422 | Regla del negocio: mostrar detail (zona, capacidad, disponibilidad, etc.). |
| 500 | Error inesperado; mostrar mensaje general y conservar traceId si existe. |
| status 0 en Angular | Revisar conexión, URL, CORS o certificados; no es una respuesta de negocio. |

Forma de error habitual (algunos campos pueden faltar):

```json
{
  "title": "Datos inválidos",
  "status": 400,
  "detail": "Uno o más campos no cumplen las validaciones.",
  "instance": "/api/pedidos",
  "errors": { "ClienteNombre": ["El nombre es obligatorio."] }
}
```

Los nombres de campo de FluentValidation pueden venir en PascalCase; la
validación del binding puede usar otros nombres. El mensaje anterior es ilustrativo.
No asumir que 404 siempre contiene detail (la consulta de ruta puede devolverlo sin él).

## Seguimiento SignalR

Instalar en el proyecto Angular `npm install @microsoft/signalr@^10`.
Este fragmento se ejecuta en el navegador; en una aplicación con SSR iniciarlo
solamente después de comprobar que se está ejecutando en el navegador.

```typescript
import { HubConnectionBuilder } from '@microsoft/signalr';
import { PedidoDto, RutaDto } from './logistica.models';

const conexion = new HubConnectionBuilder()
  .withUrl('http://localhost:5289/hubs/seguimiento')
  .withAutomaticReconnect()
  .build();

// Usar la fecha seleccionada en la pantalla.
let fechaSeleccionada = '2027-02-14';
conexion.on('PedidoActualizado', (pedido: PedidoDto) => { /* Actualizar por id. */ });
conexion.on('RutaActualizada', (ruta: RutaDto) => { /* Actualizar por id. */ });
conexion.onreconnected(async () => {
  await conexion.invoke('SuscribirseAFecha', fechaSeleccionada);
  // Recargar por REST: durante la desconexión pueden haberse perdido eventos.
});
await conexion.start(); // Si falla, mostrar reintentar: la reconexión no cubre el primer start.
await conexion.invoke('SuscribirseAFecha', fechaSeleccionada);
// Después de suscribirse, cargar la pantalla por REST para obtener el estado inicial.

// Cuando cambie la fecha:
// await conexion.invoke('CancelarFecha', fechaSeleccionada);
// fechaSeleccionada = nuevaFecha;
// await conexion.invoke('SuscribirseAFecha', fechaSeleccionada);
// Recargar datos por REST.

// Al destruir la pantalla o cerrar la sesión de seguimiento:
// await conexion.stop();
```

| Método del hub | Argumento | Uso |
| --- | --- | --- |
| `SuscribirseAFecha` | `yyyy-MM-dd` | Panel administrativo por fecha. |
| `CancelarFecha` | `yyyy-MM-dd` | Abandonar la fecha anterior. |
| `SuscribirseARepartidor` | GUID | Recibir RutaActualizada del repartidor. |
| `SeguirPedido` | GUID | Recibir PedidoActualizado del pedido. |
| `DejarDeSeguirPedido` | GUID | Dejar seguimiento individual. |

Los eventos son avisos de actualización, no reemplazan las consultas REST ni
constituyen un historial. Al reconectar hay que volver a los grupos y refrescar
datos. No todos los cambios, por ejemplo la disponibilidad del repartidor o una
zona editada, tienen un evento propio; recargar sus listados después de modificarlos.

## Flujo de prueba compartido

1. Abrir Swagger y consultar zonas y repartidores.
2. Crear una zona y un repartidor disponible, anotando sus identificadores.
3. Registrar varios pedidos dentro de la zona para una fecha futura.
4. Armar rutas para esa misma fecha y revisar rutas y pedidosSinAsignar.
5. Consultar una ruta y mostrar paradas por orden, resolviendo zona/repartidor
   desde sus listados (la ruta devuelve identificadores, no sus nombres).
6. Iniciar la ruta; marcar cada pedido en camino y luego entregado.
7. Comprobar la actualización del panel suscrito a la fecha y el cierre de ruta.
8. Probar un pedido para hoy y comprobar su resultado de asignación automática.
9. Verificar manejo de errores por coordenadas fuera de zona, cupo completo y
   transición inválida. Las acciones de cancelar/retirar del archivo HTTP son
   escenarios alternativos y no deben ejecutarse ciegamente después de entregar.

Referencias de integración: [configuración HttpClient de Angular](https://angular.dev/guide/http/setup)
y [cliente JavaScript SignalR de Microsoft](https://learn.microsoft.com/en-us/aspnet/core/signalr/javascript-client?view=aspnetcore-10.0).
