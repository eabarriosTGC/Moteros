import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/data/datasources/admin_remote_datasource.dart';
import 'features/admin/domain/usecases/manage_allies.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/membership/data/datasources/membership_remote_datasource.dart';
import 'features/membership/domain/usecases/activate_membership.dart';
import 'features/membership/presentation/bloc/membership_bloc.dart';
import 'features/places/data/datasources/place_remote_datasource.dart';
import 'features/places/domain/usecases/get_nearby_places.dart';
import 'features/places/presentation/bloc/places_bloc.dart';
import 'features/places/presentation/screens/map_explorer_screen.dart';
import 'features/validation/data/datasources/validation_remote_datasource.dart';
import 'features/validation/domain/usecases/validate_visit.dart';
import 'features/validation/presentation/bloc/validation_bloc.dart';

class MoterosApp extends StatelessWidget {
  final ApiClient apiClient;

  const MoterosApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(apiClient: apiClient)),
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
            manageAllies: ManageAlliesUseCase(
              AdminRemoteDataSource(apiClient),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Moteros Colombia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is Authenticated) {
              return const MapExplorerScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
