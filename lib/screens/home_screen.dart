import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

// ---------------------------------------------------------------------------
// Paleta inspirada en el diseño de Beeway: amarillo + negro + blanco.
// Si luego quieres mover esto a core/theme/, solo corta y pega la clase.
// ---------------------------------------------------------------------------
class AppColors {
  static const yellow = Color(0xFFFFC107);
  static const yellowSoft = Color(0xFFFFF4CC);
  static const ink = Color(0xFF111111);
  static const grey = Color(0xFF8A8A8A);
  static const surface = Color(0xFFF3F3F3);
  static const border = Color(0xFFEDEDED);
  static const green = Color(0xFF2E9E5B);
}

// Nombre de la app, único y compartido por splash/login/home.
// Cámbialo aquí por el real cuando esté definido.
const String kAppName = 'RutaExpress';

enum OrderStatus { pendiente, enCamino, entregado }

class DeliveryOrder {
  final String id;
  final String client;
  final String address;
  final String time;
  OrderStatus status;

  DeliveryOrder({
    required this.id,
    required this.client,
    required this.address,
    required this.time,
    this.status = OrderStatus.pendiente,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Datos de prueba simulando la ruta del día
  final List<DeliveryOrder> _orders = [
    DeliveryOrder(id: '#1024', client: 'María López', address: 'Av. Siempre Viva 742', time: '09:30'),
    DeliveryOrder(id: '#1025', client: 'Juan Pérez', address: 'Calle Falsa 123', time: '10:00'),
    DeliveryOrder(id: '#1026', client: 'Ana Torres', address: 'Boulevard de los Sueños Rotos', time: '10:45'),
    DeliveryOrder(id: '#1027', client: 'Luis Mora', address: 'Paseo de la Reforma 222', time: '11:30'),
    DeliveryOrder(id: '#1028', client: 'Sofía Ruiz', address: 'Wallaby 42, Sydney', time: '12:15'),
    DeliveryOrder(id: '#1029', client: 'Pedro Gil', address: 'Abbey Road', time: '13:00'),
  ];

  OrderStatus? _filter; // null = Todos
  int _navIndex = 0;

  int _count(OrderStatus s) => _orders.where((o) => o.status == s).length;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _advance(DeliveryOrder order) {
    setState(() {
      if (order.status == OrderStatus.pendiente) {
        order.status = OrderStatus.enCamino;
      } else if (order.status == OrderStatus.enCamino) {
        order.status = OrderStatus.entregado;
      }
    });
    // TODO: aquí se enviaría el cambio de estado al sistema central.
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _orders.where((o) => _filter == null || o.status == _filter).toList();
    final done = _count(OrderStatus.entregado);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: _Header(greeting: _greeting, name: 'Carlos'),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 100),
              child: _RouteSummaryCard(done: done, total: _orders.length),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 200),
              child: _FilterChips(
                selected: _filter,
                total: _orders.length,
                countOf: _count,
                onSelected: (s) => setState(() => _filter = s),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'Entregas de hoy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  'Ver mapa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No hay entregas en este estado',
                    style: TextStyle(color: AppColors.grey),
                  ),
                ),
              ),
            for (var i = 0; i < visible.length; i++)
              FadeInUp(
                // La key incluye el filtro para que la cascada se repita al filtrar.
                key: ValueKey('${visible[i].id}-${_filter?.name}'),
                duration: const Duration(milliseconds: 500),
                delay: Duration(milliseconds: 80 * i),
                child: _OrderCard(
                  order: visible[i],
                  stop: _orders.indexOf(visible[i]) + 1,
                  onAction: () => _advance(visible[i]),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.yellowSoft,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.ink),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded, color: AppColors.ink),
            label: 'Ruta',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppColors.ink),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.ink),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado: saludo + estado del repartidor + campana
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  final String greeting;
  final String name;
  const _Header({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.yellowSoft,
          child: Icon(Icons.person_rounded, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Icon(Icons.circle, size: 8, color: AppColors.green),
                  SizedBox(width: 6),
                  Text(
                    'En servicio · Zona Norte',
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              color: AppColors.ink),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta oscura (equivalente a la promo "30% off") con el progreso de la ruta
// ---------------------------------------------------------------------------
class _RouteSummaryCard extends StatelessWidget {
  final int done;
  final int total;
  const _RouteSummaryCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            bottom: -4,
            child: Icon(
              Icons.local_shipping_rounded,
              size: 84,
              color: Colors.white.withAlpha(25),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Ruta de hoy',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$done de $total entregas',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Salida 08:30 · Capacidad máx. $total pedidos',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(160),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withAlpha(35),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.yellow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chips de filtro por estado (equivalente a las categorías Taxi/Premium/...)
// ---------------------------------------------------------------------------
class _FilterChips extends StatelessWidget {
  final OrderStatus? selected;
  final int total;
  final int Function(OrderStatus) countOf;
  final ValueChanged<OrderStatus?> onSelected;

  const _FilterChips({
    required this.selected,
    required this.total,
    required this.countOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<OrderStatus?, String>>[
      MapEntry(null, 'Todos ($total)'),
      MapEntry(OrderStatus.pendiente,
          'Pendientes (${countOf(OrderStatus.pendiente)})'),
      MapEntry(OrderStatus.enCamino,
          'En camino (${countOf(OrderStatus.enCamino)})'),
      MapEntry(OrderStatus.entregado,
          'Entregados (${countOf(OrderStatus.entregado)})'),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final isSelected = selected == items[i].key;
          return GestureDetector(
            onTap: () => onSelected(items[i].key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Text(
                items[i].value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de pedido (equivalente a las tarjetas "Available cars" + botón Book)
// ---------------------------------------------------------------------------
class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final int stop;
  final VoidCallback onAction;

  const _OrderCard({
    required this.order,
    required this.stop,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.yellowSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$stop',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido ${order.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.client,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text(
                      order.time,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _ActionButton(status: order.status, onPressed: onAction),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case OrderStatus.pendiente:
        label = 'Pendiente';
        bg = AppColors.yellowSoft;
        fg = const Color(0xFF9A6B00);
        break;
      case OrderStatus.enCamino:
        label = 'En camino';
        bg = const Color(0xFFE3F0FF);
        fg = const Color(0xFF1B5FAA);
        break;
      case OrderStatus.entregado:
        label = 'Entregado';
        bg = const Color(0xFFE2F5EA);
        fg = AppColors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback onPressed;
  const _ActionButton({required this.status, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.entregado) {
      return Row(
        children: const [
          Icon(Icons.check_circle_rounded, size: 20, color: AppColors.green),
          SizedBox(width: 6),
          Text(
            'Completado',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
        ],
      );
    }

    final isStart = status == OrderStatus.pendiente;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isStart ? AppColors.yellow : AppColors.ink,
        foregroundColor: isStart ? AppColors.ink : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        isStart ? 'Iniciar →' : 'Marcar entregado',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }
}