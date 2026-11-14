# Estado actual de RutaExpress — aplicación móvil

**Fecha de revisión:** 13 de noviembre de 2026.  
**Repositorio revisado:** `frontend_mobile`.  
**Alcance:** código y documentación presentes, más análisis y pruebas ejecutados en esta revisión.

## 1. Hasta dónde está desarrollada

RutaExpress es una aplicación Flutter para conductores/repartidores. Ya superó la etapa de pantallas con datos simulados: tiene implementados el acceso JWT, el cambio obligatorio de credenciales, la consulta de la ruta propia, las acciones de entrega y la recepción de actualizaciones mediante SignalR.

El flujo implementado llega hasta **iniciar una ruta asignada, marcar pedidos en camino y confirmar su entrega**, usando las respuestas del backend. La finalización de la ruta corresponde al backend; la app consulta y muestra su estado.

La ubicación está preparada como **captura local en primer plano**. No se envían coordenadas al servidor, no se actualiza con ellas el mapa administrativo y no está implementado el seguimiento en segundo plano.

Esto describe funcionalidad existente en el código. No equivale a certificar que todos los flujos estén validados con cuentas reales, dispositivos físicos o en producción.

## 2. Funcionalidades implementadas

| Área | Estado en la aplicación |
| --- | --- |
| Presentación | Splash con identidad RutaExpress, colores amarillo/negro y mapa animado. |
| Login | Usuario o correo y contraseña; ocultar/mostrar contraseña, validación de campos y ayuda de acceso. No expone IP, URL ni identificadores técnicos. |
| Autenticación | Petición real de login JWT; admite conductor activo vinculado a un repartidor. |
| Credenciales temporales | Pantalla obligatoria para cambiar usuario/clave antes de acceder a rutas o SignalR. |
| Sesión | Token mediante almacenamiento seguro, restauración con consulta de identidad, expiración, revocación y cierre de sesión. No se guarda la contraseña. |
| Identidad del conductor | Se obtiene de la respuesta autenticada; no depende de un ID ingresado manualmente en el login. |
| Ruta | Consulta por fecha, paradas ordenadas, estados de carga/error/sin ruta y actualización manual. |
| Pedidos | Cliente, dirección, hora solicitada, estado y acciones asociadas a la parada. Teléfono y coordenadas se usan para abrir aplicaciones externas. |
| Inicio del reparto | Solicitud al backend para iniciar una ruta planificada; el servidor valida las reglas y la disponibilidad. |
| Entregas | Marcar en camino y confirmar entrega con diálogo previo. Botones bloqueados durante la petición; no se simula una entrega exitosa ante una petición fallida. |
| Ruta completada | Conservación de una ruta ya conocida mediante consulta por ID, aunque deje de aparecer como activa. No constituye un historial persistente completo. |
| Tiempo real | SignalR autenticado, grupo del repartidor, evento de ruta actualizada, reconexión y recuperación por REST. |
| Teléfono y mapas | Apertura del marcador para confirmar la llamada y apertura de mapas externos con las coordenadas de destino. |
| GPS | Permisos, servicio apagado, denegación permanente, precisión, última muestra local y control del ciclo de captura. |
| Navegación interna | Pantallas de ruta y perfil/cierre de sesión. |

### Flujo de uso implementado

1. Abrir la app y comprobar si existe una sesión recuperable.
2. Ingresar usuario y contraseña si es necesario.
3. Cambiar credenciales si la cuenta tiene una clave temporal.
4. Consultar la ruta del conductor para la fecha seleccionada.
5. Iniciar reparto cuando corresponda.
6. Marcar un pedido en camino.
7. Confirmar su entrega de forma explícita.
8. Recibir cambios de la ruta y consultar su estado actualizado.
9. Cerrar sesión o volver al login cuando la sesión expire o sea revocada.

La etiqueta «usuario o correo» se envía al campo `nombreUsuario` del contrato. La aceptación de un correo como identificador depende del backend; la app no tiene un endpoint de acceso por correo separado.

## 3. Integración con el backend

### Autenticación

| Método | Endpoint | Uso |
| --- | --- | --- |
| POST | `/api/autenticacion/login` | Obtener la sesión mediante usuario y clave. |
| GET | `/api/autenticacion/me` | Validar la identidad autenticada. |
| PUT | `/api/autenticacion/credenciales` | Cambiar credenciales y reemplazar el token. |
| POST | `/api/autenticacion/logout` | Solicitar la revocación de todas las sesiones propias. |

Los recursos protegidos utilizan Bearer JWT. No hay renovación mediante refresh token. Un token temporal queda limitado al cambio de credenciales; no habilita la operación de reparto.

El código distingue errores de credenciales, permisos, conflicto, reglas de negocio, límite de intentos, servidor y red. Un 401 se relaciona con el token que usó esa petición, para evitar que una respuesta antigua cierre una sesión nueva. Si la revocación remota no puede confirmarse al salir, se informa al usuario y se intenta limpiar la sesión local.

### Rutas y pedidos

| Método | Endpoint | Uso |
| --- | --- | --- |
| GET | `/api/repartidores/{id}/ruta?fecha=YYYY-MM-DD` | Consultar la ruta activa propia. |
| GET | `/api/rutas/{id}` | Recuperar una ruta conocida y su estado. |
| POST | `/api/rutas/{id}/iniciar` | Iniciar reparto. |
| POST | `/api/seguimiento/pedidos/{id}/en-camino` | Avanzar el pedido a en camino. |
| POST | `/api/seguimiento/pedidos/{id}/entregado` | Registrar la entrega. |

La app del conductor no debe utilizar el listado administrativo de repartidores para decidir si puede iniciar una ruta. Las restricciones y la autorización definitivas pertenecen al backend.

### SignalR

- Hub: `/hubs/seguimiento`.
- Suscripción: `SuscribirseARepartidor` con el ID de la identidad autenticada.
- Evento usado: `RutaActualizada`, con la ruta y sus pedidos.
- Token suministrado desde la sesión vigente.
- Validación de sesión y recuperación de datos al reconectar.
- Descarte de rutas ajenas a la pantalla y cierre del transporte al perder la sesión.

No se implementó un evento GPS ni un evento ficticio de asignación de rutas.

## 4. Configuración actual de conexión

Archivo único: [`lib/config/api_config.dart`](../lib/config/api_config.dart).

Valores encontrados en esta revisión:

```dart
static const String serverIp = '192.168.100.38';
static const int serverPort = 5289;
static const String scheme = 'http';
```

La URL resultante es `http://192.168.100.38:5289/api`. Login, rutas y SignalR comparten esa configuración. No se requieren argumentos especiales al ejecutar:

```powershell
flutter pub get
flutter run
```

Si se configura `localhost` o `127.0.0.1`, Android nativo lo adapta a `10.0.2.2`, dirección del equipo anfitrión desde el emulador. Una IP LAN configurada se utiliza directamente. Para teléfono físico, la IP debe ser accesible desde su red y el backend debe escuchar en ella.

HTTP está habilitado para Android debug. Para un despliegue real deben configurarse HTTPS y su certificado. Cambiar IP/puerto exige detener y volver a ejecutar la app. Esta revisión no certificó que la IP LAN configurada sea accesible actualmente.

## 5. GPS: límite exacto de lo implementado

### Ya existe

- Comprobación del servicio de ubicación.
- Solicitud y tratamiento de permisos.
- Acceso a ajustes cuando corresponde.
- Captura con `geolocator` durante la operación local autorizada.
- Validación de coordenadas y precisión.
- Conservación de la última muestra válida con su hora UTC original.
- Descarte de muestras anteriores a la última registrada.
- Detención al pausar la app, terminar la ruta, fallar la captura o cerrar/perder sesión.
- Comprobación del estado antes de reanudar la captura.

### Todavía no existe en esta aplicación

- Envío HTTP de coordenadas al backend.
- Consulta de última ubicación remota.
- Publicación/recepción del evento GPS propuesto.
- Actualización del marcador del repartidor en el panel web mediante esta captura.
- Servicio de seguimiento en segundo plano o con pantalla bloqueada.
- Historial de posiciones o sincronización de una cola offline de ubicaciones.

La documentación entregada marca el contrato GPS como pendiente. Si el backend lo implementó después, se debe revisar el contrato actualizado antes de conectarlo. La app actual no permite darlo por integrado.

## 6. Organización del código

```text
lib/
  main.dart                        Arranque y configuración de la aplicación
  config/api_config.dart           IP, puerto y protocolo compartidos
  auth/                            Modelos, repositorio, sesión y almacenamiento seguro
  data/api/                        Cliente HTTP, errores y repositorio logístico
  models/logistica_models.dart     Rutas, paradas, pedidos y otros DTO
  state/driver_controller.dart     Estado de pantalla, transiciones y ciclo de operación
  realtime/seguimiento_service.dart Conexión y suscripción SignalR
  location/gps_service.dart         Preparación y captura GPS local
  screens/                         Splash, login, cambio de credenciales, puerta de sesión,
                                   ruta/perfil y animación del mapa

test/                              Pruebas unitarias y de widgets, más prueba en vivo opcional
tool/verify_api.dart                Comprobaciones de lectura de la API
docs/                              Contratos y guías de integración
```

Dependencias declaradas: `http`, `signalr_netcore`, `geolocator`, `url_launcher`, `flutter_secure_storage`, `animate_do` y `cupertino_icons`.

## 7. Verificación realizada en esta revisión

Ejecutado el **13/11/2026**:

| Comando | Resultado |
| --- | --- |
| `flutter analyze` | Sin problemas detectados. |
| `flutter test` | 41 pruebas aprobadas, 3 fallidas y 1 omitida. Código de salida 1. |

### Por qué fallan tres pruebas

Todas pertenecen a `test/api_config_test.dart`. Esperan que las llamadas sin un `host` explícito utilicen `localhost` o la adaptación `10.0.2.2`, pero esas llamadas toman ahora el valor central `serverIp`, configurado como `192.168.100.38`.

Los casos afectados son:

- `Android emulator reaches the host rather than its own localhost`.
- `Web remains on localhost even when its host platform is Android`.
- `Desktop and iOS local defaults are unchanged`.

Esto identifica pruebas dependientes de la configuración del equipo; por sí solo no demuestra un fallo de conexión ni un fallo del login. El ajuste recomendado es proporcionar explícitamente `host: 'localhost'` en los casos que prueban ese comportamiento, y conservar un caso independiente para la IP LAN. **No se modificaron las pruebas ni la IP en esta revisión.**

La prueba en vivo JWT/SignalR se omite por defecto: requiere habilitación explícita y una sesión válida de conductor. Las pruebas simuladas cubren autenticación, credenciales temporales, expiración, almacenamiento, respuestas tardías, errores HTTP, estados de entrega, orden de paradas, reconexión, permisos GPS y widgets.

### Alcance de la evidencia

En etapas anteriores se compiló e instaló la aplicación en el emulador Android y se comprobó conectividad con la API. Eso es evidencia histórica, no una nueva validación integral del backend actual. En esta revisión no se intentó un login con una cuenta real, no se modificaron pedidos/rutas, no se probó almacenamiento seguro en teléfono físico ni se ejecutó una compilación iOS.

## 8. Pendientes para cerrar la aplicación

| Prioridad | Pendiente | Condición de cierre |
| --- | --- | --- |
| Alta | Independizar las pruebas de configuración de la IP local | Suite completa aprobada con IP LAN y localhost. |
| Alta | Prueba integrada con cuenta real de conductor | Login, cambio temporal, ruta propia, entrega, reconexión y logout verificados contra el backend. |
| Alta | Validar sesión en dispositivos físicos | Persistencia segura, expiración y revocación comprobadas en las plataformas soportadas. |
| Alta | Acordar e integrar GPS remoto | Contrato confirmado, envío autenticado y marcador web actualizándose con antigüedad de muestra visible. |
| Alta | Implementar y validar segundo plano | Pruebas con app minimizada y pantalla bloqueada, permisos y consumo documentados. |
| Media | Revisar recuperación ante resultados inciertos | Verificar también HTTP 5xx y respuestas incompletas en el controlador: la clasificación HTTP existe, pero su rama de recuperación automática contempla explícitamente conflicto/red/timeout. |
| Media | Pruebas de red y permisos en teléfonos | GPS apagado, permiso denegado/permanente, pérdida de conexión y recuperación. |
| Media | Preparar despliegue | HTTPS, configuración del servidor, identidad de aplicación, firma y compilación de distribución. |
| Según alcance | Historial y navegación dentro de la app | Definirlos si se requieren; hoy no hay historial completo ni cálculo de recorrido vial interno. |
| Académica | Evidencias e informes del proyecto | Completar las pruebas de sistema, volumen, carga y estrés y sus informes con el equipo. |

El registro administrativo de pedidos, zonas, usuarios y repartidores, y el algoritmo de armado de rutas pertenecen al backend/panel web. No son módulos administrativos implementados dentro de esta app móvil.

## 9. Documentos de referencia

- [Guía de integración móvil](INTEGRACION_MOVIL.md).
- [Contrato de autenticación JWT](Autenticacion_JWT_Integracion.md).
- [Requerimientos móviles de entregas y seguimiento](Solicitud_Flutter_Seguimiento_Repartidores.md).
- [Contrato general de API entregado](README.md).
- [Modelos JSON entregados](logistica.models.txt).

**Conclusión:** la aplicación cuenta con el flujo principal del conductor implementado a nivel de código e integración cliente. El cierre funcional y la preparación para producción siguen condicionados por la validación integral, el ajuste de las pruebas de configuración y la integración del seguimiento GPS remoto/segundo plano.
