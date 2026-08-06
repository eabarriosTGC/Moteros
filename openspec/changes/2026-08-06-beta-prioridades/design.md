# SDD Technical Design — Beta Prioridades: Cierre de Scope-Leak de Perfil, CTA de Motoposada, Registro de Viajes de Raid, Fotos de Conquista & Visibilidad de Raids Expirados

> **Proyecto:** Moteros / AsfaltoClub
> **Documento:** Technical Design para `2026-08-06-beta-prioridades`
> **Base:** `proposal.md` + 5 delta specs (`profile-scope-leak`, `progreso-motoposada-cta`, `raid-trip-registration`, `conquest-photos`, `expired-raids-visibility`)
> **Estado:** ✅ Listo para implementación
> **Nota de verificación:** toda firma, schema y `file:line` citado fue verificado contra el código real (sección 9).

---

## 0. Resumen técnico

Cinco workstreams aditivos sobre Flutter + BLoC + Supabase (Clean Architecture, UI dark M3):

- **W1 (M-PN-1..4)** — el gear de Progreso abre `SettingsScreen` directo; Settings re-homea "Editar perfil" y "Cerrar sesión" desde `ProfileScreen`; Progreso gana "Parches equipados" reusando el `PatchesBloc` global.
- **W2 (M-MPC-1..4)** — endurecer `_MiMotoposadaCard` (colores explícitos, min-height, fallback informativo, typo `'OFrecer MI CASA'` → `'Ofrecer MI CASA'`) + widget tests de los 3 estados.
- **W3 (M-RTR-1..6)** — vínculo raid→tracker con "Iniciar viaje"; origen auto (orden 0) / paradas manuales / destino auto (orden N+1) en `raid_waypoints` (migración `028`, RLS owner-only directa); fix del payload de `_save` alineado a `saved_routes` (002) con errores que surfacen.
- **W4 (M-CPU-1..4)** — flujo real de foto post-viaje (picker → upload al bucket nuevo `conquest-photos` → `insertConquestPhoto`), primera invocación del método; contador FOTOS y álbum leen la misma tabla.
- **W5 (M-ERV-1..5)** — filtro `scheduled_at >= now()` (UTC) en SOLO dos read sites: markers de Rodar y `fetchUpcomingRaids` de Explorar. `RaidBloc` y `raid_list_screen` intactos.

Los flujos de geofence-arrival (llegada a POI turístico) quedan en **fase 2** (ver 5.4): la base de F-B2 es la foto en el post-trip del raid ("llegada al destino" del requisito), y `motoposada_visits` (tabla sin migración, `route_tracker_screen.dart:259-274` con catch vacío) NO se toca ni se copia como patrón.

---

## 1. W1 — Cierre del scope-leak de perfil (M-PN-1..4)

### 1.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Gear de Progreso | Push directo `SettingsScreen` (reemplaza `ProfileScreen`) | `pushNamed('/settings')` | **Opción A — push directo** | M-PN-1. P2-6 del skill: `pushNamed` a ruta no registrada NO-OP silenciosamente (el `MaterialApp` no declara `routes:`/`onGenerateRoute`; verificado: `pushNamed` solo existe en `features_archive/`). El gear actual ya usa `MaterialPageRoute` directo (`progreso_screen.dart:61-64`). |
| Destino de "Editar perfil" | Fila en `SettingsScreen` (sección CUENTA) que pushea `ProfileEditScreen` | Botón en AppBar de Settings | **Fila con chevron en CUENTA** | M-PN-2. Settings no tiene AppBar actions y su patrón de lista es `_settingRow(icon, title, subtitle, trailing, onTap)` (`settings_screen.dart:167-207`); la fila es consistente con "Mapas Offline" (`:468-479`). `ProfileEditScreen` sigue VIVO (se pushea desde Settings) — solo `ProfileScreen`/`ShowcaseProfileScreen` quedan sin entry point. |
| Destino de "Cerrar sesión" | Fila en Settings → `context.read<AuthBloc>().add(LogoutRequested())` | Diálogo de confirmación | **Fila directa** | M-PN-2. `LogoutRequested` ya está manejado (`auth_bloc.dart:102-107` → `signOut` → listener emite `Unauthenticated`); re-homear es preservar la acción tal cual, sin estado nuevo. `AuthBloc` está provisto globalmente (`app.dart:52`), visible bajo el shell. |
| Screens de perfil | Mantener archivos + issue de deuda | Borrarlos | **Mantener + issue** | M-PN-3. `ShowcaseProfileScreen` es el patrón de perfil público futuro; `features_archive/dashboard_screen.dart:19` es la única referencia restante fuera de `features/profile/` y el barrel `showcase/showcase.dart` (código archivado; el import de `profile_screen.dart:16` queda dentro de la feature conservada — fuera del alcance del grep acotado, ver 1.2). Deuda → GitHub issue (regla del repo: residual aceptado → issue). |
| "Parches equipados" en Progreso | Sección propia que lee `PatchesBloc` (global, `app.dart:68`) y renderiza los earned | Reusar `PatchesVitrine` (showcase) | **Sección propia sobre `PatchesBloc`** | M-PN-4. `PatchesVitrine` (`patches_vitrine.dart:13-25`) está acoplada a `ShowcaseModel`/`OwnedItem`/`ShowcaseBloc` (editMode, eventos `EquipPatches`/`TogglePatchesEditMode`, `:60-71/:253-277`) y renderiza parches EQUIPADOS desde `user_showcase` — semántica distinta a los earned de `PatchesBloc` (`patches_bloc.dart:19-29`: `PatchesLoaded(patches, earned, total)`). Reusarla forzaría un segundo path de datos (showcase) en Progreso. La sección nueva es un widget dumb que despacha `LoadPatches` y consume el estado ya provisto — UNA sola fuente de datos, cero duplicación. |

### 1.2 Cambios

- `progreso_screen.dart:59-66` — gear: `ProfileScreen` → `SettingsScreen` (import `:9` cambia a settings); tooltip `'Perfil'` → `'Configuración'`.
- `settings_screen.dart` — en `_buildAccountSection` (`:224-293`), tras la fila "Nombre" (`:283-289`), dos filas nuevas:
  - `Icons.badge_outlined` "Editar perfil" (chevron) → `Navigator.push(MaterialPageRoute(builder: (_) => const ProfileEditScreen()))` (push directo, P2-6).
  - `Icons.logout` / `AppIcons.logout` "Cerrar sesión" (color `AppColors.error`, chevron) → `context.read<AuthBloc>().add(LogoutRequested())`.
  - Imports nuevos: `auth_bloc.dart`, `auth_event.dart`, `profile_edit_screen.dart`.
- `progreso_screen.dart` — nueva sección `_EquippedPatchesSection` (widget privado, montado entre `_BadgesSection` y `_RouteHistorySection`): `initState` → `LoadPatches`; `PatchesLoading` → spinner compacto; `PatchesLoaded` → grid 3 columnas (íconos + nombres, glow ámbar para earned — convenciones de `PatchesVitrine._patchCard` visual, sin su lógica de showcase); `PatchesError` → texto muted "No se pudieron cargar los parches". Renderiza solo `patch.earned` con contador "X/Y equipados".
- Resultado M-PN-3: tras el rewiring, el ÚNICO import de `ProfileScreen` vivo desde el shell (`progreso_screen.dart:9`) desaparece. Referencias restantes — todas FUERA del alcance del grep acotado (ver nota de enmienda): `profile_screen.dart:16` (import de `showcase_profile_screen` dentro de `features/profile/`, conservado a propósito — el archivo queda inalcanzable pero intacto), `features_archive/dashboard_screen.dart:19` (archivado) y `showcase/showcase.dart:10` (barrel export, no es navegación).

> **Enmienda M-PN-3 (revisión fresh-context, fix W1):** el spec se reescribe de un grep crudo de 'cero imports' a un assert de **ALCANZABILIDAD acotada desde el shell** — el test grepea imports de `profile_screen.dart`/`showcase_profile_screen.dart` en `lib/` EXCLUYENDO `features/profile/`, `features_archive/` y el barrel `showcase/showcase.dart` (delta spec editado en el mismo cambio; ver 1.4). Sin esta enmienda el grep crudo fallaría: `profile_screen.dart:16` importa `showcase_profile_screen.dart` y `:78` construye `ShowcaseProfileScreen()` — archivos conservados a propósito (M-PN-3).

### 1.3 Diagrama de secuencia — gear → Settings → acciones

```
ProgresoScreen            SettingsScreen             ProfileEditScreen      AuthBloc
   │  gear tap                │                            │                   │
   │  push(SettingsScreen) ──>│                            │                   │
   │                          │  (CUENTA: display name)    │                   │
   │                          │  'Editar perfil' tap       │                   │
   │                          │  push(ProfileEditScreen) ─>│                   │
   │                          │  ... save → pop           │                   │
   │                          │  'Cerrar sesión' tap                          │
   │                          │  add(LogoutRequested()) ─────────────────────>│
   │                          │                            │                   │ signOut()
   │                          │                            │                   │ → Unauthenticated
   │                          │                            │                   │ → shell → LoginScreen
```

### 1.4 Testing por capa

| Capa | Spec | Test | Approach |
|------|------|------|----------|
| Widget | M-PN-1 | Gear de Progreso → `SettingsScreen` visible; `ProfileScreen` nunca pusheado | Widget test con fakes (`SupabaseClient` noSuchMethod — patrón `raid_bloc_test.dart`); `_SeededBloc` para `ProgresoBloc`/`MotoposadasBloc` |
| Widget | M-PN-2 | Settings renderiza "Editar perfil" → push `ProfileEditScreen`; "Cerrar sesión" → `LogoutRequested` registrado en un `AuthBloc` test-only (`dispatched[]` — patrón `_SeededBloc` del skill) | `test/features/settings/screens/settings_screen_actions_test.dart` |
| Widget | M-PN-4 | "Parches equipados" renderiza desde `PatchesLoaded` (fixture: 2 earned + 1 no) — grid con solo earned + contador; `LoadPatches` despachado | `test/features/progression/screens/progreso_equipped_patches_test.dart` (PatchesBloc real con fake client o `_SeededBloc`) |
| Unit (grep) | M-PN-1/M-PN-3 | Mapa de navegación ACOTADO (shell-reachable): `lib/` (excluyendo `features/profile/`, `features_archive/` y el barrel `showcase/showcase.dart`) tiene CERO imports de `profile_screen.dart`/`showcase_profile_screen.dart` — los archivos de perfil conservados se importan entre sí a propósito (p. ej. `profile_screen.dart:16`) y quedan fuera de alcance por diseño | `test/features/profile/screens/profile_navigation_map_test.dart` (lee archivos con `dart:io`, assert por `contains`, directorios excluidos en la colección de rutas) |
| Regresión | M-PN-2 | `profile_screen_entry_test.dart` existente sigue verde (ProfileScreen conserva su AppBar; queda inalcanzable pero intacto) | — |

### 1.5 Rollback

Revertir los hunks: gear → `ProfileScreen`; quitar las dos filas de Settings; quitar `_EquippedPatchesSection` y `_PhotosSection` (el álbum vuelve a su estado previo: solo montado en `showcase_profile_screen.dart:227`); revertir `ProgresoLoaded.photos` en bloc/state. Sin cambio de schema. `ProfileScreen`/`ShowcaseProfileScreen` nunca se borran.

---

## 2. W2 — CTA de "Mi motoposada" en todos los estados (M-MPC-1..4)

### 2.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Estrategia | Endurecer `_MiMotoposadaCard` existente (`progreso_screen.dart:206-297`) | Reescribir la sección con otro widget | **Endurecer el widget existente** | La hipótesis P0-4 (stale APK) no exime el hardening: el widget provablemente renderiza en los 3 estados (`:162-167` loading / `:171-184` owned / `:186-200` empty); el fix es defensivo + tests + re-verificación en dispositivo. |
| Fallback sin action | CTA ausente → footer informativo muted ("Gestiona tu casa de motero en el mapa") sin botón muerto | Botón renderizado pero deshabilitado | **Footer informativo, sin botón muerto** | M-MPC-3: "no dead button". El código actual solo renderiza el botón si `actionLabel != null && onAction != null` (`:268`) — con ambos ausentes el card queda sin CTA; el fallback lo hace visiblemente informativo. Un botón deshabilitado es exactamente la clase de UI inerte que P0-3 prohíbe. |
| Colores / altura | Colores explícitos (`AppColors.textPrimary`/`textMuted` sobre `surface` ya fijado) + `ConstrainedBox(minHeight: 76)` | Depender del estilo ambiente | **Explícitos** | M-MPC-3: sin colisiones de superficie; min-height garantiza el área táctil del CTA. |
| Typo | `'OFrecer MI CASA'` → `'Ofrecer MI CASA'` | — | **Corrección puntual** | M-MPC-2 (`:191`); el test asserts ausencia del string viejo. |

### 2.2 Testing por capa

| Capa | Spec | Test | Approach |
|------|------|------|----------|
| Widget | M-MPC-1 | Estado loading: título 'Mi motoposada' + subtitle 'Cargando…' visibles, card nunca blank | `_SeededBloc` de `MotoposadasBloc` (patrón skill: `seed(MotoposadasLoading())` + `pump` doble) — `test/features/progression/screens/progreso_motoposada_card_test.dart` |
| Widget | M-MPC-1 | Estado owned (`MyMotoposadasLoaded` con casa_motero): CTA 'GESTIONAR' visible; tap → `MyMotoposadaScreen` | Ídem, seed del estado |
| Widget | M-MPC-1/M-MPC-2 | Estado empty: CTA 'Ofrecer MI CASA' visible; tap → `CreateMotoposadaScreen(mode: casaMotero)`; `'OFrecer MI CASA'` AUSENTE del árbol | Ídem |
| Widget | M-MPC-3 | Colores explícitos y min-height asserts vía `tester.widget<Container>`; card sin action → footer informativo, sin botón | Ídem |
| Device | M-MPC-4 | Re-verificación visual del usuario en APK reconstruido (versiónCode bump) | Manual |

### 2.3 Rollback

Revertir los hunks del card + el typo. Sin schema. Los tests se revierten con ellos.

---

## 3. W3 — Registro de viajes de raid (M-RTR-1..6)

### 3.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Vínculo raid→tracker | Botón **"INICIAR VIAJE"** en `RaidJoinSheet` (rama `joined`) que cierra el sheet y pushea `RouteTrackerScreen(raidId: ...)` | Navegar automáticamente al unirse (en `_join`) | **Opción A — botón explícito** | `JoinRaid` es una actualización local async del bloc (`raid_bloc.dart:94+`); navegar en el dispatch crearía una race entre el estado `joined` y el push. El botón aparece cuando `joined == true` (el sheet ya re-renderiza con el estado del bloc, `raid_join_sheet.dart:75-85`) y solo para participantes. El sheet es compartido por los 4 call sites (`rodar_screen.dart:270,612`, `raid_list_screen.dart:430`, `explorar_screen.dart:101`) → el entry point llega a todas las superficies sin cableado extra. `raids.id` es BIGSERIAL → `int` Dart. Import cross-feature raids→tracker, aceptado (mismo patrón que el sheet ya usa con RaidBloc). |
| Persistencia de waypoints | Inserts directos a `raid_waypoints` con RLS owner-only | RPC SECURITY DEFINER `insert_waypoint(...)` | **Inserts directos** | Escritura de UNA tabla, columna `user_id` directa, sin invariantes cross-tabla → las políticas directas del repo (`007:95-96` routes pattern) bastan; un RPC añade superficie sin valor (contraste con 026 donde el RPC era necesario por atomicidad de 2 filas + floor ≥300 m). M-RTR-5 (rechazo atómico) lo da el `WITH CHECK` con `public.is_raid_participant(raid_id)` (ver 3.2). |
| `checkpoints_taken` | **NO se incrementa desde la app** | RPC `increment_checkpoints(p_participant_id)` (001:67-80) o UPDATE vía `rp_update_own` (020:148) | **No tocar el contador** | Verificado: `increment_checkpoints` solo lo llama la edge fn `validate-checkpoint` (`validate-checkpoint/index.ts:169`) DESPUÉS de insertar en `raid_checkpoint_verifications` (`:146`), que es lo que dispara `trg_award_coins_on_checkpoint` (`019:123-125`). El reward loop de coins está anclado a `raid_checkpoint_verifications`, NO al contador; y `finish-raid` lee `checkpoints_taken >= totalCheckpoints` para el bono (finish-raid/index.ts:70). Un incremento app-side inflaría ese umbral sin validación real (la tabla tiene `anti_cheat_flags`/`is_flagged`, 003:148-149) y NO dispararía el trigger de coins — rompe la semántica del contador sin aportar recompensa. Las paradas son una feature aparte: filas en `raid_waypoints` con orden secuencial. Además evita el lookup del `raid_participants.id` (el RPC toma `p_participant_id`, no raid/user). |
| Alcance del control "Marcar parada" | Visible SOLO en viajes raid-linkeados (`raidId != null`) | Visible siempre, persistir a `raid_waypoints` con raid NULL o a `saved_routes` | **Solo raid-linked** | `raid_waypoints.raid_id` es NOT NULL; `saved_routes` no tiene columna de waypoints y embeberlos en `polyline_json` no es un trace consultable (la proposal rechazó JSONB por la misma razón). Los viajes standalone conservan el HUD actual. |
| Origen / destino auto | Origen = primer fix GPS → fila orden 0; destino = última posición al detener → fila orden N+1 | Pedir origen/destino al usuario | **Auto (M-RTR-1)** | El tracker ya registra el primer punto al start (`location_tracking_service.dart:145-146`); el bloc captura `_lastFix` en `onUpdate`. El usuario nunca ingresa origen/destino. |
| Trace post-trip | `PostTripResult` gana `waypoints: List<LatLng>` + `raidId: int?`; el mini-map agrega MarkerLayer de paradas entre start/end | Re-query de `raid_waypoints` en el summary | **En memoria vía PostTripResult** | M-RTR-3: el summary ya recibe `PostTripResult` (`post_trip_summary_screen.dart:15-36`, construido en `route_tracker_screen.dart:320-328`); el polyline ya recorre todos los puntos (`:303-310` PolylineLayer con `r.points`, latlong2 directo). Sin query extra en una pantalla efímera. La persistencia DB (M-RTR-2) es independiente: filas escritas al momento del press. |
| `_save` de `saved_routes` | Alinear payload a 002 + corregir el no-op del summary | — | **Alinear y corregir** | Ver 3.3. Doble bug verificado: claves inexistentes (PGRST204 tragado, `:156`) Y early-return del summary (`_save` exige `TrackerRecording`, pero tras `StopRecording` el estado es `TrackerIdle` → GUARDAR del summary no guarda nada). |
| Errores que surfacen | Estados `TrackerSaveFailed`/`TrackerSaveSucceeded` + BlocListener SnackBar en tracker y summary | try/catch en el widget | **Estados del bloc** | M-RTR-6. El save vive en el bloc (`route_tracker_screen.dart:131-157`); el bloc es la única vía limpia de exponer fallo a las dos pantallas (HUD y summary) sin duplicar lógica. |
| Resume tras background (raid) | Re-fetch de `raid_waypoints` de la MISMA sesión (created_at >= startedAt del trip) al `ResumeFromCheckpoint` | Ignorar | **Re-fetch acotado** | Los waypoints ya persisten al presionar (M-RTR-2 ✓), pero el trace en memoria se pierde si la app fue matada; el re-fetch por `(raid_id, user_id, created_at >= trip.startedAt)` restaura paradas previas y el contador de orden. Acotado por ventana temporal para no mezclar viajes del mismo raid. |

### 3.2 Migración 028 — SQL exacto

File: `supabase/migrations/028_raid_waypoints.sql` (siguiente ordinal tras `027_dedupe_achievements.sql`; verificado que `raid_waypoints` NO existe en el repo).

```sql
-- MIGRATION 028: raid_waypoints (W3 — raid trip registration)
-- Additiva e idempotente. Convenciones del repo: BEGIN/COMMIT, IF NOT EXISTS,
-- DROP POLICY IF EXISTS antes de recrear, políticas directas SIN subqueries
-- (clase de recursión RLS 012/013), ids BIGINT (consistencia con BIGSERIAL de
-- raids/raid_participants, 003).
BEGIN;

CREATE TABLE IF NOT EXISTS raid_waypoints (
    id          BIGSERIAL PRIMARY KEY,
    raid_id     BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    orden       INT NOT NULL CHECK (orden >= 0),
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Replay del trace por raid: (raid_id, orden) es la secuencia
-- origen(0) → paradas(1..N) → destino(N+1).
CREATE INDEX IF NOT EXISTS idx_raid_waypoints_raid_orden
    ON raid_waypoints(raid_id, orden);
CREATE INDEX IF NOT EXISTS idx_raid_waypoints_user
    ON raid_waypoints(user_id);

ALTER TABLE raid_waypoints ENABLE ROW LEVEL SECURITY;

-- Owner-only DIRECTAS (patrón routes 007:95-96, casa_motero_details 026:70-77).
-- M-RTR-4: SELECT/UPDATE/DELETE restringidos a auth.uid() = user_id.
-- M-RTR-5 (cerrado, fix W2): el INSERT exige PROPIEDAD DE LA FILA Y
-- pertenencia al raid — WITH CHECK (auth.uid() = user_id AND
-- public.is_raid_participant(raid_id)). El helper SECURITY DEFINER STABLE
-- (020:17-25, sin recursión; ya usado en raids_select_participant 020:88 y
-- rp_select_same_raid 020:128) hace el rechazo atómico: un insert para un
-- raid no participado no deja fila ni estado parcial. El host ya es
-- participante (raid_bloc.dart:80-84). Los waypoints son datos del viaje
-- propio: SELECT/UPDATE/DELETE quedan owner-only SIN membership check
-- (un ex-participante conserva su traza). Cierre de ambigüedad del spec M-RTR-5.
DROP POLICY IF EXISTS "rw_select_own" ON raid_waypoints;
CREATE POLICY "rw_select_own" ON raid_waypoints
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "rw_insert_own" ON raid_waypoints;
CREATE POLICY "rw_insert_own" ON raid_waypoints
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND public.is_raid_participant(raid_id)
    );

DROP POLICY IF EXISTS "rw_update_own" ON raid_waypoints;
CREATE POLICY "rw_update_own" ON raid_waypoints
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "rw_delete_own" ON raid_waypoints;
CREATE POLICY "rw_delete_own" ON raid_waypoints
    FOR DELETE USING (auth.uid() = user_id);

COMMIT;
```

### 3.3 Fix de `_save` — payload alineado a 002

`_save` (`route_tracker_screen.dart:131-157`) hoy escribe `distance/duration/avg_speed/max_speed/polyline` (claves inexistentes → PGRST204 tragado). Columnas reales de `saved_routes` (002:161-178): `total_distance_m DOUBLE PRECISION`, `duration_seconds INT`, `avg_speed_kmh DOUBLE PRECISION`, `max_speed_kmh DOUBLE PRECISION`, `points_count INT`, `polyline_json TEXT`, `start_lat/lng`, `end_lat/lng`, `started_at`, `ended_at`.

```dart
// Payload builder puro (unit-testable) — event.result ?? estado grabando.
// FIX W3: devuelve null si no hay trace (points < 2) en vez de reventar en
// points.first/last (:210-211) — el mini-map ya contempla el caso
// (post_trip_summary_screen.dart:274 hasPoints = r.points.length >= 2).
Map<String, dynamic>? buildSavedRoutePayload({
  required String userId,
  required String name,
  required double distanceKm,
  required int durationSec,
  required double avgSpeedKmh,
  required double maxSpeedKmh,
  required List<LatLng> points,
  required DateTime? startedAt,
}) {
  if (points.length < 2) return null;
  return {
    'user_id': userId,
    'name': name,
    'total_distance_m': (distanceKm * 1000).round(),        // metros (002:165)
    'duration_seconds': durationSec,                        // INT (002:166)
    'avg_speed_kmh': avgSpeedKmh,                           // (002:167)
    'max_speed_kmh': maxSpeedKmh,                           // (002:168)
    'points_count': points.length,                          // (002:169)
    'polyline_json': jsonEncode(                            // TEXT (002:170):
      points.map((p) => [p.latitude, p.longitude]).toList(),// [[lat,lng],...] plano
    ),                                                      // NO GeoJSON (el mapa
                                                            //  consume List<LatLng>)
    'start_lat': points.first.latitude, 'start_lng': points.first.longitude,
    'end_lat': points.last.latitude,  'end_lng': points.last.longitude,
    'started_at': startedAt?.toUtc().toIso8601String(),
    'ended_at': DateTime.now().toUtc().toIso8601String(),
  };
}
```

Decisión de codificación de `polyline_json`: **array plano `[[lat,lng],...]`** (no GeoJSON). Razón: `PostTripResult.points` y el mini-map consumen `List<LatLng>` (latlong2); GeoJSON añade estructura que nadie lee; el decode es `jsonDecode` → `List<List<double>>` → `LatLng`. El mismo array plano es lo que ya persiste el checkpoint (`location_tracking_service.dart:227-229`).

Cambios al evento/flujo de save:

- `SaveRoute` gana `final PostTripResult? result;` (nullable) — el HUD durante grabación no lo pasa (usa el estado `TrackerRecording`); el summary pasa `widget.result`. **Corrige el no-op**: tras `StopRecording` el estado es `TrackerIdle`, y `_save` hoy retorna antes de guardar.
- `_save`: construye payload con `event.result ?? (state as TrackerRecording)`; si `buildSavedRoutePayload` devuelve `null` (points < 2, FIX W3) → `emit(TrackerSaveFailed('No hay puntos de ruta para guardar'))` SIN insert (sin crash); si no, insert con `.select().single()` para capturar el `id`; éxito → `emit(TrackerSaveSucceeded(savedRouteId: id))` + `emit(TrackerIdle())` + `add(LoadSavedRoutes())`; fallo → `emit(TrackerSaveFailed(message))` (SIN `TrackerIdle`: el usuario puede reintentar; el flujo stop→summary no se rompe porque el summary ya está abierto).
- `PostTripSummaryScreen` y `RouteTrackerScreen` ganan un `BlocListener<TrackerBloc, TrackerState>`: `TrackerSaveSucceeded` → SnackBar "Ruta guardada" (+ pop del summary); `TrackerSaveFailed` → SnackBar con el mensaje real (nunca `catch (_) {}`).
- Read-side: `_buildHistoryTab` (`route_tracker_screen.dart:576-577`) lee `r['distance']`/`r['duration']` — claves que tampoco existen → alinear a `total_distance_m`/`duration_seconds` (mismo bug class; sin esto el historial mostraría 0 km tras el fix). `route_history` (Progreso, 010:182-196) NO se toca (M-ERV-4).

### 3.4 Flujo nuevo — secuencia completa

```
RaidJoinSheet              TrackerBloc                     raid_waypoints        saved_routes       PostTripSummary
   │ 'INICIAR VIAJE' (joined)                                  │                     │                     │
   │ pop(sheet) + push(RouteTrackerScreen(raidId: 42))         │                     │                     │
   │  → GRABAR → StartRecording(raidId: 42)                    │                     │                     │
   │──────────────────────────────────────────────────────────>│                     │                     │
   │                              │ primer fix GPS (onUpdate)  │                     │                     │
   │                              │ INSERT (raid_id:42,user_id:auth.uid(),orden:0, │                     │
   │                              │        lat,lng)  ← origen auto (M-RTR-1)       │                     │
   │                              │───────────────────────────>│                     │                     │
   │  HUD: 'Marcar parada' (solo raidId != null)               │                     │                     │
   │  AddWaypoint → INSERT (orden: ++contador)                 │                     │                     │
   │                              │───────────────────────────>│                     │                     │
   │  DETENER → StopRecording:                                  │                     │                     │
   │                              │ INSERT (orden: N+1) ← destino auto (M-RTR-1)   │                     │
   │                              │───────────────────────────>│                     │                     │
   │  push(PostTripSummary(PostTripResult(points, waypoints,   │                     │                     │
   │        raidId)))                                          │                     │                     │
   │──────────────────────────────────────────────────────────────────────────────────────────────────>│
   │  GUARDAR RUTA → SaveRoute(name, result)                   │                     │                     │
   │                              │ INSERT total_distance_m, duration_seconds,     │                     │
   │                              │   avg_speed_kmh, max_speed_kmh, polyline_json, │                     │
   │                              │   points_count, start/end, started_at/ended_at │                     │
   │                              │────────────────────────────────────────────────>│                     │
   │                              │<─ ok (id)                                        │                     │
   │                              │ TrackerSaveSucceeded(id) + TrackerIdle          │                     │
   │                              │──────────────────────────────────────────────────────────────────>│
   │                              │   (summary: SnackBar + pop; fallo → SnackBar error, sin tragar)    │
```

Detalles de implementación en `route_tracker_screen.dart` (el `TrackerBloc` vive en este archivo, `:59-174`):

- `RouteTrackerScreen({super.key, this.raidId})` — `final int? raidId;`.
- Eventos: `StartRecording(int? raidId)`, `AddWaypoint()`, `ResumeFromCheckpoint(int? raidId)`, `SaveRoute(name, {PostTripResult? result})`.
- Estado `TrackerRecording` gana `final List<LatLng> waypoints; final int? raidId;` (emitido en cada `onUpdate`; `AddWaypoint` re-emite con `[...waypoints, lastFix]`).
- `_start`: guarda `_raidId`; en el PRIMER `onUpdate` con `_raidId != null` inserta la fila orden 0 (origen). Fallo de inserción → `TrackerError` (SnackBar) sin matar la grabación.
- `_stop` (async): si `_raidId != null`, inserta destino orden `waypointCount + 1` con `_lastFix`; limpia `_raidId`/contador. El push del summary usa `recording.waypoints`/`recording.raidId`.
- `_resumeFromCheckpoint(raidId)`: si `raidId != null`, `SELECT raid_id, orden, lat, lng FROM raid_waypoints WHERE raid_id = ? AND user_id = ? AND created_at >= <trip.startedAt> ORDER BY orden` → seedea `waypoints` + contador.

### 3.5 Testing por capa

| Capa | Spec | Test | Approach |
|------|------|------|----------|
| Unit | M-RTR-6 | `buildSavedRoutePayload` mapea a las claves de 002 (`total_distance_m` en metros, `duration_seconds`, `avg_speed_kmh`, `max_speed_kmh`, `polyline_json` string JSON `[[lat,lng],...]`, `points_count`, start/end, started/ended UTC) y NUNCA a `distance/duration/avg_speed/max_speed/polyline` | `test/features/tracker/bloc/tracker_bloc_waypoints_test.dart` — función pura |
| Unit | M-RTR-6 | `buildSavedRoutePayload` con points vacío o < 2 → devuelve `null` SIN crash (guard FIX W3) y `_save` emite `TrackerSaveFailed('No hay puntos de ruta para guardar')` sin INSERT | Ídem |
| Unit | M-RTR-2 | Orden de waypoints: origen 0, paradas 1..N secuenciales, destino N+1 (contador) | Ídem, bloc con fake client |
| Datasource/RLS (noSuchMethod) | M-RTR-4/M-RTR-5 | INSERT con `user_id != auth.uid()` → `PostgrestException` propagado (rechazo atómico, sin fila); INSERT a raid NO participado → rechazado (assert de `is_raid_participant` en el WITH CHECK); INSERT owner + participante → persiste y se lee de vuelta | Fakes `FakeSupabaseClient` (patrón `raid_join_sheet_test.dart`) |
| Datasource | M-RTR-6 | `_save` invoca `from('saved_routes').insert(payload)` con `.select()` y NO traga el error (assert del estado `TrackerSaveFailed` emitido) | Ídem |
| Widget | M-RTR-1 | RaidJoinSheet: rama `joined` muestra "INICIAR VIAJE"; tap → pop + push `RouteTrackerScreen` con `raidId` del raid; rama no-unido NO lo muestra | Extiende `test/features/raids/widgets/raid_join_sheet_test.dart` |
| Widget | M-RTR-2 | HUD grabando con raidId: "Marcar parada" visible; tap → `AddWaypoint` registrado (fake bloc, `dispatched[]`); sin raidId → ausente | `tracker_bloc_waypoints_test.dart` (widget) |
| Widget | M-RTR-3 | Summary: markers de parada renderizados en orden entre start y end (por índice) | `test/features/tracker/screens/post_trip_summary_waypoints_test.dart` |
| Migration guard | M-RTR-4/M-RTR-5 | `028_raid_waypoints.sql` contiene: `CREATE TABLE`, `BIGSERIAL`, políticas `rw_select_own/rw_insert_own/rw_update_own/rw_delete_own`, `WITH CHECK (auth.uid() = user_id)`, `is_raid_participant` dentro de `rw_insert_own`, y NINGÚN `EXISTS (` en bodies de policy | `test/supabase/migration_028_029_content_test.dart` (patrón `migration_026_content_test.dart`, `dart:io`) |

Command gates: `flutter test` (all) + `flutter analyze` (config: `apply.strict_tdd: true`).

### 3.6 Rollback

- Schema: `DROP TABLE raid_waypoints;` (migración 028 es solo tabla nueva — aditiva, sin datos existentes).
- App: revertir los hunks de tracker/join-sheet/summary; `_save` vuelve al payload viejo (el bug PGRST204 preexistente vuelve a ser invisible, pero el rollback es por-feature y no rompe nada).

---

## 4. W4 — Fotos de conquista post-viaje (M-CPU-1..4)

### 4.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Bucket de storage | **Bucket NUEVO `conquest-photos`** (público lectura, insert/delete propios por prefijo `auth.uid()/`) siguiendo `008:35-47` (profile-images) | Reusar `place-photos` (008:58-65) | **Bucket nuevo** | Semántica: `place-photos` es contenido de POI (fotos de lugares); `conquest_photos` es contenido de usuario con namespace por user_id. Mezclar rompe la política de borrado (un delete de foto de conquista borraría/afectaría assets de POI) y el path-namespacing de `profile_images_insert_own` (`008:41`) es el patrón correcto para álbum personal. La policy de `place_photos_insert_auth` (`008:61-65`) ni siquiera exige namespace. Migración `029` propia (rollback por feature independiente). |
| Firma de inserción | `insertConquestPhoto(userId:, source:, sourceId:, photoUrl:, caption:)` — firma real verificada (`showcase_remote_datasource.dart:97-111`) | Insert directo desde la pantalla | **Usar `insertConquestPhoto`** | M-CPU-2: el método tiene CERO call sites (por eso FOTOS siempre 0, `progreso_bloc.dart:30/:48`); este flujo es su primera invocación. |
| Orquestación del flujo | Servicio inyectable `ConquestPhotoUploader` (typedef) que hace upload + `insertConquestPhoto`, llamado desde el summary | El bloc hace upload e insert | **Servicio inyectable (UI layer)** | El picker (`image_picker ^1.2.3`, pubspec:43) es I/O de plataforma; el patrón del repo para side-effects no-mockeables es typedef inyectable (patrón `whatsapp_launcher`, skill §test conventions). El bloc no toca `File`. Tests inyectan un fake que registra llamadas. |
| `source`/`source_id` | Raid-linked: `source: 'raid'`, `sourceId: raidId.toString()`. Standalone: `source: 'route'`, `sourceId: savedRouteId.toString()` (tras guardar) | Siempre `source: 'raid'` | **Raid → 'raid'; standalone → 'route'** | M-CPU-2 exige `source: 'raid'` con `<raid/trip id>`; el CHECK de `conquest_photos.source` (`011:243`) incluye `'route'` — el trip standalone queda asociado a su `saved_routes` id. El CHECK NO incluye `null` → source es obligatorio. |
| Timing del insert | Raid: inmediato al pickear (raidId conocido). Standalone: upload inmediato + insert encolado hasta que `TrackerSaveSucceeded` entregue `savedRouteId` | Exigir guardar antes de fotos | **Upload inmediato + cola de rows para standalone** | No bloquear UX; si el save falla, la cola no se vacía y el SnackBar dice "Guarda la ruta para adjuntar las fotos" (el archivo ya subido queda en storage — residual documentado). La fila NUNCA se inserta con `source_id` null. |
| RLS | Sin políticas nuevas: `cp_select_public`/`cp_insert_own`/`cp_delete_own` (`011:262-264`) siguen siendo la frontera | Policy nueva | **Sin cambios RLS** | M-CPU-4: el insert pasa por `cp_insert_own` (`WITH CHECK auth.uid() = user_id`) — el `userId` del uploader deriva de `auth.currentUser.id`; un mismatch = error RLS visible. Nota: NO hay policy de UPDATE (flujo insert-only; sin edición de caption). |
| Geofence-arrival | Fase 2 (fuera de scope) | Incluir prompt por llegada a POI | **Fase 2** | La base de F-B2 es la foto en el post-trip del raid (la "llegada al destino"); `motoposada_visits` (insert en `route_tracker_screen.dart:264` a tabla sin migración, catch vacío `:271-273`) NO se copia como patrón ni se arregla en este cambio. `GeofenceService` sigue siendo tracker-only (SnackBar de visita). |

### 4.2 Migración 029 — SQL exacto (bucket)

File: `supabase/migrations/029_conquest_photos_bucket.sql`.

```sql
-- MIGRATION 029: bucket conquest-photos (W4 — conquest photos upload)
-- Patrón de 008_storage.sql: buckets públicos (008:9-14) + insert/delete
-- propios por prefijo de user_id (008:35-47, profile-images).
BEGIN;

INSERT INTO storage.buckets (id, name, public) VALUES
    ('conquest-photos', 'conquest-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Lectura pública (las fotos de conquista son públicas en el álbum; la
-- frontera de borrado/inserción es del dueño).
DROP POLICY IF EXISTS "conquest_photos_select_public" ON storage.objects;
CREATE POLICY "conquest_photos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'conquest-photos');

-- Insert/delete propios: path con prefijo <user_id>/ (008:41-47).
DROP POLICY IF EXISTS "conquest_photos_insert_own" ON storage.objects;
CREATE POLICY "conquest_photos_insert_own" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'conquest-photos'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

DROP POLICY IF EXISTS "conquest_photos_delete_own" ON storage.objects;
CREATE POLICY "conquest_photos_delete_own" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'conquest-photos'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

COMMIT;
```

### 4.3 Flujo — post-trip → foto → storage → insert

```
PostTripSummaryScreen        ImagePicker        conquest-photos (storage)      insertConquestPhoto        conquest_photos
   │ 'AÑADIR FOTOS' tap           │                        │                            │                        │
   │ pickImage(...) ─────────────>│                        │                            │                        │
   │<─ XFile? ────────────────────│                        │                            │                        │
   │ ConquestPhotoUploader.upload:│                        │                            │                        │
   │  storage.upload('<userId>/<millis>_<n>.jpg', file)    │                            │                        │
   │──────────────────────────────────────────────────────>│                            │                        │
   │<─ path ──────────────────────│                        │                            │                        │
   │  getPublicUrl → photoUrl     │                        │                            │                        │
   │ insertConquestPhoto(userId, source: raid?'raid':'route',                        │                        │
   │    sourceId: raidId ?? savedRouteId, photoUrl, caption)                        │                        │
   │────────────────────────────────────────────────────────────────────────────────>│                        │
   │                                                                                 │ insert (cp_insert_own) │
   │                                                                                 │───────────────────────>│
   │<─ ok ───────────────────────────────────────────────────────────────────────────│                        │
   │  SnackBar 'Foto añadida' / error RLS → SnackBar con mensaje (sin tragar)                                  │
   │  (standalone: si no hay savedRouteId aún → cola local; flush al recibir                                   │
   │   TrackerSaveSucceeded; si TrackerSaveFailed → SnackBar 'Guarda la ruta…')                                │
```

Counter + álbum (M-CPU-3/M-CPU-4): UNA sola lectura. `ProgresoBloc` selecciona TODAS las filas de `conquest_photos` (`progreso_bloc.dart:30`), las conserva casteadas a `List<ConquestPhotoModel>` vía `ConquestPhotoModel.fromMap` (`conquest_photo_model.dart:23-33`) y las expone en `ProgresoLoaded.photos`. El contador (`photosCount`, `:48`) y la nueva sección `_PhotosSection` de Progreso (que renderiza el `PhotoAlbum` stateless existente, `photo_album.dart:9-18`, acepta `List<ConquestPhotoModel>`) derivan de la MISMA lista: al recargar Progreso (LoadProgreso) el contador sube y el álbum lista la fila nueva, sin query ni fuente paralela. `fetchConquestPhotos`/`ShowcaseBloc` NO se tocan — `ShowcaseProfileScreen` conserva su álbum inalcanzable pero intacto (M-PN-3); el widget test de M-CPU-4 ahora vive en Progreso (fix B1).

### 4.4 Testing por capa

| Capa | Spec | Test | Approach |
|------|------|------|----------|
| Widget | M-CPU-1/M-CPU-2 | "AÑADIR FOTOS" abre el picker (fake inyectado) y dispara upload + `insertConquestPhoto(source: 'raid', sourceId: raidId)` exactamente una vez; el string `'Fotos — próximamente'` está AUSENTE | `test/features/tracker/screens/post_trip_summary_waypoints_test.dart` (uploader fake) |
| Datasource | M-CPU-2/M-CPU-4 | `insertConquestPhoto` invocada con la firma real (userId/source/sourceId/photoUrl/caption); payload de fila: `user_id`, `source`, `source_id`, `photo_url` | `test/features/showcase/data/conquest_photo_upload_test.dart` (noSuchMethod) |
| Unit | M-CPU-2 | Builder del draft de foto: raid → `source='raid'` + `sourceId=raidId`; standalone → `source='route'` + `sourceId=savedRouteId`; nunca otro source | Ídem |
| Widget | M-CPU-3 | Tras insert exitoso, el contador (fixture `photosCount`) y la sección del álbum derivan de la MISMA lista de `ProgresoLoaded.photos` (select único `progreso_bloc.dart:30`) — sin query paralela | Ídem |
| Widget | M-CPU-4 | La sección `_PhotosSection` de Progreso renderiza `PhotoAlbum` desde un fixture de `ProgresoLoaded` con N fotos — M-CPU-4 verificable EN Progreso; sin fotos → la sección colapsa (`PhotoAlbum` devuelve `SizedBox.shrink`, photo_album.dart:16-18) | `test/features/progression/screens/progreso_photos_section_test.dart` (patrón `_SeededBloc`) |
| Migration guard | M-CPU-4 | `029_conquest_photos_bucket.sql` contiene el INSERT del bucket `'conquest-photos'` + las 3 policies + `auth.uid()::text || '/%'`; NO reutiliza `'place-photos'` | `migration_028_029_content_test.dart` |

### 4.5 Rollback

- Schema: `DROP POLICY … ON storage.objects` + borrar el bucket (o dejarlo huérfano — aditivo, sin impacto); migración 029.
- App: revertir hunks del summary + uploader; el placeholder "Fotos — próximamente" vuelve.

---

## 5. W5 — Visibilidad de raids expirados (M-ERV-1..5)

### 5.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Sitios del filtro | Rodar markers (`rodar_screen.dart:251-259`) + `fetchUpcomingRaids` (`explorar_datasource.dart:38-55`) — SOLO dos | Incluir RaidBloc / raid_list_screen | **Dos read sites** | M-ERV-1/M-ERV-2/M-ERV-3/M-ERV-5 explícitos: `RaidBloc._onLoadRaids` (`raid_bloc.dart:42-45`) NO gana filtro — `raid_list_screen` sigue mostrando todo (statuses y fechas) como hoy. Progreso (route_history, `progreso_bloc.dart:36`) y el flujo post-trip intactos (M-ERV-4/M-ERV-5). |
| Comparación de fecha (Dart, markers) | Parsear `scheduled_at` (TIMESTAMPTZ ISO → `DateTime.parse` devuelve UTC) y comparar con `DateTime.now().toUtc()` | Comparar strings ISO | **Parse + `isBefore(now.toUtc())`** | `scheduled_at` es `TIMESTAMPTZ NOT NULL` (003:106); el ISO de PostgREST termina en `Z` y parsea como UTC. Comparación tipada, legible y testeable como función pura `isExpiredRaid(row)`. |
| Filtro server (Explorar) | `.gte('scheduled_at', DateTime.now().toUtc().toIso8601String())` después de `.eq('status','lobby')` | Literal SQL `now()` | **Dart UTC ISO** | Mismo resultado que `now()` (TIMESTAMPTZ parsea el ISO con `Z` como UTC) pero determinista y assertable con fake builders en tests. `toUtc()` es OBLIGATORIO: un string sin offset se interpretaría con la TZ del servidor. Se documenta por qué no `now()` literal: paridad de testeo y una sola fuente de tiempo (cliente). |
| Bottom sheet de Rodar ("PRÓXIMOS RAIDS", `rodar_screen.dart:581-612`) | Intacto (spec-literal) | Filtrarlo también | **Intacto** | M-ERV-5 nombra exactamente "Rodar map markers" y "Explorar upcoming". El sheet es una tercera superficie; filtrarlo excedería el spec. Residual anotado: el header dice PRÓXIMOS RAIDS pero puede listar un raid pasado (ver Open Questions 8.x). |

### 5.2 Cambios exactos

```dart
// rodar_screen.dart — dentro del .where de markers (:251-259), condición nueva:
bool isExpiredRaid(Map<String, dynamic> r) {
  final raw = r['scheduled_at'];
  if (raw == null) return false;
  return DateTime.parse(raw.toString()).isBefore(DateTime.now().toUtc());
}
// filtro: (status in lobby|planned|active) && origin != null && !isExpiredRaid(r)
```

```dart
// explorar_datasource.dart — fetchUpcomingRaids (:38-55), entre eq y order:
.eq('status', 'lobby')
.gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
.order('scheduled_at', ascending: true)
```

Nota: `raid_card._formatDate` (raid_card.dart:243-267, sin `.toLocal()` — day-shift UTC) queda FUERA de scope: W5 toca solo los dos read sites (M-ERV-5).

### 5.3 Testing por capa

| Capa | Spec | Test | Approach |
|------|------|------|----------|
| Unit | M-ERV-1 | `isExpiredRaid`: pasado → true; futuro → false; `scheduled_at` null → false (no rompe filas legacy); comparaciones con `DateTime.utc` | Pura |
| Widget | M-ERV-1 | Raid pasado (lobby, origin no null) → sin marker en Rodar; raid futuro → marker presente | Widget test del builder de markers (fake `RaidBloc` seed) |
| Datasource (noSuchMethod) | M-ERV-2 | `fetchUpcomingRaids` emite `.gte('scheduled_at', <ISO UTC>)` — assert del filtro registrado en el fake builder | `test/features/explorar/data/explorar_datasource_test.dart` |
| Datasource | M-ERV-3 | `RaidBloc._onLoadRaids` NO registra `.gte`/`.lt` de fecha — el select string queda exacto | `raid_bloc_test.dart` (assert de llamadas del fake) |
| Regresión | M-ERV-4/M-ERV-5 | `raid_list_screen` + Progreso history + tests de post-trip pasan sin cambios | Suite completa |

### 5.4 Rollback

Revertir los dos hunks (marker filter + `gte`). Sin schema. `RaidBloc` nunca se tocó.

---

## 6. Resumen de archivos afectados

| Archivo | Acción | Descripción |
|---------|--------|-------------|
| `supabase/migrations/028_raid_waypoints.sql` | Create | `raid_waypoints` (BIGINT ids) + RLS owner-only directa (W3) |
| `supabase/migrations/029_conquest_photos_bucket.sql` | Create | Bucket `conquest-photos` + policies (W4) |
| `lib/core/...` — sin cambios de core | — | El uploader vive en showcase (Clean Architecture) |
| `lib/features/showcase/data/repositories/conquest_photo_repository.dart` | Create | `ConquestPhotoUploader` (typedef) + implementación real: upload a storage + `insertConquestPhoto` (W4) |
| `lib/features/progression/presentation/bloc/progreso_bloc.dart` | Modify | Conserva la lista de `conquest_photos` casteada a `List<ConquestPhotoModel>` (`fromMap`) y la expone en `ProgresoLoaded.photos`; `photosCount` sigue derivando de la misma lista (B1 — M-CPU-4) |
| `lib/features/progression/presentation/bloc/progreso_state.dart` | Modify | `ProgresoLoaded` gana `final List<ConquestPhotoModel> photos` (default `const []`) (B1 — M-CPU-4) |
| `lib/features/progression/presentation/screens/progreso_screen.dart` | Modify | Gear → SettingsScreen (M-PN-1); sección `_EquippedPatchesSection` (M-PN-4); sección `_PhotosSection` con `PhotoAlbum` (B1 — M-CPU-4); `_MiMotoposadaCard` hardening + typo (M-MPC-1..3) |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Modify | Filas "Editar perfil" y "Cerrar sesión" (M-PN-2) |
| `lib/features/raids/presentation/widgets/raid_join_sheet.dart` | Modify | Botón "INICIAR VIAJE" en rama joined → push `RouteTrackerScreen(raidId:)` (M-RTR-1) |
| `lib/features/tracker/presentation/screens/route_tracker_screen.dart` | Modify | `raidId` param; `StartRecording/AddWaypoint/ResumeFromCheckpoint/SaveRoute` con payloads; estado `TrackerRecording` + waypoints/raidId; `_save` alineado a 002 + errores que surfacen; `_buildHistoryTab` read-keys; HUD "Marcar parada" (M-RTR-1/2/6) |
| `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | Modify | `PostTripResult` + waypoints/raidId/photos; markers de parada en mini-map (M-RTR-3); flujo real de fotos (M-CPU-1/2); BlocListener de save |
| `lib/features/dashboard/presentation/screens/rodar_screen.dart` | Modify | Condición `!isExpiredRaid` en markers (M-ERV-1) |
| `lib/features/explorar/data/datasources/explorar_datasource.dart` | Modify | `.gte('scheduled_at', ISO-UTC)` en `fetchUpcomingRaids` (M-ERV-2) |
| `lib/features/showcase/data/datasources/showcase_remote_datasource.dart` | Modify | Primer call site de `insertConquestPhoto` (vía repository) (M-CPU-2) |
| `test/supabase/migration_028_029_content_test.dart` | Create | Guard de contenido de migraciones: 028 (incl. `is_raid_participant` en `rw_insert_own`) + 029 (patrón `migration_026_content_test.dart`) |
| `test/features/progression/screens/progreso_motoposada_card_test.dart` | Create | 3 estados del card + typo (M-MPC) |
| `test/features/progression/screens/progreso_equipped_patches_test.dart` | Create | "Parches equipados" desde `PatchesBloc` (M-PN-4) |
| `test/features/progression/screens/progreso_photos_section_test.dart` | Create | `_PhotosSection` renderiza `PhotoAlbum` desde `ProgresoLoaded` (fixture N fotos); sin fotos → colapsa; M-CPU-4 verificable en Progreso (B1) |
| `test/features/settings/screens/settings_screen_actions_test.dart` | Create | Editar perfil + Cerrar sesión (M-PN-2) |
| `test/features/profile/screens/profile_navigation_map_test.dart` | Create | Grep de mapa de navegación acotado (shell-reachable): cero imports de profile screens fuera de `features/profile/`, `features_archive/` y el barrel (M-PN-1/3) |
| `test/features/raids/widgets/raid_join_sheet_test.dart` | Modify | Extiende: "INICIAR VIAJE" joined/no-joined (M-RTR-1) |
| `test/features/tracker/bloc/tracker_bloc_waypoints_test.dart` | Create | Payload builder, orden de waypoints, `_save` fix + errores, HUD (M-RTR-2/6) |
| `test/features/tracker/screens/post_trip_summary_waypoints_test.dart` | Create | Trace de paradas + flujo de fotos (M-RTR-3, M-CPU-1/2) |
| `test/features/showcase/data/conquest_photo_upload_test.dart` | Create | Firma/llamadas de `insertConquestPhoto`, source/sourceId (M-CPU-2/4) |
| `test/features/explorar/data/explorar_datasource_test.dart` | Create | `gte` en upcoming; RaidBloc sin filtro (M-ERV-2/3) |

**Totales: 13 NEW, 11 MODIFIED, 0 DELETED.** (Los screens de perfil se conservan — deuda → issue.)

---

## 7. Migraciones y rollout

- `028_raid_waypoints.sql` (W3) y `029_conquest_photos_bucket.sql` (W4): **aditivas e idempotentes** (IF NOT EXISTS / ON CONFLICT / DROP POLICY IF EXISTS). No tocan tablas existentes; no backfill; no destrucción.
- **Deploy-side ANTES del APK (orden obligatorio del repo)**: aplicar 028 + 029 a prod antes de distribuir el APK nuevo; el APK viejo sigue funcionando contra el schema aditivo (nada que lea se rompe: la app vieja ni escribe `raid_waypoints` ni usa el bucket). Prerrequisito verificado: 028 depende solo de `raids` (003) y `users`; 029 solo de `storage.buckets`.
- **Revisión del usuario antes de aplicar**: presentar ambos SQL con resumen por statement (regla del repo: nunca correr migraciones a prod sin revisión previa del usuario).
- **Verificación en apply**: contra `information_schema` en prod (convención del skill): columnas reales de `saved_routes` (¿coinciden con 002? la app escribía ad-hoc) y ausencia de objetos `raid_waypoints`/bucket `conquest-photos` previos.
- **Version bump**: `pubspec version: X.Y.Z+N` con `+N` estrictamente mayor al release anterior (versionCode; verificar con `aapt dump badging` del APK previo) ANTES de buildear.
- Orden de prerequisitos del trail: 024 → 025 → 026 → 027 existentes; 028/029 son las nuevas.

## 8. Orden de implementación (para tasks.md)

| Fase | Trabajo | Rationale |
|------|---------|-----------|
| 1 | Migraciones 028 + 029 + guard de contenido (`migration_028_029_content_test.dart`) | Fundación DB; desbloquea W3/W4; se aplica a prod antes que el APK |
| 2 | W2 — hardening del card + 3 widget tests (RED first) | Independiente; cierra la hipótesis P0-4 con evidencia automatizada + re-verificación en dispositivo |
| 3 | W1 — gear→Settings, filas de Settings, `_EquippedPatchesSection`, `_PhotosSection` (álbum re-homado, fix B1), grep test de navegación | Rewiring puro, sin dependencias de DB. El álbum va AQUÍ (no en la fase 6 de W4): la `_PhotosSection` consume el estado YA provisto por `ProgresoBloc` (select de `conquest_photos` vivo en `progreso_bloc.dart:30`) — cero dependencia del uploader/029 de W4; el fix B1 viaja con el rewiring que lo causó y M-CPU-4 queda verificable desde el inicio |
| 4 | W3 backend-bloc — payload builder, eventos, `_save` fix, estados de error, tests unit/bloc | Núcleo del registro; depende de 028 |
| 5 | W3 UI — "INICIAR VIAJE" en el sheet, HUD "Marcar parada", waypoints en summary, resume re-fetch + widget tests | Consume la fase 4 |
| 6 | W4 — repository uploader + flujo de fotos en summary + tests | Depende de 029; el insert usa la firma verificada de `insertConquestPhoto` |
| 7 | W5 — `isExpiredRaid` + markers + `gte` de Explorar + tests | Último: toca queries de lista (dos read sites exactos) |
| 8 | `flutter test` full + `flutter analyze` (delta 0 vs main) + bump de versión + build + verificación en dispositivo | Gate final |

## 9. Notas de verificación empírica (claims confirmados contra código)

- `insertConquestPhoto` — firma real verificada (`showcase_remote_datasource.dart:97-111`): `{required String userId, required String source, String? sourceId, required String photoUrl, String? caption}` → insert con `user_id/source/source_id/photo_url/caption`. El design cita `source:` y `sourceId:` (no `source_id:` como param).
- Políticas de `conquest_photos` — verificadas (`011:261-264`): `cp_select_public` (SELECT true), `cp_insert_own` (INSERT WITH CHECK `auth.uid() = user_id`), `cp_delete_own` (DELETE). **Sin policy de UPDATE** — flujo insert-only.
- `increment_checkpoints` — verificada (`001_functions.sql:67-80`): `p_participant_id BIGINT` (id de `raid_participants`, no raid/user), SECURITY DEFINER, `RETURNS INT`. Único caller: edge fn `validate-checkpoint/index.ts:169`, tras el upsert a `raid_checkpoint_verifications` (`:146`) que dispara `trg_award_coins_on_checkpoint` (`019:123-125`).
- Trigger de coins — `award_coins_on_checkpoint` (`019:88-121`) dispara sobre `raid_checkpoint_verifications` (NO sobre `raid_participants.checkpoints_taken`); `finish-raid/index.ts:70` lee el contador para el bono.
- `saved_routes` (002:161-178) — `total_distance_m/duration_seconds/avg_speed_kmh/max_speed_kmh/points_count/polyline_json TEXT/start_lat/lng/end_lat/lng/started_at/ended_at`. Mismatch confirmado con `_save` (`route_tracker_screen.dart:141-146` → `distance/duration/avg_speed/max_speed/polyline`), catch vacío `:156`, y **no-op adicional**: `SaveRoute` desde el summary retorna antes (estado `TrackerIdle` tras `StopRecording`).
- `PolylineLayer` — latlong2 directo verificado: `Polyline(points: r.points)` con `List<LatLng>` en `post_trip_summary_screen.dart:303-310` y `route_tracker_screen.dart:388-394`; `latlong2: ^0.9.1` en pubspec.
- RLS raids/participants (020:73-159) — helpers SECURITY DEFINER + `rp_insert_public`/`rp_select_own`/`rp_update_own`/`rp_delete_own`; `raids_select_public` solo `planned|lobby` (`:81-84`).
- `raid_waypoints` — cero matches en el repo; ordinal libre `028` tras `027_dedupe_achievements.sql` (lista de migraciones verificada).
- `RaidJoinSheet` — `showRaidJoinSheet` compartida por 4 call sites (`rodar_screen.dart:270,612`, `raid_list_screen.dart:430`, `explorar_screen.dart:101`); rama `joined` en `:193-232`.
- `PatchesBloc` global (`app.dart:68`); `PatchesVitrine` acoplada a ShowcaseBloc (`patches_vitrine.dart:13-25,60-71`).
- `pushNamed` solo en `features_archive/`; `MaterialApp` sin `routes:` — push directo obligatorio (P2-6).
- Buckets actuales (008:9-14): `clan-logos/profile-images/checkpoint-evidence/place-photos` — no existe `conquest-photos`.
- `motoposada_visits` sin migración + catch vacío (`route_tracker_screen.dart:259-274`) — no se copia el patrón; geofence-arrival = fase 2.
- `is_raid_participant` — helper `SECURITY DEFINER STABLE` sin recursión (`020_fix_raid_rls_final.sql:17-25`), ya usado en `raids_select_participant` (`020:88`) y `rp_select_same_raid` (`020:128`); el host ya es participante (`raid_bloc.dart:80-84`). Reutilizado por `rw_insert_own` (028, fix W2).
- `PhotoAlbum` — widget stateless existente (`photo_album.dart:9-18`): acepta `List<ConquestPhotoModel> photos` (default `const []`; `SizedBox.shrink` si vacío, :16-18); `ConquestPhotoModel.fromMap` (`conquest_photo_model.dart:23-33`) mapea la fila de `conquest_photos`. `ProgresoBloc` ya selecciona TODAS las filas (`progreso_bloc.dart:30`), castea (`:41`) y cuenta (`:48`) — la lista se descartaba; el fix B1 la conserva en `ProgresoLoaded.photos` (sin query nueva).

## 10. Open Questions

- [ ] M-ERV-5 spec-literal: el bottom sheet "PRÓXIMOS RAIDS" de Rodar (`rodar_screen.dart:581-612`) puede mostrar un raid pasado. Se deja intacto (spec) — ¿confirmar si el producto quiere que también filtre (excedería el spec, requeriría delta)?
- [ ] Prod `saved_routes`: verificar `information_schema` real antes de apply (convención del skill: las columnas de prod pueden diferir del trail — la app escribía ad-hoc). El payload nuevo fallaría igual si prod no tiene las columnas de 002.
- [x] Semántica de M-RTR-5 — **cerrada (revisión fresh-context, fix W2)**: `rw_insert_own` gana `WITH CHECK (auth.uid() = user_id AND public.is_raid_participant(raid_id))` (helper 020:17-25, sin recursión) — el rechazo atómico cubre propiedad de fila Y pertenencia al raid en INSERT. SELECT/UPDATE/DELETE quedan owner-only sin membership check (los waypoints son datos del viaje propio; un ex-participante conserva su traza).
- [ ] Standalone con fotos: la cola de insert exige `TrackerSaveSucceeded`; si el usuario descarta el trip, el archivo subido queda huérfano en storage (residual aceptado, se documenta en el código).
- [ ] Resume tras kill de app en viaje de raid: el re-fetch usa `created_at >= trip.startedAt`; si el reloj del dispositivo cambió entre sesiones, la ventana puede quedar vacía (caso límite, sin impacto de datos — las filas ya están en DB).
