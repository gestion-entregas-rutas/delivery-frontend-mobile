import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/auth_shell.dart';
import '../widgets/primary_button.dart';
import '../widgets/route/inline_notice.dart';
import '../widgets/status_chip.dart';

class ChangeCredentialsScreen extends StatefulWidget {
  const ChangeCredentialsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ChangeCredentialsScreen> createState() =>
      _ChangeCredentialsScreenState();
}

class _ChangeCredentialsScreenState extends State<ChangeCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _username = TextEditingController();
  final _newPassword = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _username.text = widget.auth.user?.nombreUsuario ?? '';
  }

  @override
  void dispose() {
    _current.dispose();
    _username.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  String? _passwordError(String? value) {
    final password = value ?? '';
    if (password.length < 12 || password.length > 128) {
      return 'Usa entre 12 y 128 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Incluye mayúscula, minúscula, número y símbolo';
    }
    if (password == _current.text) return 'La nueva clave debe ser diferente';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.auth.changeCredentials(
      currentPassword: _current.text,
      username: _username.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    _current.clear();
    _newPassword.clear();
    if (widget.auth.error == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(widget.auth.error!.message)));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar de cuenta'),
        content: const Text(
          'Cerrar sesión revoca todas las sesiones activas de esta cuenta. '
          '¿Quieres cerrar sesión y volver al acceso?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await widget.auth.logout();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      final saving = widget.auth.status == AuthStatus.changingCredentials;
      return AuthShell(
        showRoute: false,
        tagline: 'Un paso más y empiezas.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 30,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Crea tu clave nueva', style: AppText.title),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta tiene una clave temporal. Cámbiala para ver tu ruta.',
                style: AppText.body.copyWith(color: AppColors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _current,
                obscureText: true,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Clave actual',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 22),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingresa tu clave actual'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _username,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Nuevo nombre de usuario',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 22),
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().length < 3 ||
                        value.trim().length > 100
                    ? 'Usa entre 3 y 100 caracteres'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPassword,
                obscureText: _obscure,
                enabled: !saving,
                decoration: InputDecoration(
                  labelText: 'Nueva clave',
                  helperText: '12 o más caracteres, con mayúscula, minúscula, número y símbolo',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.key_outlined, size: 22),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostrar clave' : 'Ocultar clave',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: _passwordError,
              ),
              if (widget.auth.error != null) ...[
                const SizedBox(height: 16),
                InlineNotice(
                  status: AppStatus.error,
                  message: widget.auth.error!.message,
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Guardar y continuar',
                loading: saving,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: saving ? null : _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión y usar otra cuenta'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
