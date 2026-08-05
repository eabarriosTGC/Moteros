import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/network/api_client.dart';
import 'core/onboarding/profile_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'core/theme/theme_cubit.dart';
import 'core/widgets/main_shell.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/dashboard/presentation/screens/rodar_screen.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/dashboard/presentation/bloc/search_bloc.dart';
import 'features/dashboard/data/datasources/nominatim_datasource.dart';
import 'features/challenges/presentation/bloc/challenges_bloc.dart';
import 'features/refugios/presentation/bloc/refugios_bloc.dart';
import 'features/places/data/datasources/place_remote_datasource.dart';
import 'features/places/domain/usecases/get_nearby_places.dart';
import 'features/places/presentation/bloc/places_bloc.dart';
import 'features/raids/presentation/bloc/raid_bloc.dart';
import 'features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'features/patches/presentation/bloc/patches_bloc.dart';
import 'features/tracker/presentation/screens/route_tracker_screen.dart';
import 'features/routes/data/datasources/route_datasource.dart';
import 'features/routes/presentation/bloc/route_bloc.dart';
import 'features/mileage/presentation/bloc/mileage_bloc.dart';
import 'features/progression/presentation/bloc/leaderboard_bloc.dart';
import 'features/showcase/presentation/bloc/showcase_bloc.dart';
import 'features/progression/presentation/bloc/progreso_bloc.dart';
import 'features/progression/presentation/screens/progreso_screen.dart';
import 'features/explorar/presentation/bloc/explorar_bloc.dart';
import 'features/explorar/presentation/screens/explorar_screen.dart';

class MoterosApp extends StatelessWidget {
  final ApiClient apiClient;
  final AuthBloc authBloc;

  const MoterosApp({
    super.key,
    required this.apiClient,
    required this.authBloc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider(
          create: (_) => SearchBloc(datasource: NominatimDatasource()),
        ),
        BlocProvider(create: (_) => DashboardBloc(apiClient: apiClient)),
        BlocProvider(create: (_) => ChallengesBloc(apiClient: apiClient)),
        BlocProvider(create: (_) => RefugiosBloc()),
        BlocProvider(create: (_) => MotoposadasBloc()),
        BlocProvider(
          create: (_) => PlacesBloc(
            getNearbyPlaces: GetNearbyPlacesUseCase(
              PlaceRemoteDataSource(apiClient),
            ),
          ),
        ),
        BlocProvider(create: (_) => RaidBloc()),
        BlocProvider(create: (_) => PatchesBloc()),
        BlocProvider(create: (_) => TrackerBloc()),
        // New F-29 to F-35 BLoCs
        BlocProvider(create: (_) => RouteBloc(datasource: RouteDatasource())),
        BlocProvider(create: (_) => MileageBloc()),
        BlocProvider(create: (_) => LeaderboardBloc()),
        BlocProvider(create: (_) => ShowcaseBloc()),
        BlocProvider(create: (_) => ProgresoBloc()),
        BlocProvider(create: (_) => ExplorarBloc()),
      ],
      child: BlocProvider<ThemeCubit>(
        create: (_) => ThemeCubit(),
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) => MaterialApp(
            title: 'AsfaltoClub',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            darkTheme: AppTheme.dark,
            theme: AppTheme.light,
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthInitial) {
                  return const SplashScreen();
                }
                if (state is AuthLoading) {
                  return const SplashScreen();
                }
                if (state is Authenticated) {
                  return const AuthenticatedShell();
                }
                return const LoginScreen();
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Gate state for the first-access profile check (F-M12, ADR-001).
/// Decided by the ACTUAL users row (full_name/bike_model/city), never by the
/// `onboarding_complete` metadata boolean.
enum _GateState { loading, complete, incomplete, error }

class AuthenticatedShell extends StatefulWidget {
  /// Injectable for tests; defaults to the app-wide Supabase client.
  final SupabaseClient? client;

  const AuthenticatedShell({super.key, this.client});

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _GateState _gateState = _GateState.loading;

  SupabaseClient get _db => widget.client ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  /// Queries the users row and derives gate state from real field presence.
  /// Row missing (null) → incomplete (onboarding upsert recreates it).
  Future<void> _checkOnboarding() async {
    if (_gateState != _GateState.loading) {
      setState(() => _gateState = _GateState.loading);
    }
    try {
      final row = await _db
          .from('users')
          .select('full_name, bike_model, city')
          .eq('id', _db.auth.currentUser!.id)
          .maybeSingle();
      final complete = isProfileComplete(
        fullName: row?['full_name'] as String?,
        bikeModel: row?['bike_model'] as String?,
        city: row?['city'] as String?,
      );
      if (mounted) {
        setState(
          () => _gateState = complete
              ? _GateState.complete
              : _GateState.incomplete,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _gateState = _GateState.error);
    }
  }

  Future<void> _showOnboarding() async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    // Re-query the users row on return — the query result IS the state.
    // NEVER setState(true) here (phantom-flag bug class, ADR-001).
    if (mounted) {
      await _checkOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Onboarding gate — show onboarding if profile fields are incomplete
    if (_gateState == _GateState.incomplete) {
      // Show onboarding in a non-blocking way
      Future.microtask(() {
        if (mounted) _showOnboarding();
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Still loading onboarding status
    if (_gateState == _GateState.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Gate query failed (network/RLS) — retry, never loop silently
    if (_gateState == _GateState.error) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No pudimos verificar tu perfil',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Revisá tu conexión e intentá de nuevo',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _checkOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnAmber,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdCircular,
                    ),
                  ),
                  child: const Text('REINTENTAR'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      body: MainShell(
        rodarScreen: const RodarScreen(),
        progresoScreen: const ProgresoScreen(),
        explorarScreen: const ExplorarScreen(),
        initialTab: AppTab.rodar,
      ),
    );
  }
}

/// Temporary placeholder for screens not yet migrated to the 3-tab layout.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          label,
          style: AppTypography.h1.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
