// Copyright 2026 eabarriosTGC
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Create ApiClient (compatibility shim wrapping SupabaseClient)
  final apiClient = ApiClient();

  // Create AuthBloc and dispatch CheckAuthStatus immediately
  final authBloc = AuthBloc();
  authBloc.add(CheckAuthStatus());

  runApp(MoterosApp(
    apiClient: apiClient,
    authBloc: authBloc,
  ));
}
