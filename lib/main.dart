import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/datasources/firebase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Inicializar Google Sign-In
  final firebaseAuthService = FirebaseAuthService();
  await firebaseAuthService.initialize();

  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  final apiClient = ApiClient(baseUrl: baseUrl);

  runApp(MoterosApp(
    apiClient: apiClient,
    firebaseAuthService: firebaseAuthService,
  ));
}
