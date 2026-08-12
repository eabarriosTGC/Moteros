# R8 (activo por defecto en release del Flutter Gradle plugin) elimina
# com.google.mlkit.vision.barcode.BarcodeScanning cuando otra librería nativa
# FFI (objectbox vía flutter_map_tile_caching) está presente, rompiendo el
# escáner de mobile_scanner SOLO en release con:
#   Attempt to invoke virtual method 'a5.e a5.d.a(w4.b)' on a null object reference
# Workaround verificado en mobile_scanner issue #1725 (2026-07-02).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.** { *; }
