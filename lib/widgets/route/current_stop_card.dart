import 'package:flutter/material.dart';

import '../../models/logistica_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/contact.dart';
import '../status_chip.dart';

/// Separa el resumen de artículos ("2 × Vela, 1 × Jabón") en una lista de
/// líneas, por comas o saltos de línea.
List<String> parseStopItems(String? detalles) => (detalles ?? '')
    .split(RegExp(r'[\n,]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

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
    final items = parseStopItems(order.detalles);
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
          if (items.isNotEmpty) ...[
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
                      const Icon(
                        Icons.inventory_2_rounded,
                        size: 18,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Para entregar',
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
