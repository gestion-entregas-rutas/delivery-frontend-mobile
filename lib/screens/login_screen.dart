import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../config/api_config.dart';
import '../data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/auth_shell.dart';
import '../widgets/primary_button.dart';
import '../widgets/route/inline_notice.dart';
import '../widgets/status_chip.dart';

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
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 30,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            const Text('¿Necesitas acceso?', style: AppText.title),
            const SizedBox(height: 10),
            Text(
              'Pide a tu administrador las credenciales de repartidor. La app no crea cuentas ni guarda tu contraseña.',
              style: AppText.body.copyWith(color: AppColors.grey),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AuthShell(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Hola de nuevo', style: AppText.title),
          const SizedBox(height: 8),
          Text(
            'Ingresa con las credenciales que te dio tu administrador para ver tu ruta de hoy.',
            style: AppText.body.copyWith(color: AppColors.grey),
          ),
          if (_auth.lastWarning != null) ...[
            const SizedBox(height: 16),
            InlineNotice(
              status: AppStatus.warning,
              message: _auth.lastWarning!,
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _user,
            enabled: !_loading,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Usuario o correo',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 22),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ingresa tu usuario o correo'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            enabled: !_loading,
            obscureText: _obscure,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _continue(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Ingresa tu contraseña' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _help,
              child: const Text('¿Necesitas ayuda?'),
            ),
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Iniciar sesión',
            loading: _loading,
            onPressed: _continue,
          ),
          const SizedBox(height: 18),
          Text(
            'Tu contraseña solo se usa para entrar y nunca se guarda en el teléfono.',
            style: AppText.label.copyWith(
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
