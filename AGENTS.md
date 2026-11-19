# AGENTS.md — Aplicación Móvil Repartidor (`frontend_mobile` / RutaExpress)

## 1. Contexto y Misión
Este repositorio es la aplicación móvil en **Flutter** para los conductores/repartidores (`RutaExpress`)[cite: 11], conectada al backend en C# / .NET (`http://192.168.100.38:5289/api` o configurado en `lib/config/api_config.dart`)[cite: 11] y al hub SignalR (`/hubs/seguimiento`)[cite: 11].
Con el nuevo enfoque E-Commerce, los clientes compran en la tienda web (`frontend-tienda`) y, cuando eligen entrega a `Domicilio`, el backend genera automáticamente un `Pedido` logístico que el algoritmo propio asigna a la ruta del repartidor.

Tu misión es **mantener intacto el flujo operacional aprobado**, integrar la visualización de los artículos comprados en cada parada y cerrar los pendientes críticos de pruebas y GPS documentados en `MOVIL-FRONTEND.md`[cite: 11].

## 2. Reglas Inquebrantables
1. **Conservar diseño e identidad:** Mantener la identidad morada de RutaExpress (el morado sale de la animación del splash) y el flujo de Splash -> Login -> Cambio de credenciales temporales -> Ruta asignada -> Iniciar reparto -> En camino -> Entregado[cite: 6, 7, 11]. Los colores, la tipografía y los componentes viven en `lib/theme/` y `lib/widgets/`: úsalos en lugar de repetir colores o tamaños en línea. Significado fijo de color: morado = lo que puedes hacer o está activo, morado profundo con check = hecho, ámbar = atención, rojo = error. Cada estado de la pantalla de ruta tiene un solo botón principal, fijo abajo.
2. **Cero APIs externas de ruteo (con una excepción acotada):** No integrar Google Directions ni servicios externos de cálculo de rutas para decidir el orden de las paradas: el orden proviene 100% del algoritmo propio del backend[cite: 11]. Excepción autorizada por el responsable del proyecto: la app puede pedir al servidor público de OSRM (`router.project-osrm.org`, `lib/data/routing/road_router.dart`) únicamente el trazado por calles, la distancia y el tiempo entre puntos YA ordenados, para dibujarlos en el mapa (pestaña Mapa y pantalla de ruta a una parada). OSRM nunca reordena, elige ni descarta paradas; si falla, la app dibuja líneas rectas. Límites a tener presentes: es un servidor de demostración sin garantías y recibe las coordenadas de las paradas y del repartidor; para producción apunta `OsrmRoadRouter.baseUrl` a un OSRM propio. El mapa usa teselas de OpenStreetMap, cuyo servidor público tampoco es para uso intensivo. Nunca abrir Google Maps ni otras apps de mapas para navegar.
3. **El backend tiene la autoridad:** Nunca permitir que la app decida por sí sola iniciar rutas o cambiar estados sin confirmación HTTP exitosa del servidor[cite: 11].

## 3. Tareas Específicas a Realizar
1. **Visualización de Productos en la Parada (E-Commerce):**
   - En la tarjeta de detalle de cada pedido dentro de la ruta (`screens/`), mostrar de forma limpia el contenido de `detalles` (resumen de artículos de la tienda que el repartidor debe entregar, ej. *"2x Vela perfumada Yankee Candle"*) junto al nombre del destinatario, teléfono y dirección[cite: 11].
2. **Reparar Suite de Pruebas (`test/api_config_test.dart`):**
   - Corregir los 3 tests que fallan porque esperan `localhost`/`10.0.2.2` por defecto mientras `serverIp` está fijado en `192.168.100.38`[cite: 11]. Pasar `host: 'localhost'` explícitamente en esos casos unitarios (`Android emulator reaches the host rather than its own localhost`, `Web remains on localhost even when its host platform is Android`, `Desktop and iOS local defaults are unchanged`) y conservar un test independiente para IP LAN, logrando que `flutter test` pase al 100% sin fallos[cite: 11].
3. **Integración de Envío GPS Remoto (Pendiente Prioritario):**
   - Actualmente `location/gps_service.dart` captura coordenadas localmente en primer plano sin enviarlas al servidor[cite: 11].
   - Conectar la captura periódica (cuando la ruta está `EnCurso`) al endpoint/evento de ubicación del backend (ej. `POST /api/seguimiento/ubicacion` o invocación SignalR `ActualizarUbicacionRepartidor`, verificando el contrato exacto en el backend) para que el marcador del repartidor se mueva en tiempo real en el mapa de `RouteOS`[cite: 10, 11].
4. **Resiliencia en Pruebas de Estrés/Red:**
   - Asegurar que ante errores HTTP 5xx o pérdida temporal de conexión durante una entrega, el botón no quede bloqueado permanentemente y permita reintentar de forma segura sin duplicar estados[cite: 11].

## 4. Verificación antes de finalizar
Ejecutar obligatoriamente[cite: 11]:
1. `flutter analyze` (debe terminar con 0 issues)[cite: 11]. Si la ruta del proyecto tiene caracteres no ASCII (por ejemplo `GESTIÓN`), `flutter analyze` directo falla con `FormatException`; usa `powershell -File tool/analyze.ps1`, que lo corre desde una unidad virtual.
2. `flutter test` (todas las pruebas deben aprobar)[cite: 11].