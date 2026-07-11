import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.8, curve: Curves.easeInOut)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _pulse,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Central glow + logo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Amber glow background circle
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.amberGlow,
                      ),
                    ),
                    // Logo icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface.withAlpha(180),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(80),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.motorcycle,
                        size: 52,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // ASFALTOCLUB — Space Grotesk, amber, glow
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    boxShadow: AppShadows.amberGlow,
                  ),
                  child: Text(
                    'ASFALTOCLUB',
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // BATTLE RIDE — cyan subtitle
                Text(
                  'BATTLE RIDE',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.secondary,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading indicator — amber
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
