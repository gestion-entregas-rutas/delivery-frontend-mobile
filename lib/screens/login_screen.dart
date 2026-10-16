import 'package:flutter/material.dart';

import 'animated_route.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    // Demo only: replace with the central authentication service.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
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
              'Te ayudamos a volver a tu ruta',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              'Contacta al administrador de tu negocio para recuperar tu acceso o solicitar una cuenta de conductor.',
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
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TU DÍA, EN MARCHA',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF666A56),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Cada entrega\nempieza contigo.',
                                style: TextStyle(
                                  fontSize: 32,
                                  height: 1.08,
                                  letterSpacing: -1.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Ingresa para consultar tu ruta y empezar el recorrido.',
                                style: TextStyle(
                                  color: Color(0xFF64665E),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 26),
                              TextFormField(
                                controller: _user,
                                enabled: !_loading,
                                autofillHints: const [AutofillHints.username],
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: _decoration(
                                  'Usuario o correo',
                                  Icons.person_outline_rounded,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Ingresa tu usuario o correo'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _password,
                                enabled: !_loading,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
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
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Ingresa tu contraseña'
                                    : null,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _help,
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(color: AppColors.ink),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed: _loading ? null : _login,
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
                                            color: AppColors.yellow,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Iniciar recorrido',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Center(
                                child: Text(
                                  'Vista de demostración · acceso simulado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64665E),
                                  ),
                                ),
                              ),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _help,
                                  icon: const Icon(
                                    Icons.support_agent_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('¿Necesitas ayuda?'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF64665E),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: MediaQuery.paddingOf(context).bottom,
                              ),
                            ],
                          ),
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
