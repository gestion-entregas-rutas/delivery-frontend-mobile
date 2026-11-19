import 'package:flutter/material.dart';

import '../../models/logistica_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/contact.dart';
import '../../utils/format.dart';
import '../status_chip.dart';

// Un artículo del checkout empieza con la cantidad: "2x Audífonos".
final RegExp _itemStart = RegExp(r'^\s*\d+\s*[xX×]\s+\S');
// Entre artículos hay ", " seguido de la cantidad del siguiente. Una coma que
// no va seguida de "1x ..." es parte del nombre y no corta.
final RegExp _itemSplit = RegExp(r',\s*(?=\d+\s*[xX×]\s+\S)');

/// Lo que dice `observaciones`: artículos o una nota libre.
class Observaciones {
  const Observaciones({this.items = const [], this.note});

  /// Artículos ("2x Audífonos"), cuando el pedido viene de la tienda.
  final List<String> items;

  /// Texto libre (pedidos creados a mano), que NO se parte por comas.
  final String? note;
}

/// Los pedidos de la tienda traen `"{cantidad}x {producto}"` separados por
/// `", "`; los creados a mano traen texto libre. Solo en el primer caso se
/// parte en artículos; el texto libre se deja entero.
Observaciones parseObservaciones(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return const Observaciones();
  if (!_itemStart.hasMatch(text)) return Observaciones(note: text);
  final items = <String>[
    for (final line in text.split('\n'))
      for (final item in line.split(_itemSplit))
        if (item.trim().isNotEmpty) item.trim(),
  ];
  return Observaciones(items: items);
}

/// Los artículos de un pedido (vacío si es texto libre).
List<String> parseStopItems(String? detalles) =>
    parseObservaciones(detalles).items;

/// La parada en la que está el repartidor: quién es, dónde, qué lleva y cómo
/// contactarlo. Es el bloque principal de la pantalla.
class CurrentStopCard extends StatelessWidget {
  const CurrentStopCard({
    super.key,
    required this.stop,
    required this.onCall,
    required this.onWhatsapp,
    required this.onShowMap,
  });

  final ParadaDto stop;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  /// Lleva al mapa interno con esta parada enfocada (sin salir de la app).
  final VoidCallback onShowMap;

  @override
  Widget build(BuildContext context) {
    final order = stop.pedido;
    final enRoute = order.estado == 'EnCamino';
    final obs = parseObservaciones(order.detalles);
    final items = obs.items;
    final note = obs.note;
    final cargo = _cargoChips(order);
    final phone = order.clienteTelefono.trim();
    final hasPhone = phone.isNotEmpty;
    final canWhatsapp = whatsappUri(phone) != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.brand, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6A1B9A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            status: AppStatus.active,
            label: enRoute ? 'En camino' : 'Siguiente parada',
          ),
          const SizedBox(height: 12),
          Text(order.clienteNombre, style: AppText.title),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.place_rounded,
                  size: 22,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.direccion,
                  style: AppText.body.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Fecha, hora y teléfono, cada uno en su propio campo.
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _InfoField(
                icon: Icons.calendar_today_rounded,
                label: 'Fecha',
                value: order.fechaEntrega,
              ),
              _InfoField(
                icon: Icons.schedule_rounded,
                label: 'Hora',
                value: shortTime(order.horaEntrega),
              ),
              if (hasPhone)
                _InfoField(
                  icon: Icons.phone_rounded,
                  label: 'Teléfono',
                  value: phone,
                ),
            ],
          ),
          if (items.isNotEmpty || note != null || cargo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        items.isNotEmpty
                            ? Icons.inventory_2_rounded
                            : note != null
                            ? Icons.sticky_note_2_rounded
                            : Icons.scale_rounded,
                        size: 18,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          items.isNotEmpty
                              ? 'Para entregar'
                              : note != null
                              ? 'Observaciones'
                              : 'Datos de la carga',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  // Nota libre del pedido (no se parte en artículos).
                  if (note != null)
                    Text(
                      note,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  // Frágil, prioridad, peso y tipo, solo los que tienen valor.
                  if (cargo.isNotEmpty) ...[
                    SizedBox(height: items.isEmpty && note == null ? 0 : 12),
                    Wrap(spacing: 8, runSpacing: 8, children: cargo),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                iconSize: 20,
              );
              final call = OutlinedButton.icon(
                style: compact,
                onPressed: hasPhone ? onCall : null,
                icon: const Icon(Icons.call_rounded),
                label: const Text('Llamar'),
              );
              final whatsapp = OutlinedButton.icon(
                style: compact,
                onPressed: canWhatsapp ? onWhatsapp : null,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              );
              // En pantallas muy angostas los botones van uno sobre otro para
              // que ninguno quede cortado.
              final stacked = constraints.maxWidth < 230;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stacked) ...[
                    call,
                    const SizedBox(height: 10),
                    whatsapp,
                  ] else
                    Row(
                      children: [
                        Expanded(child: call),
                        const SizedBox(width: 10),
                        Expanded(child: whatsapp),
                      ],
                    ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandSoft,
                      foregroundColor: AppColors.brand,
                      minimumSize: const Size(64, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppText.button.copyWith(fontSize: 15),
                    ),
                    onPressed: onShowMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Ver en el mapa'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Marcas de la carga que el repartidor debe saber: frágil, prioridad, peso y
/// tipo. Solo las que el pedido trae con valor; el resto no se muestra.
List<Widget> _cargoChips(PedidoDto order) => [
  if (order.fragil)
    const _CargoChip(
      icon: Icons.warning_amber_rounded,
      label: 'Frágil',
      warning: true,
    ),
  if (order.prioridad != null)
    _CargoChip(
      icon: Icons.flag_rounded,
      label: 'Prioridad: ${order.prioridad}',
      // Urgente y Alta se resaltan: hay que entregarlos primero.
      warning: const {
        'urgente',
        'alta',
      }.contains(order.prioridad!.toLowerCase()),
    ),
  if (order.pesoKg != null)
    _CargoChip(icon: Icons.scale_rounded, label: formatWeight(order.pesoKg!)),
  if (order.tipoCarga != null)
    _CargoChip(icon: Icons.category_rounded, label: order.tipoCarga!),
];

class _CargoChip extends StatelessWidget {
  const _CargoChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;

  /// Frágil va en ámbar: es lo que más importa al manipular el paquete.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.amber : AppColors.brandDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warning ? AppColors.amberSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label, style: AppText.label.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Un dato con su etiqueta: "Hora / 09:00".
class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.brand),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.label.copyWith(color: AppColors.grey)),
              Text(
                value,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
