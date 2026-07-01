import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';

class MoterosApp extends StatelessWidget {
  const MoterosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moteros Colombia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
