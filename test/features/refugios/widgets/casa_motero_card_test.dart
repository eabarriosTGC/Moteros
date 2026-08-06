/// CasaMoteroCard widget tests — F-M10/F-M11 (M-MAPA-3, M-WA-1/2/3).
///
/// STRICT TDD: these tests reference `CasaMoteroCard` and its
/// `contactLauncher` seam BEFORE the widget exists — they must FAIL
/// (compile) until task 5.4 lands.
///
/// Covered:
/// - renders alias, badge "Casa de motero", description, capacity, the
///   host `TrustSignalsRow` (4 values), "Ubicación aproximada" note, nav
///   row (Waze/Google Maps at approx coords), Contactar (M-MAPA-3)
/// - NO phone and NO address in the tree (M-MAPA-3, M-WA-1)
/// - Contactar tap → dispatches `FetchCasaMoteroWhatsapp` (M-WA-1)
/// - phone loaded → wa.me URL built with the availability message (M-WA-1)
/// - phone null → "El anfitrión no está disponible" (M-WA-1)
/// - canLaunch=false → WhatsApp Web fallback sheet (M-WA-2)
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/services/whatsapp_launcher.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/widgets/casa_motero_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only subclass (pattern: create_casa_motero_screen_test.dart): exposes
/// the protected `emit` to seed loaded states AND records dispatched events
/// without touching Supabase. flutter_bloc 8.x `BlocBuilder`/`BlocListener`
/// read the bloc as a Listenable (context.watch) — a mocktail Mock +
/// StreamController can never notify it, so tests seed real states via
/// [seed] and assert dispatches via [dispatched].
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

MotoposadaModel _casaMotero() => MotoposadaModel.fromMap({
      'id': 7,
      'user_id': 'user-1',
      'type': 'casa',
      'title': 'Casa del Faro',
      'description': 'Hospedaje para moteros con parqueadero techado',
      'lat': 4.5991,
      'lng': -74.0761,
      'address': '',
      'max_guests': 3,
      'is_active': true,
      'visibility': 'public',
      'created_at': '2024-01-01T00:00:00.000Z',
      'poi_type': 'casa_motero',
      'users': {
        'username': 'Che',
        'created_at': '2023-08-01T00:00:00.000Z',
        'user_xp': {'level': 5, 'km_traveled': 1200},
        'user_achievements': [
          {'count': 5},
        ],
      },
    }, tripsByHost: {'user-1': 3});

Future<_SeededBloc> _pumpCard(
  WidgetTester tester, {
  CasaMoteroContactLauncher? contactLauncher,
}) async {
  final bloc = _SeededBloc();
  await tester.pumpWidget(
    BlocProvider<MotoposadasBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: Scaffold(
          body: CasaMoteroCard(mp: _casaMotero(), contactLauncher: contactLauncher),
        ),
      ),
    ),
  );
  await tester.pump();
  return bloc;
}

void main() {
  group('CasaMoteroCard — content (M-MAPA-3)', () {
    testWidgets('renders alias, badge, description, capacity, signals, '
        'approx-note, nav and Contactar', (tester) async {
      await _pumpCard(tester);

      // Alias + badge "Casa de motero" (poiTypeLabel).
      expect(find.text('Casa del Faro'), findsOneWidget);
      expect(find.text('Casa de motero'), findsOneWidget);
      // Description.
      expect(
        find.text('Hospedaje para moteros con parqueadero techado'),
        findsOneWidget,
      );
      // Capacity.
      expect(find.text('3 huéspedes'), findsOneWidget);
      // TrustSignalsRow — the 4 public host values (TS-R1).
      expect(find.text('Miembro desde ago 2023'), findsOneWidget);
      expect(find.text('3 viajes'), findsOneWidget);
      expect(find.text('1200 km'), findsOneWidget);
      expect(find.text('5 insignias'), findsOneWidget);
      // "Ubicación aproximada" note (M-MAPA-3 / M-WA-3: never the address).
      expect(find.text('Ubicación aproximada'), findsOneWidget);
      // Nav row + Contactar.
      expect(find.text('Waze'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Contactar'), findsOneWidget);
    });

    testWidgets('NO phone and NO address in the tree (M-MAPA-3, M-WA-1)',
        (tester) async {
      await _pumpCard(tester);

      // The model carries no phone by construction; the card must not render
      // any phone-ish surface.
      expect(find.textContaining('573001234567'), findsNothing);
      expect(find.byIcon(Icons.phone_rounded), findsNothing);
      // No address, no "Dirección" label, no exact coords as text.
      expect(find.textContaining('Dirección'), findsNothing);
      expect(find.textContaining('Calle'), findsNothing);
      expect(find.textContaining('4.5991'), findsNothing);
      expect(find.textContaining('-74.0761'), findsNothing);
    });
  });

  group('CasaMoteroCard — Contactar (M-WA-1)', () {
    testWidgets('tap dispatches FetchCasaMoteroWhatsapp with the listing id',
        (tester) async {
      final bloc = await _pumpCard(tester);

      await tester.scrollUntilVisible(
        find.text('Contactar'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Contactar'));
      await tester.pump();

      final fetches =
          bloc.dispatched.whereType<FetchCasaMoteroWhatsapp>().toList();
      expect(fetches, hasLength(1));
      expect(fetches.single.id, 7);
    });

    testWidgets('phone loaded → wa.me URL built with availability message',
        (tester) async {
      String? launchedPhone;
      String? launchedMessage;
      final bloc = await _pumpCard(
        tester,
        contactLauncher: (context, phone, message) async {
          launchedPhone = phone;
          launchedMessage = message;
        },
      );

      await tester.scrollUntilVisible(
        find.text('Contactar'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Contactar'));
      await tester.pump();

      // On-demand phone arrives → BlocListener launches.
      const phone = '573001234567';
      bloc.seed(const CasaMoteroWhatsappLoaded(phone: phone));
      await tester.pump();
      await tester.pump();

      expect(launchedPhone, phone);
      expect(launchedMessage, isNotNull);
      // M-WA-1: wa.me URL with digits + encoded message.
      final url = buildWhatsAppUrl(phone, launchedMessage!);
      expect(url, startsWith('https://wa.me/573001234567?text='));
      // M-WA-3: the outbound message never carries coords/address.
      expect(launchedMessage, contains('disponible'));
      expect(launchedMessage, isNot(contains('4.5991')));
      expect(launchedMessage, isNot(contains('Calle')));
    });
  });

  group('CasaMoteroCard — phone null / fallback (M-WA-1/2)', () {
    testWidgets('phone null → "El anfitrión no está disponible"',
        (tester) async {
      final bloc = await _pumpCard(tester);

      bloc.seed(const CasaMoteroWhatsappLoaded());
      await tester.pump();
      await tester.pump();

      expect(
        find.text('El anfitrión no está disponible'),
        findsOneWidget,
      );
    });

    testWidgets('canLaunch=false → WhatsApp Web fallback sheet (M-WA-2)',
        (tester) async {
      final bloc = await _pumpCard(
        tester,
        contactLauncher: (context, phone, message) =>
            launchWhatsAppContact(
          context,
          phone,
          message,
          canLaunch: (_) async => false,
          launch: (_) async => true,
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Contactar'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Contactar'));
      await tester.pump();

      bloc.seed(
        const CasaMoteroWhatsappLoaded(phone: '573001234567'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // No silent failure: the fallback sheet with web + copy is visible.
      expect(find.text('Abrir WhatsApp Web'), findsOneWidget);
      expect(find.text('Copiar mensaje'), findsOneWidget);
      expect(find.textContaining('WhatsApp requerido'), findsOneWidget);
    });
  });
}
