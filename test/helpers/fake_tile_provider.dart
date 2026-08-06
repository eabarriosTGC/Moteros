/// Helper de test para screens con FlutterMap (canónico del repo).
///
/// Los widget tests que montan un `FlutterMap` con el `TileLayer` por
/// defecto (`NetworkTileProvider`) cuelgan en teardown bajo FakeAsync:
/// el stream de tiles de red queda pendiente y el cierre del sink revienta
/// con `Bad state: Cannot close sink while adding stream`. El repo NO
/// widget-testeaba FlutterMap antes (precedente cero), así que la solución
/// adoptada es **inyección de TileProvider**: las screens con mapa aceptan
/// `tileProvider` (nullable, default null → comportamiento actual con el
/// provider de red/FMTC en prod) y los tests pasan [FakeTileProvider].
///
/// `MemoryImage` decodifica los bytes del PNG en memoria — cero HTTP, cero
/// streams de red → el test no cuelga. Este patrón es el mismo que usa la
/// suite propia de flutter_map.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// PNG transparente 1x1 (bytes mínimos válidos).
final Uint8List kTransparentPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// TileProvider fake: sirve un PNG transparente en memoria para cualquier
/// tile, sin tocar la red.
class FakeTileProvider extends TileProvider {
  FakeTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(kTransparentPngBytes);
  }
}
