/// Conquest photo repository — pipeline upload → public URL → insert
/// (W4 — M-CPU-1/2, primera invocación de `insertConquestPhoto`).
///
/// El servicio inyectable se declara como dos typedefs (patrón
/// `whatsapp_launcher` del repo) porque el flujo standalone necesita
/// SEPARAR el upload del insert (design §4.1, fila "Timing del insert"):
/// el archivo se sube de inmediato al pickear, pero la fila se encola hasta
/// que `TrackerSaveSucceeded` entregue `savedRouteId`. Un único typedef
/// full-pipeline no podría diferir el insert sin re-subir el archivo.
///
/// - [ConquestPhotoUploader]: upload a storage + `getPublicUrl` → devuelve la
///   URL pública (el lado storage del pipeline).
/// - [ConquestPhotoInserter]: insert de la fila `conquest_photos` con la
///   firma real de `insertConquestPhoto` (el lado DB del pipeline).
///
/// [resolveConquestPhotoSource] decide source/source_id del draft: raid →
/// `('raid', raidId)`; standalone → `('route', savedRouteId)`. El insert
/// NUNCA se hace con `source_id` null (el widget solo llama al inserter
/// cuando el sourceId resuelto es no-null).
library;

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/showcase_remote_datasource.dart';

/// Uploads a picked photo to the `conquest-photos` bucket and returns its
/// public URL. Injectable seam — the real implementation is
/// [uploadConquestPhoto] (pattern `whatsapp_launcher`).
typedef ConquestPhotoUploader = Future<String> Function(
  File photo, {
  required String userId,
});

/// Inserts a `conquest_photos` row. Injectable seam mirroring the real
/// signature of `ShowcaseRemoteDatasource.insertConquestPhoto` (M-CPU-2).
typedef ConquestPhotoInserter = Future<void> Function({
  required String userId,
  required String source,
  String? sourceId,
  required String photoUrl,
  String? caption,
});

/// Source association of a photo draft: raid-linked trips always win over
/// standalone (M-CPU-2 — never another source).
typedef ConquestPhotoSource = ({String source, String? sourceId});

/// Contador de uploads por sesión: el path lleva `_<n>` para permitir
/// varias fotos en el mismo milisegundo (`<userId>/<millis>_<n>.jpg`).
int _photoUploadSeq = 0;

/// Real uploader: `storage.upload('<userId>/<millis>_<n>.jpg', photo)` al
/// bucket `conquest-photos` (migración 029, policies por prefijo
/// `auth.uid()/`), luego `getPublicUrl` → URL pública. Los errores propagan
/// (sin tragar). El `userId` deriva de `auth.currentUser.id` en el caller;
/// un mismatch de prefijo = error RLS visible (cp_insert_own).
Future<String> uploadConquestPhoto(
  File photo, {
  required String userId,
  SupabaseClient? client,
}) async {
  final supabase = client ?? Supabase.instance.client;
  final bucket = supabase.storage.from('conquest-photos');
  final path =
      '$userId/${DateTime.now().millisecondsSinceEpoch}_${++_photoUploadSeq}.jpg';
  await bucket.upload(path, photo);
  return bucket.getPublicUrl(path);
}

/// Real inserter: delega a `ShowcaseRemoteDatasource.insertConquestPhoto`
/// con la firma real (user_id/source/source_id/photo_url/caption). Es el
/// PRIMER call site del método (hasta W4 tenía cero invocaciones — por eso
/// el contador FOTOS siempre fue 0).
Future<void> insertConquestPhotoRow({
  required String userId,
  required String source,
  String? sourceId,
  required String photoUrl,
  String? caption,
  SupabaseClient? client,
}) async {
  await ShowcaseRemoteDatasource(client: client).insertConquestPhoto(
    userId: userId,
    source: source,
    sourceId: sourceId,
    photoUrl: photoUrl,
    caption: caption,
  );
}

/// M-CPU-2 — resuelve source/source_id del draft de foto. Raid-linked →
/// `('raid', raidId.toString())`; standalone → `('route', savedRouteId)`.
/// Nunca otro source. El caller solo inserta cuando [ConquestPhotoSource.sourceId]
/// es no-null (nunca `source_id` null en la fila).
ConquestPhotoSource resolveConquestPhotoSource({
  int? raidId,
  String? savedRouteId,
}) {
  if (raidId != null) {
    return (source: 'raid', sourceId: raidId.toString());
  }
  return (source: 'route', sourceId: savedRouteId);
}
