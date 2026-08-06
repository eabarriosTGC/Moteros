# Apply Progress — motoposadas-moteros

## Batch 1 (deleg_5f991552) — DONE, commiteado

- **Fase 0**: verificación de rama `motoposadas-moteros` + audit de integration points ✅
- **Fase 1** (commit `3c50788`, 7 files, +737): migración `026_casa_motero.sql` (223 líneas, reviewer-fixed: index parcial max-1, `mp_insert_own` re-creado con `poi_type IS DISTINCT FROM 'casa_motero'`, `casa_motero_details` con `cmd_select_own`/`cmd_update_own` — SIN `cmd_delete_own` (solo comentario), SIN INSERT policy, RPCs SECURITY DEFINER con floor haversine ≥300m, triggers blur floor con `UPDATE OF lat,lng,poi_type`); `blur_coordinates.dart` (jitter polar 300-500m + haversineMeters espejo); `casa_motero_payload.dart` (phone normalizado, sin address/cédula); tests: `blur_coordinates_test.dart`, `migration_026_content_test.dart`, `casa_motero_payload_test.dart`; CI guard grep en workflow.
- **Fase 2** (commit `95064b4`, 2 files, +389): `whatsapp_launcher.dart` (buildWhatsAppUrl wa.me, buildAvailabilityMessage sin ubicación, launchWhatsAppContact con fallback web/copiar — nunca silencio); `whatsapp_launcher_test.dart`.
- **46/46 tests** de fases 1-2 verificados por el orquestador (re-run). ⚠ DEPLOY: migración 026 NO aplicada — deploy-side, antes del release.

## Batch 2 (siguiente) — Fases 3-6

- [ ] Fase 3: bloc events/states/handlers (eligibility, create vía RPC + 23505→CasaMoteroAlreadyExists, update público/privado, phone on demand, LoadCasaMoteroDetails) + `casa_motero_bloc_test.dart` noSuchMethod
- [ ] Fase 4: form create/edición modo casa_motero (disclaimer gating, map picker + jitter, sin address/cédula) + My casa (entry, edit/toggle/delete) + no_cedula_guard part 2 + tests widget
- [ ] Fase 5: CasaMoteroMarker + markerKindFor + CasaMoteroCard (TrustSignalsRow, sin phone/address) + rodar_screen 3-vías + featured card + tests widget
- [ ] Fase 6: flutter test completo + flutter analyze + dart format
