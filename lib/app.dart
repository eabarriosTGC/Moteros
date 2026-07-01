import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/places/data/datasources/place_remote_datasource.dart';
import 'features/places/domain/usecases/get_nearby_places.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/places/presentation/bloc/places_bloc.dart';
import 'features/places/presentation/screens/map_explorer_screen.dart';

class MoterosApp extends StatelessWidget {
  final ApiClient apiClient;

  const MoterosApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    final placeDataSource = PlaceRemoteDataSource(apiClient);
    final getNearbyPlaces = GetNearbyPlacesUseCase(placeDataSource);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(apiClient: apiClient)),
        BlocProvider(create: (_) => PlacesBloc(getNearbyPlaces: getNearbyPlaces)),
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
