# Solicitud al equipo Flutter: entregas y seguimiento del repartidor

## Objetivo

Implementar en la aplicación móvil la consulta de entregas asignadas, la actualización de estados y el envío de ubicación durante el reparto. La ubicación debe permitir al panel web mostrar la última posición conocida del repartidor.

**Herramientas seleccionadas:** Flutter, `geolocator` para obtener la ubicación y `signalr_netcore` para recibir actualizaciones del backend en tiempo real. Las acciones y el envío de ubicación se realizarán mediante HTTP; SignalR distribuirá las actualizaciones a los clientes.

Este documento distingue los contratos actuales de las propuestas pendientes. No implementar las propuestas como si ya estuvieran disponibles en el backend.

## 1. Consulta de rutas y entregas

- Consultar la ruta activa del repartidor para la fecha seleccionada.
- Mostrar los pedidos por `paradas[].orden`, que comienza en 1.
- Mostrar cliente, teléfono, dirección, ubicación de entrega, hora solicitada y estado.
- Mostrar una pantalla sin ruta asignada cuando la consulta responda 404.
- Permitir actualizar manualmente y recargar después de recuperar la conexión.
- Conservar la ruta completada en pantalla usando su identificador: la consulta de ruta activa deja de devolverla cuando termina.

### Endpoints existentes

| Acción | Método y ruta | Resultado |
|---|---|---|
| Consultar ruta activa | `GET /api/repartidores/{id}/ruta?fecha=YYYY-MM-DD` | Ruta planificada o en curso; 404 si no hay ruta activa |
| Consultar una ruta | `GET /api/rutas/{id}` | Ruta con sus paradas y pedidos |
| Consultar un pedido | `GET /api/pedidos/{id}` | Datos del pedido |
| Iniciar ruta | `POST /api/rutas/{id}/iniciar` | Ruta actualizada |
| Marcar en camino | `POST /api/seguimiento/pedidos/{pedidoId}/en-camino` | Pedido actualizado |
| Confirmar entrega | `POST /api/seguimiento/pedidos/{pedidoId}/entregado` | Pedido actualizado |

Los tres POST anteriores no requieren cuerpo. Las propiedades JSON usan camelCase y los estados se representan como texto.

### Acciones según el estado

| Acción móvil | Condición |
|---|---|
| Iniciar reparto | Ruta `Planificada`, con pedidos y repartidor disponible |
| Marcar en camino | Ruta `EnCurso` y pedido `AsignadoARuta` |
| Confirmar entrega | Ruta `EnCurso` y pedido `EnCamino` |
| Finalizar ruta | Automático en backend al entregar todos los pedidos |

No marcar entregas automáticamente por proximidad GPS. Pedir confirmación al repartidor. Mostrar el orden planificado; actualmente el backend no obliga a completar las paradas en ese orden.

Deshabilitar el botón mientras la petición está en curso. Actualizar la interfaz con la respuesta del servidor. No mostrar una entrega como confirmada si la petición falló o no tiene respuesta.

## 2. Permisos y obtención de ubicación con geolocator

- Explicar que la ubicación se comparte durante el reparto y para qué se utiliza.
- Comprobar si el servicio de ubicación del teléfono está habilitado.
- Solicitar los permisos aplicables a cada plataforma en el momento de usar la función.
- Gestionar permiso denegado, denegación permanente, ubicación desactivada y precisión insuficiente, sin bloquear ni cerrar la app.
- Ofrecer instrucciones para habilitar el servicio o cambiar el permiso en ajustes cuando corresponda.
- Mostrar si el seguimiento está activo, sin permiso, sin conexión o esperando una ubicación válida.
- No solicitar acceso a contactos, micrófono ni registro de llamadas para estas funciones.

**Segundo plano:** se solicita mantener el seguimiento durante una ruta activa al minimizar la app o bloquear la pantalla. El equipo Flutter debe validar y configurar los permisos, servicios y capacidades nativas requeridas por Android/iOS y por las versiones elegidas. No asumir que instalar `geolocator` por sí solo resuelve la ejecución en segundo plano ni garantizar seguimiento después de un cierre forzado del sistema o del usuario. Documentar el comportamiento real probado.

## 3. Ciclo de seguimiento GPS

1. Al intentar iniciar una ruta, comprobar el estado del GPS y los permisos e informar cualquier limitación.
2. Después de que el backend confirme la ruta `EnCurso`, iniciar la captura y el envío de ubicaciones si están autorizados.
3. Enviar una primera ubicación válida y continuar durante la ruta.
4. Al recuperar conexión o volver a abrir la app, consultar el estado de la ruta antes de reanudar el seguimiento.
5. Detener la captura y el envío al completar la ruta, cerrar sesión o perder autorización para compartir ubicación. Mostrar cualquier interrupción durante una ruta activa.

Propuesta inicial configurable: limitar envíos a uno cada 10–15 segundos y usar un umbral de movimiento de aproximadamente 20 metros, con una actualización periódica aunque el vehículo esté detenido. Son valores de partida para probar batería, precisión y consumo, no requisitos del contrato actual.

Ante pérdida de internet, conservar la ubicación más reciente con su hora original y enviarla al reconectar. Evitar acumular y enviar un historial ilimitado. No cambiar la hora de captura para hacer pasar una posición antigua por reciente. Los cambios de estado de pedidos requieren confirmación independiente del servidor.

## 4. Contrato GPS propuesto: pendiente del backend

**Este endpoint y el evento GPS todavía no existen.** Ambos equipos deben confirmar el contrato antes de integrar.

### Envío HTTP propuesto

`POST /api/repartidores/me/ubicacion`

El backend deberá identificar al repartidor mediante autenticación. No confiar en un identificador arbitrario enviado por el teléfono. La autenticación también está pendiente.

```json
{
  "rutaId": "00000000-0000-0000-0000-000000000001",
  "latitud": -0.1807,
  "longitud": -78.4678,
  "precisionMetros": 12.0,
  "capturadaEn": "2026-10-17T15:30:00Z"
}
```

- Latitud entre -90 y 90; longitud entre -180 y 180.
- Precisión en metros, con valor finito y no negativo.
- Fecha de captura en UTC; el backend también registrará la hora de recepción.
- Verificar que la ruta esté en curso y pertenezca al usuario autenticado.
- Una muestra anterior no debe reemplazar una ubicación más reciente.
- Confirmar con backend la respuesta HTTP y los límites de antigüedad, precisión y frecuencia antes de desarrollar contra este contrato.

### Evento propuesto para el panel web

`UbicacionRepartidorActualizada`, con repartidor, ruta, coordenadas, precisión, hora de captura y hora de recepción. El backend lo publicará a los usuarios autorizados. También debe ofrecer una consulta de última ubicación para la carga inicial y la reconexión del panel.

## 5. Actualizaciones mediante signalr_netcore

### Contrato existente

- Hub: `/hubs/seguimiento`.
- Suscripción: invocar `SuscribirseARepartidor` con el identificador del repartidor como argumento.
- Evento `RutaActualizada`: contiene un `RutaDto`; actualiza orden, paradas y estado de la ruta.
- Evento `PedidoActualizado`: contiene un `PedidoDto`, pero actualmente se publica a los grupos por fecha y pedido, no al grupo del repartidor. Para recibirlo individualmente, invocar `SeguirPedido` con el id del pedido; para dejarlo, `DejarDeSeguirPedido`.

Para la pantalla del repartidor basta inicialmente con suscribirse a `RutaActualizada`, que incluye los pedidos de la ruta. No asumir que existe un evento `RutaAsignada` ni un evento GPS implementado.

Registrar los manejadores una sola vez. Al reconectar, volver a suscribirse al grupo del repartidor y a los pedidos que se sigan, y consultar la ruta por HTTP para recuperar cambios perdidos. Descartar mensajes de rutas ajenas a la pantalla actual y cerrar la conexión al cerrar sesión.

La pertenencia a grupos no sustituye la autorización: backend debe restringir el acceso según la identidad autenticada antes de usar datos reales.

## 6. Teléfono del cliente y navegación

- Agregar una acción que abra el marcador del teléfono con el número del cliente para que el usuario confirme la llamada.
- No se solicita realizar llamadas directas ni leer contactos. Si se propone ese alcance, revisar permisos y aprobación del equipo por separado.
- Para abrir el marcador o una app externa de navegación puede hacer falta un paquete adicional, como `url_launcher`; acordarlo antes de incorporarlo. Estas acciones no las resuelven `geolocator` ni `signalr_netcore`.
- El backend entrega coordenadas de destinos y orden de paradas, pero no geometría por calles ni tiempos estimados de viaje. Una línea entre paradas no debe presentarse como recorrido vial calculado.

## 7. Errores y configuración

- Configurar la URL base por entorno y usar HTTPS en despliegues reales.
- No incluir credenciales de PostgreSQL en Flutter: la app solo se comunica con la API.
- En un teléfono físico, `localhost` apunta al teléfono; configurar una dirección alcanzable del backend.
- Manejar 400 (datos inválidos), 404 (recurso o ruta activa inexistente), 409 (conflicto de estado/concurrencia), 422 (regla de negocio), fallos de red y errores del servidor.
- Cuando exista autenticación, manejar también 401/403 y enviar el token en HTTP y en la conexión SignalR.
- Mostrar un mensaje comprensible y recargar el estado tras conflictos. No repetir automáticamente acciones de entrega con resultado incierto sin consultar primero su estado.

## 8. Responsabilidades y dependencias

| Equipo | Trabajo |
|---|---|
| Flutter | Pantallas, permisos, GPS, segundo plano, envío HTTP, recepción SignalR, reconexión y marcador telefónico |
| Backend | Autenticación/autorización, endpoint GPS, validación, última posición, consulta inicial y evento GPS |
| Frontend web | Mostrar última ubicación, antigüedad de la muestra y actualizaciones del marcador por SignalR |
| Todos | Confirmar contrato GPS, entornos, frecuencia, comportamiento sin conexión y pruebas integradas |

La consulta de entregas y sus cambios de estado pueden integrarse con los endpoints actuales. El envío GPS completo depende de los cambios pendientes de backend.

## 9. Criterios de aceptación

- [ ] El repartidor consulta su ruta y las paradas se muestran en el orden recibido.
- [ ] Los botones respetan los estados y las respuestas del backend actualizan la pantalla.
- [ ] La entrega requiere confirmación y completar todos los pedidos finaliza la ruta.
- [ ] La app recibe cambios de ruta y recupera el estado después de una reconexión.
- [ ] Se prueban permisos aceptados, denegados, denegación permanente y GPS apagado.
- [ ] Con el contrato GPS implementado, una ruta en curso envía coordenadas con precisión y hora de captura.
- [ ] Se verifica el comportamiento con pantalla bloqueada y app en segundo plano en dispositivos físicos de las plataformas soportadas.
- [ ] La pérdida de internet es visible y la recuperación no genera una cola ilimitada ni posiciones falsamente recientes.
- [ ] El seguimiento se detiene al terminar el reparto o cerrar sesión.
- [ ] La llamada abre el marcador con el número correcto y requiere confirmación del usuario.
- [ ] Backend y web verifican juntos que el marcador se actualiza y muestra la antigüedad de la última posición.

## 10. Entregables solicitados a Flutter

1. Implementación en el repositorio móvil manteniendo su organización actual.
2. Instrucciones de configuración por plataforma y entorno, incluyendo permisos y limitaciones de segundo plano.
3. Pruebas de estados, errores, reconexión y permisos, más evidencia en dispositivo físico del seguimiento.
4. Lista de dependencias adicionales propuestas y confirmación del contrato GPS acordado con backend.
