import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'home_screen.dart';

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
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.yellow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_reset_rounded,
                          size: 44,
                          color: AppColors.ink,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Cambia tus credenciales',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tu cuenta tiene una clave temporal. Debes actualizarla antes de consultar la ruta.',
                          style: TextStyle(color: AppColors.grey, height: 1.45),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _current,
                          obscureText: true,
                          enabled:
                              widget.auth.status !=
                              AuthStatus.changingCredentials,
                          decoration: const InputDecoration(
                            labelText: 'Clave actual',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingresa tu clave actual'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _username,
                          enabled:
                              widget.auth.status !=
                              AuthStatus.changingCredentials,
                          decoration: const InputDecoration(
                            labelText: 'Nuevo nombre de usuario',
                            prefixIcon: Icon(Icons.person_outline),
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
                          enabled:
                              widget.auth.status !=
                              AuthStatus.changingCredentials,
                          decoration: InputDecoration(
                            labelText: 'Nueva clave',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: _passwordError,
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed:
                                widget.auth.status ==
                                    AuthStatus.changingCredentials
                                ? null
                                : _submit,
                            child:
                                widget.auth.status ==
                                    AuthStatus.changingCredentials
                                ? const CircularProgressIndicator()
                                : const Text('Guardar y continuar'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton.icon(
                            onPressed:
                                widget.auth.status ==
                                    AuthStatus.changingCredentials
                                ? null
                                : _logout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'Cerrar sesión y usar otra cuenta',
                            ),
                          ),
                        ),
                        if (widget.auth.error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            widget.auth.error!.message,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
