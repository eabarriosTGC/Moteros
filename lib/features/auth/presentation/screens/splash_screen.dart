import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: .88, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) context.read<AuthBloc>().add(CheckAuthStatus());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.dashboard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(top: -100, right: -100, child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(18), boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(28), blurRadius: 110, spreadRadius: 35)]))),
            Positioned(bottom: -110, left: -90, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary.withAlpha(14), boxShadow: [BoxShadow(color: AppColors.secondary.withAlpha(18), blurRadius: 100, spreadRadius: 30)]))),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(31),
                        child: Image.asset(
                          'icon.jpeg',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text('MOTEROS', style: AppTypography.displayMedium.copyWith(color: AppColors.textPrimary, letterSpacing: 6)),
                      const SizedBox(height: 8),
                      Text('TU RUTA. TU COMUNIDAD.', style: AppTypography.label.copyWith(color: AppColors.secondaryLight, letterSpacing: 2.1)),
                      const SizedBox(height: 38),
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryLight)),
                    ],
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
