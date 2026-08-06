/// Conquest photo upload tests — M-CPU-1/2/4 (Fase 6, W4 — fotos de conquista).
///
/// STRICT TDD: escritos ANTES del GREEN (`conquest_photo_repository.dart` no
/// existe → RED por compilación + aserciones reales sobre la firma).
///
/// Cubre:
///  - Datasource (M-CPU-2/4): `insertConquestPhoto` se invoca con la firma
///    real (`userId/source/sourceId/photoUrl/caption`) y el payload de fila
///    `{user_id, source, source_id, photo_url, caption}`.
///  - Repository (M-CPU-1/2): `uploadConquestPhoto` sube a storage
///    `conquest-photos` con path `<userId>/<millis>_<n>.jpg` y resuelve la
///    URL pública con `getPublicUrl`.
///  - Unit (M-CPU-2): `resolveConquestPhotoSource` — raid → `('raid', raidId)`;
///    standalone → `('route', savedRouteId)`; nunca otro source.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/showcase/data/datasources/showcase_remote_datasource.dart';
import 'package:moteros_app/features/showcase/data/repositories/conquest_photo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes (patrón noSuchMethod del repo — raid_bloc_test.dart) ──

/// Fake del file API de storage (`from('bucket')`): registra upload y
/// getPublicUrl. `upload` resuelve con el path; `getPublicUrl` devuelve la
/// URL configurada (es síncrono en storage_client).
class _FakeFileApi implements StorageFileApi {
  _FakeFileApi();

  final String publicUrl = 'https://cdn.example/foto.jpg';
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #upload) {
      final path = invocation.positionalArguments.first as String;
      return Future.value(path);
    }
    if (invocation.memberName == #getPublicUrl) return publicUrl;
    return null;
  }
}

/// Fake del storage client (`client.storage`): `from(bucket)` devuelve el
/// [_FakeFileApi] y registra el nombre del bucket.
class _FakeStorage implements SupabaseStorageClient {
  _FakeStorage(this.fileApi);

  final _FakeFileApi fileApi;
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #from) return fileApi;
    return null;
  }
}

/// Fake query builder para `from(table)` (insert payload capture).
class _FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder({List<Invocation>? recorder}) : recorder = recorder ?? [];

  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(const <Map<String, dynamic>>[])
          .then((_) => onValue(const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

class _FakeQueryBuilder implements SupabaseQueryBuilder {
  _FakeQueryBuilder({List<Invocation>? recorder}) : recorder = recorder ?? [];

  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    return _FakeFilterBuilder(recorder: recorder);
  }
}

/// Fake SupabaseClient — `from(table)` devuelve un fake por tabla; `storage`
/// devuelve el [_FakeStorage]. Todas las invocaciones caen en [calls].
class _FakeSupabaseClient implements SupabaseClient {
  final Map<String, _FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];
  @override
  final _FakeStorage storage = _FakeStorage(_FakeFileApi());

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(table, () => _FakeQueryBuilder(recorder: calls));
    }
    if (invocation.memberName == #storage) return storage;
    return null;
  }
}

// ── Fixtures ──

final _basePath = RegExp(r'^u1/\d+_\d+\.jpg$');

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // M-CPU-2/4 — insertConquestPhoto: firma real + payload de fila
  // ══════════════════════════════════════════════════════════════════════

  group('ShowcaseRemoteDatasource.insertConquestPhoto (M-CPU-2/4)', () {
    test('payload de fila: user_id/source/source_id/photo_url/caption', () async {
      final client = _FakeSupabaseClient();
      final ds = ShowcaseRemoteDatasource(client: client);

      await ds.insertConquestPhoto(
        userId: 'u1',
        source: 'raid',
        sourceId: '42',
        photoUrl: 'https://cdn.example/foto.jpg',
        caption: 'Cumbre',
      );

      final insert =
          client.calls.firstWhere((i) => i.memberName == #insert);
      final payload = insert.positionalArguments.first as Map<String, dynamic>;
      expect(payload, {
        'user_id': 'u1',
        'source': 'raid',
        'source_id': '42',
        'photo_url': 'https://cdn.example/foto.jpg',
        'caption': 'Cumbre',
      });
    });

    test('sourceId y caption opcionales (firma real con nulls)', () async {
      final client = _FakeSupabaseClient();
      final ds = ShowcaseRemoteDatasource(client: client);

      await ds.insertConquestPhoto(
        userId: 'u2',
        source: 'route',
        photoUrl: 'https://cdn.example/otra.jpg',
      );

      final insert =
          client.calls.firstWhere((i) => i.memberName == #insert);
      final payload = insert.positionalArguments.first as Map<String, dynamic>;
      expect(payload['user_id'], 'u2');
      expect(payload['source'], 'route');
      expect(payload['source_id'], isNull);
      expect(payload['photo_url'], 'https://cdn.example/otra.jpg');
      expect(payload['caption'], isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // M-CPU-1/2 — uploadConquestPhoto: storage conquest-photos + path
  // ══════════════════════════════════════════════════════════════════════

  group('uploadConquestPhoto (M-CPU-1/2)', () {
    test('sube al bucket conquest-photos con path <userId>/<millis>_<n>.jpg '
        'y devuelve la URL pública', () async {
      final client = _FakeSupabaseClient();

      final url = await uploadConquestPhoto(
        File('foto.jpg'),
        userId: 'u1',
        client: client,
      );

      // Bucket correcto (nunca 'place-photos').
      final fromCall = client.storage.calls
          .firstWhere((i) => i.memberName == #from);
      expect(fromCall.positionalArguments.first, 'conquest-photos');

      // Path con prefijo EXACTO de userId + <millis>_<n>.jpg (I4).
      final fileApi = client.storage.fileApi;
      final upload = fileApi.calls.firstWhere((i) => i.memberName == #upload);
      final path = upload.positionalArguments.first as String;
      expect(path, matches(_basePath));

      // getPublicUrl se llama con el MISMO path; el retorno es la URL.
      final getUrl =
          fileApi.calls.firstWhere((i) => i.memberName == #getPublicUrl);
      expect(getUrl.positionalArguments.first, path);
      expect(url, fileApi.publicUrl);
    });

    test('dos uploads → paths distintos (contador n)', () async {
      final client = _FakeSupabaseClient();

      await uploadConquestPhoto(File('a.jpg'), userId: 'u1', client: client);
      await uploadConquestPhoto(File('b.jpg'), userId: 'u1', client: client);

      final fileApi = client.storage.fileApi;
      final uploads =
          fileApi.calls.where((i) => i.memberName == #upload).toList();
      expect(uploads, hasLength(2));
      final p1 = uploads[0].positionalArguments.first as String;
      final p2 = uploads[1].positionalArguments.first as String;
      expect(p1, isNot(p2));
      expect(p1, matches(_basePath));
      expect(p2, matches(_basePath));
    });

    test('los errores de storage propagan (no se tragan)', () async {
      final client = _SupabaseWithStorage(_ThrowingStorage());

      await expectLater(
        uploadConquestPhoto(File('foto.jpg'), userId: 'u1', client: client),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // M-CPU-2 — resolveConquestPhotoSource: raid vs standalone
  // ══════════════════════════════════════════════════════════════════════

  group('resolveConquestPhotoSource (M-CPU-2)', () {
    test('raid-linked → source raid + sourceId raidId.toString()', () {
      final src = resolveConquestPhotoSource(raidId: 42);
      expect(src.source, 'raid');
      expect(src.sourceId, '42');
    });

    test('standalone (guardada) → source route + sourceId savedRouteId', () {
      final src = resolveConquestPhotoSource(savedRouteId: 'r9');
      expect(src.source, 'route');
      expect(src.sourceId, 'r9');
    });

    test('raid gana sobre standalone; nunca otro source', () {
      final src = resolveConquestPhotoSource(raidId: 7, savedRouteId: 'r9');
      expect(src.source, 'raid');
      expect(src.sourceId, '7');
    });
  });
}

/// File API cuyo getPublicUrl lanza (para probar propagación de errores).
class _ThrowingFileApi implements StorageFileApi {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #upload) {
      final path = invocation.positionalArguments.first as String;
      return Future.value(path);
    }
    if (invocation.memberName == #getPublicUrl) {
      throw StateError('storage caído');
    }
    return null;
  }
}

/// Storage cuyo `from(bucket)` devuelve un file api lanzador.
class _ThrowingStorage implements SupabaseStorageClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #from) return _ThrowingFileApi();
    return null;
  }
}

/// Cliente con un storage lanzador (getPublicUrl).
class _SupabaseWithStorage implements SupabaseClient {
  _SupabaseWithStorage(this.storage);
  @override
  final SupabaseStorageClient storage;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #storage) return storage;
    return null;
  }
}
