# RutaExpress · Aplicación del conductor

Aplicación Flutter para consultar rutas y gestionar entregas de Delivery API.

## Arranque

```powershell
flutter pub get
flutter run
```

Configura la dirección del backend en `lib/config/api_config.dart`:

```dart
static const String serverIp = '192.168.100.38'; // IP real de tu servidor
static const int serverPort = 5289;
```

La IP mostrada es un ejemplo. El valor inicial `localhost` mantiene el desarrollo local y se convierte automáticamente en `10.0.2.2` en Android nativo. Una IP LAN configurada se usa directamente en todas las plataformas. La URL se comparte entre login, rutas y SignalR. No necesitas argumentos adicionales; detén y vuelve a ejecutar la app después de cambiarla. Para HTTPS cambia `scheme` a `https`.
## Acceso

El administrador debe crear una cuenta de rol `Conductor` vinculada a un repartidor. El login envía usuario y contraseña al backend. No existen usuarios ni contraseñas predeterminados.

Las cuentas temporales pasan al cambio obligatorio de credenciales antes de consultar rutas. La app obtiene el repartidor de la identidad autenticada; ya no utiliza `DRIVER_ID`. Conserva el JWT mediante `flutter_secure_storage`, nunca la contraseña. Cuando el token expira, se debe ingresar nuevamente: el backend no ofrece refresh tokens. Cerrar sesión revoca todas las sesiones propias; si no hay conexión, se cierra localmente y se informa que la revocación remota no fue confirmada.

## Verificación

```powershell
flutter analyze
flutter test
dart run tool/verify_api.dart http://localhost:5289
```

Sin token local, el último comando verifica que los recursos operativos y SignalR rechacen acceso anónimo. Opcionalmente acepta `DELIVERY_TEST_TOKEN` del entorno local para comprobaciones autenticadas de lectura. No pases tokens por argumentos, no los guardes en archivos del repositorio ni los compartas en chat.

Detalles de configuración, permisos y pruebas en [docs/INTEGRACION_MOVIL.md](docs/INTEGRACION_MOVIL.md). Contrato JWT del backend en [docs/Autenticacion_JWT_Integracion.md](docs/Autenticacion_JWT_Integracion.md).

## GPS pendiente

La autenticación ya está integrada. El endpoint de envío/consulta de ubicación y el evento GPS siguen pendientes del backend. La captura actual es una vista previa local en primer plano; no envía coordenadas ni actualiza el marcador web. El segundo plano requiere implementación y validación en dispositivos físicos.


