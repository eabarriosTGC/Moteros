import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_shell.dart';
import 'core/widgets/scanner_fab.dart';
import 'features/admin/data/datasources/admin_remote_datasource.dart';
import 'features/admin/domain/usecases/manage_allies.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/validation/presentation/screens/qr_scanner_screen.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/challenges/presentation/bloc/challenges_bloc.dart';
import 'features/refugios/presentation/bloc/refugios_bloc.dart';
import 'features/refugios/presentation/screens/refugios_screen.dart';
import 'features/membership/data/datasources/membership_remote_datasource.dart';
import 'features/membership/domain/usecases/activate_membership.dart';
import 'features/membership/presentation/bloc/membership_bloc.dart';
import 'features/places/data/datasources/place_remote_datasource.dart';
import 'features/places/domain/usecases/get_nearby_places.dart';
import 'features/places/presentation/bloc/places_bloc.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/raids/presentation/bloc/raid_bloc.dart';
import 'features/raids/presentation/screens/raid_list_screen.dart';
import 'features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'features/clans/presentation/bloc/clan_bloc.dart';
import 'features/clans/presentation/screens/clan_list_screen.dart';
import 'features/patches/presentation/bloc/patches_bloc.dart';
import 'features/tracker/presentation/screens/route_tracker_screen.dart';
import 'features/alerts/presentation/screens/radar_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/validation/data/datasources/validation_remote_datasource.dart';
import 'features/validation/domain/usecases/validate_visit.dart';
import 'features/validation/presentation/bloc/validation_bloc.dart';

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
        BlocProvider(
          create: (_) => PlacesBloc(
            getNearbyPlaces: GetNearbyPlacesUseCase(
              PlaceRemoteDataSource(apiClient),
            ),
          ),
        ),
        BlocProvider(
          create: (_) => ValidationBloc(
            validateVisit: ValidateVisitUseCase(
              ValidationRemoteDataSource(apiClient),
            ),
          ),
        ),
        BlocProvider(
          create: (_) => MembershipBloc(
            activateMembership: ActivateMembershipUseCase(
              MembershipRemoteDataSource(apiClient),
            ),
          ),
        ),
        BlocProvider(
          create: (_) => AdminBloc(
            manageAllies: ManageAlliesUseCase(AdminRemoteDataSource(apiClient)),
          ),
        ),
        BlocProvider(create: (_) => RaidBloc()),
        BlocProvider(create: (_) => ClanBloc()),
        BlocProvider(create: (_) => PatchesBloc()),
        BlocProvider(create: (_) => TrackerBloc()),
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
            // Unauthenticated or AuthError → show login
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

/// Wraps the authenticated experience: MainShell + ScannerFab overlay.
class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell();

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openScanner() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      body: const MainShell(
        dashboard: DashboardScreen(),
        raidScreen: RaidListScreen(),
        refugiosScreen: RefugiosScreen(),
        clanScreen: ClanListScreen(),
        profileScreen: ProfileScreen(),
        initialTab: AppTab.dashboard,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ScannerFab(onTap: _openScanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
