# Autenticación JWT y roles

## Estado y configuración

Se implementaron los roles `Administrador` y `Conductor`. Toda la API operativa requiere JWT y credenciales definitivas. No existe registro público. El login es anónimo; las cuentas se crean por un administrador.

`Jwt:Issuer` y `Jwt:Audience` están en `Api/appsettings.json`. `Jwt:Key` debe ser un secreto aleatorio de al menos 32 bytes: usar user-secrets, `Jwt__Key` o la configuración local ignorada por Git. Se generó una clave aleatoria en `Api/appsettings.Development.json` para este equipo. No compartirla con web o Flutter: los clientes reciben tokens, nunca la clave de firma.

La migración `UsuariosAutenticacion` agrega la tabla `Usuarios`, los hashes, el rol y el vínculo único al repartidor. Para otras instalaciones:

```powershell
dotnet ef database update -p Infrastructure -s Infrastructure
```

## Primer administrador 

Desde la raíz, ejecutar localmente:

```powershell
.\scripts\Crear-Administrador.ps1
```

El script solicita usuario y contraseña temporal sin mostrarla, los transmite al proceso por variables de entorno y los retira al terminar. Se niega a crear el administrador inicial si ya existe uno; después se usa la gestión de usuarios autenticada. No se crea una cuenta ni una contraseña predeterminada. Este comando no inicia el servidor HTTP.

La primera sesión del administrador también exige cambiar credenciales. Para iniciar la API normalmente:

```powershell
dotnet run --project Api --launch-profile http
```

## Flujo del conductor

1. El administrador crea el repartidor mediante `POST /api/repartidores` y luego su cuenta mediante `POST /api/usuarios`, con rol `Conductor`, `repartidorId`, usuario y contraseña temporal.
2. Entrega esas credenciales al conductor por un canal acordado. El backend no envía correos ni mensajes automáticamente.
3. Flutter llama a `POST /api/autenticacion/login` con `{ "nombreUsuario": "...", "clave": "..." }`.
4. La respuesta contiene `accessToken`, `expiraEn`, `tokenType` y `usuario` (id, nombreUsuario, rol, repartidorId, activo y debeCambiarCredenciales).
5. Si `usuario.debeCambiarCredenciales` es `true`, abrir la pantalla de cambio obligatorio. Este token dura 10 minutos y solo permite identidad, cambio de credenciales y cierre de sesión. No permite rutas, pedidos ni SignalR.
6. Enviar `PUT /api/autenticacion/credenciales` con `claveActual`, `nuevoNombreUsuario` y `nuevaClave`. Puede conservarse el mismo nombre si el conductor solo desea cambiar la contraseña.
7. Guardar el nuevo token devuelto; el anterior queda revocado. El token operativo dura 30 minutos. Luego consultar la ruta propia y conectar SignalR.

Las claves requieren 12–128 caracteres, mayúscula, minúscula, número y símbolo. No se permite reutilizar la clave actual al cambiar credenciales. Los nombres de usuario son únicos sin distinguir mayúsculas/minúsculas y tienen 3–100 caracteres.

## Permisos

| Operación | Administrador | Conductor |
|---|---|---|
| Crear/listar cuentas, activar/desactivar y restablecer claves | Sí | No |
| Gestionar pedidos, zonas, repartidores y armado/ajuste de rutas | Sí | No |
| Consultar una ruta o pedido | Sí | Solo los vinculados a su repartidor |
| Consultar ruta activa por repartidor y fecha | Sí | Solo su repartidor |
| Iniciar ruta y marcar pedido en camino/entregado | Sí | Solo recursos propios, respetando estados |
| Listar todos los pedidos/rutas/repartidores | Sí | No |
| Cambiar credenciales y cerrar sesiones propias | Sí | Sí |

No se expone cambio de rol o reasignación de repartidor de una cuenta existente. Un conductor se vincula a un repartidor al crearla. La desactivación conserva el historial. Un administrador no puede desactivar su propia cuenta.

## Endpoints de autenticación y gestión

| Método | Ruta | Acceso |
|---|---|---|
| POST | `/api/autenticacion/login` | Anónimo |
| GET | `/api/autenticacion/me` | Sesión autenticada, incluso temporal |
| PUT | `/api/autenticacion/credenciales` | Credenciales propias, incluso sesión temporal |
| POST | `/api/autenticacion/logout` | Revoca todas las sesiones propias |
| POST | `/api/usuarios` | Administrador |
| GET | `/api/usuarios` | Administrador |
| PUT | `/api/usuarios/{id}/activo` | Administrador; cuerpo `{ "activo": false }` o `true` |
| POST | `/api/usuarios/{id}/restablecer-clave` | Administrador; cuerpo `{ "claveTemporal": "..." }` |

Después de restablecer la clave, el usuario vuelve al cambio obligatorio. Desactivar, cambiar credenciales, restablecer la clave o cerrar sesión invalida los JWT anteriores. No se implementan refresh tokens: cuando expire el token se debe ingresar nuevamente. `logout` cierra todas las sesiones de la cuenta, no solo el teléfono actual.

## Integración HTTP y SignalR

Enviar `Authorization: Bearer <accessToken>` en las peticiones protegidas. Swagger incorpora el botón **Authorize** con esquema Bearer; pegar únicamente el token.

Para evitar un bloqueo inicial de acceso a Swagger, la interfaz y el documento se publican anónimamente solo en desarrollo. Los endpoints operativos permanecen protegidos.

Hub: `/hubs/seguimiento`. Configurar la función de suministro de token de `signalr_netcore` para que use el token vigente. El backend acepta `access_token` por query únicamente en esta ruta para los transportes que lo requieren. Usar HTTPS y no registrar tokens en logs o URLs compartidas.

- Conductor: `SuscribirseARepartidor` solo con su `usuario.repartidorId`. Usar `RutaActualizada` para actualizar también los estados de los pedidos incluidos. Los grupos por pedido y fecha quedan reservados a administradores, para evitar que un conductor conserve una suscripción a un pedido reasignado.
- Administrador: puede suscribirse por fecha, repartidor o pedido.
- Eventos actuales: `RutaActualizada` y `PedidoActualizado`; no cambian sus nombres ni formatos.
- Reintentar la conexión con el token nuevo y volver a suscribir los grupos al reconectar. Un token temporal no permite negociar SignalR.
- Se cierran las conexiones al expirar la autenticación. Al revocar una cuenta/sesión, se desconectan sus conexiones registradas en esta instancia.
- Si se despliega en varias instancias, se requiere distribuir la revocación de sockets entre instancias; la validación HTTP ya consulta el sello persistido en PostgreSQL en cada petición.

En Flutter, guardar el token en almacenamiento seguro de la plataforma (acordar un paquete adicional); nunca conservar la contraseña temporal ni incluir credenciales de la base de datos. Al cambiar credenciales, reemplazar el token antes de conectar SignalR.

## Respuestas y protección de ingreso

- `401`: token ausente, inválido, vencido o revocado; credenciales incorrectas o cuenta no disponible.
- `403`: sesión válida sin permiso o con cambio obligatorio pendiente para una operación protegida.
- `409`: conflicto de concurrencia/estado; recargar antes de repetir.
- `422`: regla de negocio, por ejemplo nombre duplicado o clave que no cumple la política.
- `429`: límite de intentos por IP (10 peticiones/minuto para login y cambio de credenciales, compartido).

Cinco contraseñas incorrectas bloquean el ingreso de la cuenta por 15 minutos. El administrador puede restablecer una clave para retirar el bloqueo. No mostrar información que distinga cuentas existentes/inexistentes en el login.

El archivo `Api/Autenticacion.http` contiene ejemplos para todos los endpoints nuevos. Las claves que aparecen allí son ejemplos y no corresponden a cuentas creadas.

## Pruebas

Las pruebas HTTP/SignalR usan WebApplicationFactory y una base EF InMemory aislada: verifican políticas, tokens y flujo de credenciales. No sustituyen pruebas de restricciones o concurrencia contra PostgreSQL. La migración se aplica por separado al PostgreSQL local.

Referencia para la configuración Bearer de SignalR: [documentación oficial de ASP.NET Core](https://learn.microsoft.com/aspnet/core/signalr/authn-and-authz?view=aspnetcore-10.0).
