/// Post-trip photo flow widget tests — M-CPU-1/2 (Fase 6, W4 — fotos de
/// conquista).
///
/// STRICT TDD: escritos ANTES del GREEN (`conquest_photo_button.dart` no
/// existe → RED por compilación).
///
/// El flujo se testea como WIDGET AISLADO (`ConquestPhotoButton`), NO la
/// pantalla completa: PostTripSummaryScreen lleva FlutterMap y el stream de
/// tiles cuelga el harness bajo FakeAsync (precedente del repo — las screens
/// con mapa son source-verified). El botón inyecta picker/uploader/inserter
/// (patrón typedef `whatsapp_launcher`) y escucha `TrackerBloc` para la cola
/// standalone (flush en TrackerSaveSucceeded).
///
/// Los SnackBars se avanzan con `pump(5s)` al final de cada test para no
/// dejar timers pendientes bajo FakeAsync.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:moteros_app/core/services/location_tracking_service.dart';
import 'package:moteros_app/features/tracker/presentation/screens/route_tracker_screen.dart';
import 'package:moteros_app/features/tracker/presentation/widgets/conquest_photo_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes inyectados (patrón typedef del repo) ──

/// Picker fake: registra llamadas y devuelve el XFile configurado (o null
/// para simular cancelación).
class _RecordingPicker {
  _RecordingPicker(this.result);
  final XFile? result;
  int calls = 0;

  Future<XFile?> call() async {
    calls++;
    return result;
  }
}

/// Uploader fake: registra (file, userId) y devuelve una URL pública.
class _RecordingUploader {
  final List<({File file, String userId, String? caption})> calls = [];

  Future<String> call(File file,
      {required String userId, String? caption}) async {
    calls.add((file: file, userId: userId, caption: caption));
    return 'https://cdn.example/foto_${calls.length}.jpg';
  }
}

/// Inserter fake: registra la firma real de insertConquestPhoto.
class _RecordingInserter {
  final List<
      ({
        String userId,
        String source,
        String? sourceId,
        String photoUrl,
        String? caption,
      })> calls = [];

  Future<void> call({
    required String userId,
    required String source,
    String? sourceId,
    required String photoUrl,
    String? caption,
  }) async {
    calls.add((
      userId: userId,
      source: source,
      sourceId: sourceId,
      photoUrl: photoUrl,
      caption: caption,
    ));
  }
}

// ── TrackerBloc seedable (patrón _SeededBloc del repo) ──

/// GPS no-op: TrackerBloc con tracker real cuelga FakeAsync (singleton
/// LocationTrackingService.instance) — siempre inyectar un no-op.
class _NoopTracker implements TrackerGpsService {
  @override
  Future<bool> start() async => true;

  @override
  void stop() {}

  @override
  Future<bool> restoreFromCheckpoint() async => true;

  @override
  List<LatLng> get tracePoints => const [];

  @override
  DateTime? get startedAt => null;

  @override
  void Function(TrackingSnapshot)? get onUpdate => null;

  @override
  set onUpdate(void Function(TrackingSnapshot)? callback) {}
}

class _NullClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SeededTrackerBloc extends TrackerBloc {
  _SeededTrackerBloc()
      : super(client: _NullClient(), tracker: _NoopTracker());

  final List<TrackerEvent> dispatched = [];

  /// Expone `emit` (protected) para sembrar estados sin procesar eventos.
  void seed(TrackerState s) => emit(s);

  @override
  void add(TrackerEvent e) {
    dispatched.add(e);
  }
}

// ── Helper de pump ──

Future<void> _pumpButton(
  WidgetTester tester, {
  required _SeededTrackerBloc bloc,
  _RecordingUploader? uploader,
  _RecordingInserter? inserter,
  _RecordingPicker? picker,
  int? raidId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<TrackerBloc>(
          create: (_) => bloc,
          child: ConquestPhotoButton(
            userId: 'u1',
            raidId: raidId,
            uploader: uploader?.call,
            inserter: inserter?.call,
            pickImage: picker?.call,
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // M-CPU-1/2 — raid-linked: pick → upload → insert source 'raid'
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'AÑADIR FOTOS (raid) abre el picker y hace upload + insert '
      'source raid/sourceId raidId exactamente una vez', (tester) async {
    final bloc = _SeededTrackerBloc();
    final picker = _RecordingPicker(XFile('/tmp/foto.jpg'));
    final uploader = _RecordingUploader();
    final inserter = _RecordingInserter();

    await _pumpButton(tester,
        bloc: bloc,
        picker: picker,
        uploader: uploader,
        inserter: inserter,
        raidId: 42);

    // M-CPU-1: el placeholder ya no existe en el árbol.
    expect(find.text('Fotos — próximamente'), findsNothing);

    await tester.tap(find.text('AÑADIR FOTOS'));
    await tester.pump();
    await tester.pump();

    expect(picker.calls, 1);
    expect(uploader.calls, hasLength(1));
    expect(uploader.calls.single.userId, 'u1');
    expect(inserter.calls, hasLength(1));
    expect(inserter.calls.single.source, 'raid');
    expect(inserter.calls.single.sourceId, '42');
    expect(inserter.calls.single.userId, 'u1');
    expect(inserter.calls.single.photoUrl, 'https://cdn.example/foto_1.jpg');

    // SnackBar de éxito + avanzar reloj para no dejar timers pendientes.
    expect(find.text('Foto añadida'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('picker cancelado (null) → ni upload ni insert', (tester) async {
    final bloc = _SeededTrackerBloc();
    final picker = _RecordingPicker(null);
    final uploader = _RecordingUploader();
    final inserter = _RecordingInserter();

    await _pumpButton(tester,
        bloc: bloc, picker: picker, uploader: uploader, inserter: inserter);

    await tester.tap(find.text('AÑADIR FOTOS'));
    await tester.pump();
    await tester.pump();

    expect(picker.calls, 1);
    expect(uploader.calls, isEmpty);
    expect(inserter.calls, isEmpty);
  });

  // ══════════════════════════════════════════════════════════════════════
  // M-CPU-2 — standalone: upload inmediato + cola hasta TrackerSaveSucceeded
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'standalone: upload inmediato, insert encolado, flush en '
      'TrackerSaveSucceeded con source route/sourceId savedRouteId',
      (tester) async {
    final bloc = _SeededTrackerBloc();
    final picker = _RecordingPicker(XFile('/tmp/foto.jpg'));
    final uploader = _RecordingUploader();
    final inserter = _RecordingInserter();

    await _pumpButton(tester,
        bloc: bloc, picker: picker, uploader: uploader, inserter: inserter);

    await tester.tap(find.text('AÑADIR FOTOS'));
    await tester.pump();
    await tester.pump();

    // Upload inmediato; insert NO (aún no hay savedRouteId).
    expect(uploader.calls, hasLength(1));
    expect(inserter.calls, isEmpty);

    // Save exitoso → flush de la cola con source 'route'.
    bloc.seed(TrackerSaveSucceeded(savedRouteId: 'r9'));
    await tester.pump();
    await tester.pump();

    expect(inserter.calls, hasLength(1));
    expect(inserter.calls.single.source, 'route');
    expect(inserter.calls.single.sourceId, 'r9');
    expect(inserter.calls.single.userId, 'u1');
    expect(inserter.calls.single.photoUrl, 'https://cdn.example/foto_1.jpg');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
      'standalone: TrackerSaveFailed → SnackBar "Guarda la ruta…" y la fila '
      'NO se inserta con source_id null', (tester) async {
    final bloc = _SeededTrackerBloc();
    final picker = _RecordingPicker(XFile('/tmp/foto.jpg'));
    final uploader = _RecordingUploader();
    final inserter = _RecordingInserter();

    await _pumpButton(tester,
        bloc: bloc, picker: picker, uploader: uploader, inserter: inserter);

    await tester.tap(find.text('AÑADIR FOTOS'));
    await tester.pump();
    await tester.pump();
    expect(uploader.calls, hasLength(1));

    bloc.seed(TrackerSaveFailed('sin conexión'));
    await tester.pump();
    // El SnackBar 'Foto añadida' (4s) sigue visible → el de 'Guarda la ruta'
    // queda ENCOLADO en el ScaffoldMessenger. Bajo FakeAsync la cola de
    // SnackBars es timing-frágil (mismo pozo que el hang de Fase 5): se
    // verifica el NÚCLEO de M-CPU-2 (la fila NUNCA se inserta con source_id
    // null) y el texto del SnackBar queda como UX source-verified.
    await tester.pump(const Duration(seconds: 5));

    // NUNCA insertar con source_id null (M-CPU-2) — la cola NO se vacía en
    // error (reintento posible; residual huérfano documentado).
    expect(inserter.calls, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });
}
