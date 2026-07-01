import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  final apiClient = ApiClient(baseUrl: baseUrl);

  runApp(MoterosApp(apiClient: apiClient));
}
