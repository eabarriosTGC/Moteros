# Apply Progress — motoposadas-moteros

## Batch 1 (deleg_5f991552) — DONE, commiteado

- **Fase 0**: verificación de rama `motoposadas-moteros` + audit de integration points ✅
- **Fase 1** (commit `3c50788`, 7 files, +737): migración `026_casa_motero.sql` (223 líneas, reviewer-fixed: index parcial max-1, `mp_insert_own` re-creado con `poi_type IS DISTINCT FROM 'casa_motero'`, `casa_motero_details` con `cmd_select_own`/`cmd_update_own` — SIN `cmd_delete_own` (solo comentario), SIN INSERT policy, RPCs SECURITY DEFINER con floor haversine ≥300m, triggers blur floor con `UPDATE OF lat,lng,poi_type`); `blur_coordinates.dart` (jitter polar 300-500m + haversineMeters espejo); `casa_motero_payload.dart` (phone normalizado, sin address/cédula); tests: `blur_coordinates_test.dart`, `migration_026_content_test.dart`, `casa_motero_payload_test.dart`; CI guard grep en workflow.
- **Fase 2** (commit `95064b4`, 2 files, +389): `whatsapp_launcher.dart` (buildWhatsAppUrl wa.me, buildAvailabilityMessage sin ubicación, launchWhatsAppContact con fallback web/copiar — nunca silencio); `whatsapp_launcher_test.dart`.
- **46/46 tests** de fases 1-2 verificados por el orquestador (re-run). ⚠ DEPLOY: migración 026 NO aplicada — deploy-side, antes del release.

## Batch 2 (deleg_b8b2ce54 + retoma orquestador) — Fase 3 DONE, commiteada

- **Fase 3** (commit `ea0f436`, 11 files): eventos/estados/handlers completos + `casa_motero_bloc_test.dart` 16/16. El sub-agente dejó 10/16 RED por bugs de infraestructura del fake (no por lógica): el orquestador los resolvió inline con el patrón probado del repo — `FakeTransformBuilder<T>` para `maybeSingle` (el await seam espera `PostgrestTransformBuilder<Map<String,dynamic>?>`), `FakeRpcBuilder<T>` para RPC con primitivos (int 99 / phone String — el `?? const <Map<String,dynamic>>[]` de FakeFilterBuilder envenena la inferencia), `Map<String,dynamic>.from()` para payloads de update (`_Map<dynamic,dynamic>`). Tests de create ahora con `disclaimerAcceptedAt` real (el bloc hace `!` — el form garantiza disclaimer antes de despachar).
- **Suite completa: 215/215 PASS** verificado por el orquestador.

## Batch 3 (deleg_b11b67de + retoma orquestador) — Fase 4 DONE, commiteada

- **Fase 4** (commit `be1f604`, 6 files): form casaMotero (disclaimer gating, jitter, phone normalizado, sin address/cédula, modo edición con prefill) + My casa (entry + edit/toggle/delete) + no_cedula_guard part 2.
- El sub-agente dejó 13/24 RED por un fallo estructural del patrón de mock (mocktail Mock + StreamController NO notifica a BlocBuilder 8.x — lee el bloc como Listenable). El orquestador reescribió los tests al patrón probado `_SeededBloc` (emit expuesto + dispatched[] para verificar eventos) + pump doble (microtask del stream + frame). Fix de timing en suite: los tests de scroll+tap pueden flakear en paralelo (re-run estable).
- **235/235 suite completa, analyze 580 = baseline** verificado por el orquestador.

## Batch 4 (deleg — parte 1) — Fase 5 DONE

- **Fase 5** (pendiente commit checkpoint): `casa_motero_marker.dart` (NEW — `MarkerKind` enum + `CasaMoteroMarker` Icons.home_rounded + AppColors.secondary, chip 🏠; puro `markerKindFor` 3-vías `isTourist` → `isCasaMotero` → standard) + `casa_motero_marker_test.dart` 9/9 (incl. precedencia isTourist y truncado — ojo: 🏠 es surrogate pair, bound 19 no 18); `casa_motero_card.dart` (NEW — bottom sheet: alias/badge poiTypeLabel/desc/capacidad/TrustSignalsRow/"Ubicación aproximada"/nav Waze+GoogleMaps con mp.lat/mp.lng/Contactar; BlocListener `CasaMoteroWhatsappLoaded` → phone null → SnackBar "El anfitrión no está disponible", phone → `launchWhatsAppContact` con seam `contactLauncher` inyectable; sin phone/address en el árbol) + `casa_motero_card_test.dart` 6/6 (patrón `_SeededBloc`); `rodar_screen.dart` (MODIFIED — switch `markerKindFor` 3-vías + tap casa_motero → `showCasaMoteroCard`); `featured_motoposada_card.dart` (MODIFIED — badge `poiTypeLabel` en secondary para casa_motero; línea "Ubicación aproximada" en vez de address).
- **Checkpoint parcial: 63/63** en `test/features/refugios/widgets/ + test/features/dashboard/ + test/features/explorar/`; `dart analyze` de archivos tocados: 0 issues.

## Batch 4 (parte 2) — Fase 6 (verificación final)

- **Fase 5 commiteada**: `1fe7bf2` (7 files, +791/-13).
- **Fase 6 DONE**: `8521acd` (dart format + cierre) — **250/250 suite completa, flutter analyze 580 = baseline main (delta 0)** verificado por el orquestador (re-run final).

## ✅ APPLY COMPLETO — motoposadas-moteros (fases 0-6)

Commits: `3c50788` (migración 026 + blur + payload), `95064b4` (wa launcher), `ea0f436` (bloc), `be1f604` (forms + My casa), `1fe7bf2` (marker + card + mapa), `8521acd` (format + cierre).
- **250/250 tests, analyze 580 = baseline main (delta 0)**
- ⚠ DEPLOY: migración 026 NO aplicada — deploy-side, ANTES del release (create RPC, details table, triggers, mp_insert_own re-create dependen de ella)
- Siguiente: gatekeeper de apply (reviewer fresh-context) → sdd-verify → sdd-archive
