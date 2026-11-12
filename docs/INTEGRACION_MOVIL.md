# Integración móvil del conductor

## Entorno

```powershell
flutter pub get
flutter run
```

Configura serverIp, serverPort y scheme en lib/config/api_config.dart. Coloca solo la IP o nombre del servidor, sin protocolo ni /api. localhost se adapta a 10.0.2.2 en el emulador Android; una IP LAN se conserva en todas las plataformas. Usa HTTPS en despliegues reales. No se muestran campos técnicos en el login. Detén y vuelve a ejecutar la app tras modificar la configuración.

## JWT y roles

El contrato vigente está en [Autenticacion_JWT_Integracion.md](Autenticacion_JWT_Integracion.md).

- `POST /api/autenticacion/login`: `{ nombreUsuario, clave }`. La etiqueta usuario o correo se envía en `nombreUsuario`, tal como exige el contrato; no existe un endpoint separado para correo.
- La respuesta contiene `accessToken`, `expiraEn`, `tokenType` y `usuario`. Solo se admite un conductor activo vinculado a un repartidor.
- El identificador operativo procede de `usuario.repartidorId`; se eliminó el acceso simulado por `DRIVER_ID`.
- `GET /api/autenticacion/me` valida la identidad al restaurar y antes de recuperar actividad protegida.
- Si `debeCambiarCredenciales` es verdadero, se presenta exclusivamente el cambio obligatorio. El token temporal no consulta rutas ni conecta el hub.
- `PUT /api/autenticacion/credenciales`: `{ claveActual, nuevoNombreUsuario, nuevaClave }`. La clave nueva exige 12–128 caracteres, mayúscula, minúscula, número y símbolo; debe diferir de la actual. El token devuelto reemplaza al revocado antes de abrir rutas.
- `POST /api/autenticacion/logout` revoca todas las sesiones de la cuenta. La app confirma este alcance. Ante error de red elimina la sesión local y avisa de que la revocación remota no está confirmada.

No se implementan registro público, creación de cuentas ni refresh tokens. La expiración o revocación obliga a ingresar nuevamente. No se deben probar credenciales de ejemplo: el administrador entrega una cuenta real por el canal acordado.

### Persistencia y errores

Se agregó [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) para el sobre de sesión. La contraseña no se guarda. Android desactiva las copias de seguridad de la aplicación; deben validarse KeyStore/Keychain y la persistencia en cada plataforma de destino. Las pruebas unitarias usan almacenamiento inyectado, no sustituyen una prueba de almacenamiento nativo.

Los JWT se envían como `Authorization: Bearer` en REST y mediante el proveedor de token de SignalR. No se registran tokens ni contraseñas. Un 401 solo invalida la sesión cuyo token se usó en esa petición; una respuesta antigua no borra un token de reemplazo. Un 403 informa permiso insuficiente. El login muestra un error genérico de credenciales sin distinguir cuentas existentes. Un 429 pide esperar y no se reintenta automáticamente.

Si `/me` no responde por un fallo transitorio, el token cifrado se conserva para reintentar, pero no se muestra la pantalla operativa. Las escrituras/borrados de sesión se serializan y las respuestas tardías no deben reactivar una sesión cerrada.

## Rutas y entregas

La consulta usa `GET /api/repartidores/{repartidorId}/ruta?fecha=YYYY-MM-DD`. Las fechas se conservan locales, sin conversión UTC. Se ordenan las paradas por `orden`. Un 404 muestra que no hay ruta activa. Una ruta ya conocida y completada se conserva mediante `GET /api/rutas/{id}` durante la sesión.

Las acciones no llevan cuerpo y no se reintentan automáticamente:

- `POST /api/rutas/{id}/iniciar`
- `POST /api/seguimiento/pedidos/{id}/en-camino`
- `POST /api/seguimiento/pedidos/{id}/entregado`

La disponibilidad al iniciar la ruta la valida el backend. La app del conductor no consulta el listado administrativo de repartidores. Los botones respetan los estados, bloquean dobles toques y solicitan confirmación antes de entregar. Los conflictos y resultados inciertos requieren recargar el estado antes de continuar.

## SignalR

Hub `/hubs/seguimiento`, con el JWT vigente. Se invoca `SuscribirseARepartidor` únicamente para la identidad autenticada y se usa `RutaActualizada`. Los grupos por fecha/pedido no se utilizan desde la app del conductor.

Al recuperar la conexión se valida la sesión, se repone el grupo y se recarga por REST. El primer fallo permite reintento manual. Se descartan rutas ajenas a la pantalla y se detiene el transporte al cerrar o perder la sesión.

## GPS y acciones externas

`geolocator` comprueba servicio, permisos y precisión. La pantalla explica el propósito antes de pedir permiso. Se conserva únicamente la última muestra válida con su hora UTC de captura; se descartan muestras anteriores. La captura es **local y en primer plano**: se detiene al salir de la app, finalizar la ruta o cerrar/perder sesión. Al regresar se consulta el estado antes de reiniciarla.

Aunque JWT ya existe, el contrato GPS continúa pendiente. No se hace POST al endpoint propuesto ni se inventan eventos. El seguimiento en segundo plano/pantalla bloqueada requiere implementación nativa y pruebas físicas; no se garantiza después de un cierre forzado.

El teléfono abre el marcador para que el usuario confirme la llamada. Las coordenadas abren mapas externos mediante `url_launcher`. No se solicitan permisos de contactos ni llamadas directas.

## Pruebas

```powershell
flutter analyze
flutter test
dart run tool/verify_api.dart http://localhost:5289
```

El último comando comprueba 401 sin token. Con un JWT operativo de conductor disponible únicamente en la variable local `DELIVERY_TEST_TOKEN`, comprueba identidad, ruta propia y negociación del hub sin modificar datos. Para verificar el cliente SignalR real con esa misma variable local:

```powershell
flutter test test/live_api_test.dart --dart-define=LIVE_API=true
```

La prueba en vivo se omite por defecto. No pases tokens en argumentos ni los escribas en archivos versionados o chats. La suite simulada cubre transiciones, fechas, errores, GPS, login, cambio obligatorio, almacenamiento, expiración y respuestas tardías. Todavía deben validarse el ingreso con cuenta real, la revocación entre dispositivos, el almacenamiento nativo y el GPS en teléfonos físicos. No se alteraron pedidos ni rutas reales durante estas comprobaciones.

## Diagnóstico de conexión

Comprueba serverIp y serverPort en lib/config/api_config.dart y que el backend escuche en esa dirección. En un teléfono físico usa la IP LAN del equipo servidor. Android debug permite HTTP local; los despliegues reales deben usar HTTPS. El navegador y el emulador comparten la configuración central. No se requiere --dart-define para arrancar la app.

