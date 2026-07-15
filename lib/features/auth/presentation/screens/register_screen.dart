import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/theme/design_tokens.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _codeValid = false;
  String? _codeClubName;
  bool _checkingCode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_codeValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Validá el código de invitación primero')),
        );
        return;
      }
      context.read<AuthBloc>().add(RegisterRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          ));
    }
  }

  Future<void> _validateCode() async {
    final code = _inviteCodeController.text.trim();
    if (code.length < 4) return;
    setState(() => _checkingCode = true);
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'validate-invite-code',
        body: {'code': code},
      );
      final data = result.data as Map<String, dynamic>;
      if (data['valid'] == true) {
        setState(() {
          _codeValid = true;
          _codeClubName = data['club_name'] as String?;
        });
      } else {
        setState(() {
          _codeValid = false;
          _codeClubName = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Código inválido')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _codeValid = false;
        _codeClubName = null;
      });
    } finally {
      if (mounted) setState(() => _checkingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Crear cuenta'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.motorcycle,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Únete a AsfaltoClub',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu cuenta de motero',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Name
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.input,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 16),
                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.input,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Ingresa tu email' : null,
                  ),
                  const SizedBox(height: 16),
                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.input,
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Ingresa tu contraseña'
                        : null,
                    onFieldSubmitted: (_) => _onRegister(),
                  ),
                  const SizedBox(height: 16),
                  // Invite code
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _inviteCodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Código de invitación',
                          hintText: 'Ej: ABC12345',
                          hintStyle: const TextStyle(color: AppColors.textDisabled),
                          prefixIcon: const Icon(Icons.vpn_key, color: AppColors.textMuted),
                          suffixIcon: _checkingCode
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : (_codeValid
                                  ? const Icon(Icons.check_circle, color: AppColors.success)
                                  : null),
                          filled: true, fillColor: AppColors.input,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) {
                          if (_codeValid) setState(() { _codeValid = false; _codeClubName = null; });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _checkingCode ? null : _validateCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _codeValid ? AppColors.success : AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                        ),
                        child: const Text('VALIDAR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ]),
                  if (_codeClubName != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.check, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text('Club: $_codeClubName',
                        style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  // Register button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _onRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.metallicDark,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mdCircular,
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Registrarse',
                                  style: AppTypography.button.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Back to login
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text.rich(
                      TextSpan(
                        text: '¿Ya tienes cuenta? ',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                        children: [
                          TextSpan(
                            text: 'Inicia sesión',
                            style: AppTypography.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
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
    );
  }
}
