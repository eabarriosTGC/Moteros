import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 750), vsync: this);
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(LoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: _LoginBackground()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BrandHeader(),
                            const SizedBox(height: 38),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withAlpha(235),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.borderLight.withAlpha(180)),
                                boxShadow: AppShadows.elevated,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bienvenido de vuelta', style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
                                  const SizedBox(height: 6),
                                  Text('Tu próxima ruta empieza aquí.', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                                  const SizedBox(height: 22),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    style: const TextStyle(color: AppColors.textPrimary),
                                    decoration: const InputDecoration(
                                      labelText: 'Correo electrónico',
                                      prefixIcon: Icon(Icons.alternate_email_rounded),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu correo' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _hidePassword,
                                    autofillHints: const [AutofillHints.password],
                                    style: const TextStyle(color: AppColors.textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                        icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                      ),
                                    ),
                                    onFieldSubmitted: (_) => _onLogin(),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      final isLoading = state is AuthLoading;
                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: isLoading ? null : AppGradients.primaryButton,
                                          borderRadius: AppRadius.mdCircular,
                                          boxShadow: isLoading ? null : AppShadows.amberGlow,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: isLoading ? null : _onLogin,
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                          child: isLoading
                                              ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                              : const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('Entrar a Moteros'),
                                                    SizedBox(width: 9),
                                                    Icon(Icons.arrow_forward_rounded, size: 19),
                                                  ],
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              child: const Text('Crear una cuenta nueva'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppShadows.amberGlow,
          ),
          child: const Icon(Icons.two_wheeler_rounded, size: 41, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text('MOTEROS', style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimary, letterSpacing: 4.5)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(18),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.secondary.withAlpha(55)),
          ),
          child: Text('RUTA · COMUNIDAD · AVENTURA', style: AppTypography.caption.copyWith(color: AppColors.secondaryLight, letterSpacing: 1.1)),
        ),
      ],
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.dashboard),
      child: Stack(
        children: [
          Positioned(top: -90, right: -80, child: _GlowOrb(size: 250, color: AppColors.primary)),
          Positioned(bottom: 70, left: -100, child: _GlowOrb(size: 220, color: AppColors.secondary)),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(20), boxShadow: [BoxShadow(color: color.withAlpha(25), blurRadius: 90, spreadRadius: 30)]),
    );
  }
}
