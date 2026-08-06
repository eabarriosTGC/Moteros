/// CasaMotero create/edit form widget tests — F-M9 (M-CRUD-1/3/4/5).
///
/// STRICT TDD: these tests reference `CreateMotoposadaMode.casaMotero` and
/// the casa_motero field set BEFORE the screen implements them — they must
/// FAIL (compile) until task 4.2 lands.
///
/// Covered:
/// - renders alias/desc/capacity/WhatsApp/disponible/map-picker (M-CRUD-5)
/// - NO address field, NO cédula field (M-CRUD-4)
/// - disclaimer unchecked → submit blocked + validation message (M-CRUD-3)
/// - disclaimer checked → event carries non-null `disclaimer_accepted_at`
///   and jittered approx coords (M-CRUD-3, M-MAPA-1)
/// - phone normalized BEFORE dispatch (M-WA-1)
/// - `CasaMoteroEligibilityLoaded(has: true)` → blocked UI + "IR A MI CASA"
///   (M-CRUD-1 UX pre-check)
/// - 23505 → friendly SnackBar, never crash (M-CRUD-1)
/// - edit mode: `LoadCasaMoteroDetails` prefill + `UpdateCasaMotero` /
///   `UpdateCasaMoteroDetails` dispatch (M-CRUD-2/5)
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/screens/create_motoposada_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only subclass (pattern: motoposada_detail_signals_test.dart): exposes
/// the protected `emit` to seed loaded states AND records dispatched events
/// without touching Supabase. flutter_bloc 8.x `BlocBuilder` reads the bloc
/// as a Listenable (context.watch) — a mocktail Mock + StreamController can
/// never notify it, so tests seed real states via [seed] and assert
/// dispatches via [dispatched].
class _SeededBloc extends MotoposadasBloc {
  _SeededBloc() : super(client: _FakeSupabaseClient());

  final List<MotoposadasEvent> dispatched = [];

  void seed(MotoposadasState state) => emit(state);

  @override
  void add(MotoposadasEvent event) {
    dispatched.add(event);
    // Do not process — the test controls state via seed().
  }
}

/// Minimal SupabaseClient fake — only the constructor needs a non-null
/// client; the seeded bloc never queries (add is overridden).
class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MotoposadaModel _existingCasaMotero() => MotoposadaModel.fromMap({
  'id': 7,
  'user_id': 'user-1',
  'type': 'casa',
  'title': 'Casa del Faro',
  'description': 'Hospedaje para moteros',
  'lat': 4.5991,
  'lng': -74.0761,
  'max_guests': 3,
  'is_active': true,
  'visibility': 'public',
  'created_at': '2024-01-01T00:00:00.000Z',
  'poi_type': 'casa_motero',
});

Future<_SeededBloc> _pumpForm(
  WidgetTester tester, {
  MotoposadaModel? existing,
}) async {
  final bloc = _SeededBloc();
  await tester.pumpWidget(
    BlocProvider<MotoposadasBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: CreateMotoposadaScreen(
          mode: CreateMotoposadaMode.casaMotero,
          existing: existing,
        ),
      ),
    ),
  );
  await tester.pump();
  return bloc;
}

Future<void> _enterField(WidgetTester tester, String hint, String value) async {
  await tester.enterText(find.widgetWithText(TextField, hint), value);
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

/// Fills the create form and accepts the disclaimer, ready to submit.
Future<void> _fillAndAccept(WidgetTester tester) async {
  await _enterField(tester, 'Ej: Casa en La Calera', 'Casa del Faro');
  await _enterField(
    tester,
    'Contanos sobre el espacio...',
    'Hospedaje para moteros',
  );
  await _enterField(tester, 'Ej: +57 300 123 4567', '+57 300 123 4567');
  await _scrollTo(tester, find.textContaining('descargo'));
  await tester.tap(find.textContaining('descargo'));
  await tester.pump();
}

void main() {
  group('CreateMotoposadaScreen casa_motero mode — M-CRUD-5 field set', () {
    testWidgets('renders alias/desc/capacity/WhatsApp/disponible/map-picker', (
      tester,
    ) async {
      await _pumpForm(tester);

      // M-CRUD-5 fields.
      expect(find.text('TÍTULO'), findsOneWidget);
      expect(find.text('DESCRIPCIÓN'), findsOneWidget);
      expect(find.text('MÁXIMO HUÉSPEDES'), findsOneWidget);
      expect(find.text('WHATSAPP'), findsOneWidget);
      expect(find.text('DISPONIBLE'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      // Map picker button (M-CRUD-5: approximate + exact location).
      expect(find.text('Seleccionar en el mapa'), findsOneWidget);
    });

    testWidgets('NO address field, NO cédula, NO standard-only fields', (
      tester,
    ) async {
      await _pumpForm(tester);

      // M-CRUD-4 / M-WA-3: no address collection in the casa_motero form.
      expect(find.text('DIRECCIÓN'), findsNothing);
      expect(find.text('Dirección amigable'), findsNothing);
      // Standard-mode-only controls are hidden in casa_motero mode.
      expect(find.text('TIPO'), findsNothing);
      expect(find.text('REGLAS'), findsNothing);
      expect(find.text('VISIBILIDAD'), findsNothing);
      expect(find.text('CIUDAD'), findsNothing);
      expect(find.text('¿Es un lugar de visita obligada?'), findsNothing);
      // No cédula / identity-document concept anywhere (M-CRUD-4).
      for (final pattern in [
        RegExp(r'c[ée]dula', caseSensitive: false),
        RegExp(r'documento', caseSensitive: false),
        RegExp(r'identidad', caseSensitive: false),
        RegExp(r'pasaporte', caseSensitive: false),
      ]) {
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(
            pattern.hasMatch(text.data ?? ''),
            isFalse,
            reason:
                'casa_motero form must not reference identity: '
                '"${text.data}" matches /${pattern.pattern}/',
          );
        }
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          final hint = field.decoration?.hintText ?? '';
          expect(
            pattern.hasMatch(hint),
            isFalse,
            reason:
                'casa_motero hint must not reference identity: '
                '"$hint" matches /${pattern.pattern}/',
          );
        }
      }
    });

    testWidgets('dispatches CheckCasaMoteroEligibility on init (M-CRUD-1 UX)', (
      tester,
    ) async {
      final bloc = await _pumpForm(tester);

      expect(
        bloc.dispatched.whereType<CheckCasaMoteroEligibility>(),
        hasLength(1),
      );
    });
  });

  group(
    'CreateMotoposadaScreen casa_motero mode — disclaimer gating (M-CRUD-3)',
    () {
      testWidgets(
        'disclaimer unchecked → submit blocked + validation message',
        (tester) async {
          final bloc = await _pumpForm(tester);

          await _enterField(tester, 'Ej: Casa en La Calera', 'Casa del Faro');
          await _enterField(tester, 'Ej: +57 300 123 4567', '+57 300 123 4567');

          await _scrollTo(tester, find.text('PUBLICAR'));
          await tester.tap(find.text('PUBLICAR'));
          await tester.pump();

          // Blocked: validation message visible, no create event dispatched.
          expect(
            find.textContaining('Debés aceptar el descargo'),
            findsOneWidget,
          );
          expect(bloc.dispatched.whereType<CreateCasaMotero>(), isEmpty);
        },
      );

      testWidgets(
        'disclaimer checked → CreateCasaMotero with non-null acceptedAt, '
        'normalized phone, jittered approx coords',
        (tester) async {
          final bloc = await _pumpForm(tester);

          await _fillAndAccept(tester);

          await _scrollTo(tester, find.text('PUBLICAR'));
          await tester.tap(find.text('PUBLICAR'));
          await tester.pump();

          final creates = bloc.dispatched
              .whereType<CreateCasaMotero>()
              .toList();
          expect(creates, hasLength(1));
          final event = creates.single;

          // M-CRUD-3: disclaimer persisted non-null.
          expect(event.disclaimerAcceptedAt, isNotNull);
          // M-WA-1: phone normalized (digits only) before dispatch.
          expect(event.whatsappPhone, '573001234567');
          // M-MAPA-1: approx (public) coords are jittered away from exact.
          expect(event.lat, isNot(event.latExact));
          expect(event.lng, isNot(event.lngExact));
          expect(
            (event.lat - event.latExact).abs() > 0.001,
            isTrue,
            reason: 'jitter must move the point >100 m (~0.001 deg lat)',
          );
        },
      );
    },
  );

  group('CreateMotoposadaScreen casa_motero mode — max-1 UX (M-CRUD-1)', () {
    testWidgets('eligibility has=true → blocked UI + "IR A MI CASA" link', (
      tester,
    ) async {
      final bloc = await _pumpForm(tester);

      bloc.seed(const CasaMoteroEligibilityLoaded(has: true));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Ya tenés una casa de motero'),
        findsOneWidget,
      );
      expect(find.text('IR A MI CASA'), findsOneWidget);
    });

    testWidgets(
      '23505 (CasaMoteroAlreadyExists) → friendly SnackBar, no crash',
      (tester) async {
        final bloc = await _pumpForm(tester);

        bloc.seed(const CasaMoteroAlreadyExists());
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Ya tienes una casa de motero publicada'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('CreateMotoposadaScreen casa_motero mode — edit (M-CRUD-2/5)', () {
    testWidgets(
      'edit mode dispatches LoadCasaMoteroDetails and prefills phone',
      (tester) async {
        final bloc = await _pumpForm(tester, existing: _existingCasaMotero());

        expect(
          bloc.dispatched.whereType<LoadCasaMoteroDetails>(),
          hasLength(1),
        );

        // Prefill arrives → phone field populated from owner-only details.
        bloc.seed(
          const CasaMoteroDetailsLoaded(
            motoposadaId: 7,
            whatsappPhone: '573001234567',
            latExact: 4.5942,
            lngExact: -74.0702,
          ),
        );
        await tester.pump();

        expect(find.text('573001234567'), findsOneWidget);
        expect(find.text('Casa del Faro'), findsOneWidget);
      },
    );

    testWidgets(
      'edit submit dispatches UpdateCasaMotero + UpdateCasaMoteroDetails',
      (tester) async {
        final bloc = await _pumpForm(tester, existing: _existingCasaMotero());

        bloc.seed(
          const CasaMoteroDetailsLoaded(
            motoposadaId: 7,
            whatsappPhone: '573001234567',
            latExact: 4.5942,
            lngExact: -74.0702,
          ),
        );
        await tester.pump();

        await _scrollTo(tester, find.text('GUARDAR'));
        await tester.tap(find.text('GUARDAR'));
        await tester.pump();

        final updates = bloc.dispatched.whereType<UpdateCasaMotero>().toList();
        expect(updates, hasLength(1));
        final updEvent = updates.single;
        expect(updEvent.id, 7);
        expect(updEvent.title, 'Casa del Faro');
        expect(updEvent.isActive, isTrue);
        // Re-jittered approx on save (design §1.4).
        expect(updEvent.lat, isNot(updEvent.lng));
      },
    );
  });
}
