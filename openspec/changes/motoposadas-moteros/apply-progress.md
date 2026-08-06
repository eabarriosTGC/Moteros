# Apply Progress — motoposadas-moteros

## Batch 1 (deleg_5f991552) — DONE, commiteado

- **Fase 0**: verificación de rama `motoposadas-moteros` + audit de integration points ✅
- **Fase 1** (commit `3c50788`, 7 files, +737): migración `026_casa_motero.sql` (223 líneas, reviewer-fixed: index parcial max-1, `mp_insert_own` re-creado con `poi_type IS DISTINCT FROM 'casa_motero'`, `casa_motero_details` con `cmd_select_own`/`cmd_update_own` — SIN `cmd_delete_own` (solo comentario), SIN INSERT policy, RPCs SECURITY DEFINER con floor haversine ≥300m, triggers blur floor con `UPDATE OF lat,lng,poi_type`); `blur_coordinates.dart` (jitter polar 300-500m + haversineMeters espejo); `casa_motero_payload.dart` (phone normalizado, sin address/cédula); tests: `blur_coordinates_test.dart`, `migration_026_content_test.dart`, `casa_motero_payload_test.dart`; CI guard grep en workflow.
- **Fase 2** (commit `95064b4`, 2 files, +389): `whatsapp_launcher.dart` (buildWhatsAppUrl wa.me, buildAvailabilityMessage sin ubicación, launchWhatsAppContact con fallback web/copiar — nunca silencio); `whatsapp_launcher_test.dart`.
- **46/46 tests** de fases 1-2 verificados por el orquestador (re-run). ⚠ DEPLOY: migración 026 NO aplicada — deploy-side, antes del release.

## Batch 2 (deleg_b8b2ce54 + retoma orquestador) — Fase 3 DONE, commiteada

- **Fase 3** (commit `ea0f436`, 11 files): eventos/estados/handlers completos + `casa_motero_bloc_test.dart` 16/16. El sub-agente dejó 10/16 RED por bugs de infraestructura del fake (no por lógica): el orquestador los resolvió inline con el patrón probado del repo — `FakeTransformBuilder<T>` para `maybeSingle` (el await seam espera `PostgrestTransformBuilder<Map<String,dynamic>?>`), `FakeRpcBuilder<T>` para RPC con primitivos (int 99 / phone String — el `?? const <Map<String,dynamic>>[]` de FakeFilterBuilder envenena la inferencia), `Map<String,dynamic>.from()` para payloads de update (`_Map<dynamic,dynamic>`). Tests de create ahora con `disclaimerAcceptedAt` real (el bloc hace `!` — el form garantiza disclaimer antes de despachar).
- **Suite completa: 215/215 PASS** verificado por el orquestador.

## Batch 3 (siguiente) — Fases 4-6

- [ ] Fase 4: form create/edición modo casa_motero (disclaimer gating, map picker + jitter, sin address/cédula) + My casa (entry, edit/toggle/delete) + no_cedula_guard part 2 + tests widget
- [ ] Fase 5: CasaMoteroMarker + markerKindFor + CasaMoteroCard (TrustSignalsRow, sin phone/address) + rodar_screen 3-vías + featured card + tests widget
- [ ] Fase 6: flutter test completo + flutter analyze + dart format
