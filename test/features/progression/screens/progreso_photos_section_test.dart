/// _PhotosSection test — M-CPU-4 re-homed into Progreso (fix B1).
///
/// STRICT TDD: written BEFORE `ProgresoLoaded.photos` exists (RED by
/// construction — the fixtures reference the photos parameter that the
/// state does not carry yet). Asserts the section renders the existing
/// stateless `PhotoAlbum` from the SAME list the bloc already selects
/// (progreso_bloc.dart:30) — no parallel photo source — and collapses to
/// SizedBox.shrink when the list is empty.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:moteros_app/features/patches/presentation/bloc/patches_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_event.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_state.dart';
import 'package:moteros_app/features/progression/presentation/screens/progreso_screen.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/showcase/data/models/conquest_photo_model.dart';
import 'package:moteros_app/features/showcase/presentation/widgets/photo_album.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SeededProgresoBloc extends ProgresoBloc {
  @override
  void add(ProgresoEvent event) {}

  void seed(ProgresoState state) => emit(state);
}

class _SeededMotoposadasBloc extends MotoposadasBloc {
  _SeededMotoposadasBloc() : super(client: _FakeSupabaseClient());

  @override
  void add(MotoposadasEvent event) {}

  void seed(MotoposadasState state) => emit(state);
}

class _SeededPatchesBloc extends PatchesBloc {
  @override
  void add(PatchesEvent event) {}
}

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ConquestPhotoModel _photo(String id) => ConquestPhotoModel(
  id: id,
  userId: 'u1',
  source: 'raid',
  sourceId: '42',
  photoUrl: 'https://example.com/$id.jpg',
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<void> _pumpProgreso(
  WidgetTester tester, {
  required List<ConquestPhotoModel> photos,
}) async {
  await tester.runAsync(
    () => Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'fake-anon-key',
    ),
  );
  addTearDown(() async {
    await tester.runAsync(() => Supabase.instance.dispose());
  });

  final progresoBloc = _SeededProgresoBloc()
    ..seed(ProgresoLoaded(totalKm: 12, tripsCount: 2, photos: photos));
  final motoposadasBloc = _SeededMotoposadasBloc()
    ..seed(MyMotoposadasLoaded(motoposadas: const []));

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ProgresoBloc>.value(value: progresoBloc),
        BlocProvider<MotoposadasBloc>.value(value: motoposadasBloc),
        BlocProvider<PatchesBloc>(create: (_) => _SeededPatchesBloc()),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: const MaterialApp(home: ProgresoScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProgresoLoaded with N photos renders PhotoAlbum (M-CPU-4, '
      'fix B1)', (tester) async {
    await _pumpProgreso(tester, photos: [_photo('1'), _photo('2')]);

    expect(
      find.byType(PhotoAlbum),
      findsOneWidget,
      reason:
          'the re-homed album must render inside Progreso (B1: the only '
          'previous mount — ShowcaseProfileScreen — became unreachable)',
    );
    expect(find.text('ÁLBUM DE CONQUISTAS'), findsOneWidget);
    expect(
      find.text('2 fotos'),
      findsOneWidget,
      reason: 'the album counter derives from the same photos list',
    );
  });

  testWidgets('no photos → the section collapses (SizedBox.shrink) (M-CPU-4)', (
    tester,
  ) async {
    await _pumpProgreso(tester, photos: const []);

    expect(
      find.text('ÁLBUM DE CONQUISTAS'),
      findsNothing,
      reason:
          'empty photos list must collapse the section (PhotoAlbum '
          'returns SizedBox.shrink)',
    );
    expect(find.byType(PhotoAlbum), findsOneWidget);
  });
}
