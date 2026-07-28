import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'core/widgets/main_shell.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/dashboard/presentation/screens/rodar_screen.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
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
        BlocProvider(create: (_) => DashboardBloc(apiClient: apiClient)),
        BlocProvider(create: (_) => ChallengesBloc(apiClient: apiClient)),
        BlocProvider(create: (_) => RefugiosBloc()),
        BlocProvider(create: (_) => MotoposadasBloc()),
        BlocProvider(create: (_) => PlacesBloc(
          getNearbyPlaces: GetNearbyPlacesUseCase(
            PlaceRemoteDataSource(apiClient),
          ),
        )),
        BlocProvider(
          create: (_) => RaidBloc(),
        ),
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
      child: MaterialApp(
        title: 'AsfaltoClub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthInitial) {
              return const SplashScreen();
            }
            if (state is AuthLoading) {
              return const SplashScreen();
            }
            if (state is Authenticated) {
              return const _AuthenticatedShell();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell();

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final done = meta?['onboarding_complete'] == true;
    if (mounted) setState(() => _onboardingComplete = done);
  }

  Future<void> _showOnboarding() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
    if (result == true && mounted) {
      setState(() => _onboardingComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Onboarding gate — show onboarding if not yet completed
    if (_onboardingComplete == false) {
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
    if (_onboardingComplete == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator()),
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
