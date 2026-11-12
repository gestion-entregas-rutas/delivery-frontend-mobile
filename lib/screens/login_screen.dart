import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../config/api_config.dart';
import '../data/api/api_client.dart';
import 'animated_route.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});

  final AuthController? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  late final AuthController _auth;
  late final bool _ownsAuth;
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.auth != null) {
      _auth = widget.auth!;
      _ownsAuth = false;
    } else {
      late AuthController controller;
      final api = ApiClient(
        baseUrl: ApiConfig.baseUrl,
        accessTokenProvider: () => controller.accessToken,
        onUnauthorized: (token) => controller.handleUnauthorized(token),
      );
      controller = AuthController(api: api);
      _auth = controller;
      _ownsAuth = true;
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    if (_ownsAuth) {
      _auth.dispose();
      _auth.api.close();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final password = _password.text;
    await _auth.login(username: _user.text, password: password);
    if (!mounted) return;
    _password.clear();
    setState(() => _loading = false);
    if (_auth.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_auth.error!.message)));
    }
  }

  void _help() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.support_agent_rounded, size: 36),
            SizedBox(height: 16),
            Text(
              '¿Necesitas acceso?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              'Solicita al administrador de tu negocio las credenciales de conductor. La aplicación no crea cuentas ni almacena tu contraseña.',
            ),
          ],
        ),
      ),
    ),
  );

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF6F6F2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Row(
                        children: [
                          Icon(Icons.route_rounded, size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kAppName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.8,
                              ),
                            ),
                          ),
                          Icon(Icons.local_shipping_outlined),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: keyboard
                          ? 90
                          : (constraints.maxHeight * .30).clamp(150.0, 260.0),
                      child: const AnimatedRoute(),
                    ),
                    Container(
                      constraints: BoxConstraints(
                        minHeight: keyboard ? 0 : constraints.maxHeight * .62,
                      ),
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(36),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACCESO DEL REPARTIDOR',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF666A56),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Tu ruta,\nen marcha.',
                              style: TextStyle(
                                fontSize: 32,
                                height: 1.08,
                                letterSpacing: -1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ingresa con las credenciales entregadas por tu administrador para consultar tu ruta.',
                              style: TextStyle(
                                color: Color(0xFF64665E),
                                height: 1.5,
                              ),
                            ),
                            if (_auth.lastWarning != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF2D6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _auth.lastWarning!,
                                  style: const TextStyle(
                                    color: Color(0xFF704C00),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 26),
                            TextFormField(
                              controller: _user,
                              enabled: !_loading,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: _decoration(
                                'Usuario o correo',
                                Icons.person_outline_rounded,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Ingresa tu usuario o correo'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              enabled: !_loading,
                              obscureText: _obscure,
                              autocorrect: false,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _continue(),
                              decoration: _decoration(
                                'Contraseña',
                                Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: _obscure
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Ingresa tu contraseña'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _help,
                                child: const Text(
                                  '¿Necesitas ayuda?',
                                  style: TextStyle(color: AppColors.ink),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton(
                                onPressed: _loading ? null : _continue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.ink,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Center(
                              child: Text(
                                'La contraseña solo se usa para autenticarte y nunca se guarda en el dispositivo.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
