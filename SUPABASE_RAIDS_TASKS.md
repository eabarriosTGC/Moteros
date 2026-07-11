# AsfaltoClub: Battle Ride — Desglose de Tareas de Implementación

> **Base:** SDD (`SUPABASE_RAIDS_SDD.md`), Specs (`SUPABASE_RAIDS_SPECS.md`), Design (`SUPABASE_RAIDS_DESIGN.md`)
> **Stack:** Supabase (Auth + Postgres + Realtime + Storage + Edge Functions) + LiveKit + Flutter
> **Total tareas:** 45 organizadas en 5 fases + infraestructura
> **Estimaciones:** S (<1h), M (<3h), L (<8h), XL (>8h)

---

# Fase 0 — Fundación (P0)

*Debe funcionar antes de cualquier gameplay. Sin dependencias externas más que Supabase.*

---

## Task: T01 — Crear proyecto Supabase + schema SQL completo

**Phase:** P0
**Depends on:** Ninguna
**Estimate:** L
**Files:**
- `supabase/migrations/001_functions.sql` — funciones háversine, XP, progresión
- `supabase/migrations/002_existing_tables.sql` — tablas existentes migradas (users, places, allies, etc.)
- `supabase/migrations/003_core_tables.sql` — tablas nuevas core (raids, clans, user_xp, achievements, etc.)
- `supabase/migrations/004_extra_tables.sql` — tablas extra (drive_scores, voice, economy, anti-cheat, sos, etc.)

### Description
Ejecutar las 4 primeras migraciones SQL del Design (§1.1–1.4) para crear el schema completo de la base de datos: ~42 tablas con índices, constraints, y funciones base. No usa PostGIS (lat/lng DOUBLE PRECISION + B-tree). No usa ENUMs (TEXT + CHECK).

### Steps
1. Crear proyecto en [supabase.com/dashboard](https://supabase.com/dashboard)
2. Configurar DATABASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY en .env
3. Ejecutar `supabase/migrations/001_functions.sql` — funciones háversine, xp_to_level, award_xp, get_nearby_places, increment_checkpoints, increment_alert_upvote
4. Ejecutar `supabase/migrations/002_existing_tables.sql` — users, user_follows, memberships, places, visits, allies, evidence_photos, saved_routes, road_alerts, challenges, user_challenges, patches, user_patches, chat_messages, conversation_participants
5. Ejecutar `supabase/migrations/003_core_tables.sql` — user_xp, achievements, user_achievements, leaderboard_snapshots, clans, clan_members, raids, raid_participants, raid_checkpoints, raid_checkpoint_verifications, raid_messages, clan_messages
6. Ejecutar `supabase/migrations/004_extra_tables.sql` — drive_scores, voice_channels, mentor_relationships, conduct_reports, shop_items, user_purchases, battle_passes, battle_pass_progress, battle_pass_missions, user_missions_progress, anti_cheat_log, sos_events, raid_spectators, raid_position_log, clan_territories
7. Verificar que todas las tablas e índices existen en Supabase SQL Editor

### Verification
- [ ] `SELECT count(*) FROM information_schema.tables WHERE table_schema='public'` devuelve ~42 tablas
- [ ] `SELECT haversine_distance(0,0,0,0)` devuelve 0
- [ ] `SELECT xp_to_level(0)` devuelve 1; `xp_to_level(100)` devuelve 2
- [ ] `SELECT is_within_distance(0,0,0,0,50)` devuelve true
- [ ] Todos los índices B-tree existen en `pg_indexes`

### Edge Cases
- La función `handle_new_user` usa `SECURITY DEFINER SET search_path = ''` — asegurar que el trigger post-signup funciona
- Las columnas `UNIQUE` en raids/clanes pueden causar errores si hay datos legacy duplicados

---

## Task: T02 — SQL triggers + funciones de progresión

**Phase:** P0
**Depends on:** T01
**Estimate:** M
**Files:**
- `supabase/migrations/005_triggers.sql` — todos los triggers

### Description
Ejecutar migración 005 del Design (§2) con todos los triggers: updated_at automático, streak tracking, achievement checker, post-signup user creation (handle_new_user), night raid detection. Ver Design §2.1–2.5.

### Steps
1. Ejecutar `update_updated_at()` function + triggers para users, places, clans, raids, user_xp
2. Ejecutar `update_streak()` function + trigger `trg_update_streak` en raid_participants (AFTER UPDATE OF is_completed)
3. Ejecutar `check_achievements()` function + trigger `trg_check_achievements` en user_xp (AFTER UPDATE OF raids_completed, checkpoints_captured, km_traveled)
4. Ejecutar `handle_new_user()` function + trigger `trg_handle_new_user` en auth.users (AFTER INSERT)
5. Ejecutar `check_night_raid()` function + trigger `trg_check_night_raid` en raids (BEFORE INSERT OR UPDATE OF scheduled_at)
6. Habilitar Realtime publication: `ALTER PUBLICATION supabase_realtime ADD TABLE raid_messages, clan_messages`

### Verification
- [ ] `INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'test@test.com')` → se crea registro en `users` y `user_xp`
- [ ] `UPDATE raids SET scheduled_at = '2026-07-11 22:00:00-03'` → `is_night_raid = true`
- [ ] `UPDATE raid_participants SET is_completed = true` → streak se actualiza en user_xp
- [ ] `UPDATE user_xp SET raids_completed = 1` donde raids_completed era 0 → achievement "Primer Raid" se otorga

### Edge Cases
- `update_streak()` con `last_raid_date = NULL` (primer raid) debe setear streak=1
- `update_streak()` con `last_raid_date = today` no debe incrementar (mismo día)
- `check_achievements()` no debe re-otorgar achievements ya desbloqueados (UNIQUE lo bloquea)

---

## Task: T03 — Seed data

**Phase:** P0
**Depends on:** T01
**Estimate:** S
**Files:**
- `supabase/migrations/006_seed.sql` — seed data

### Description
Ejecutar migración 006 del Design (§3) con seed data: 17 achievements, 12 shop items iniciales, leaderboard placeholder, 6 challenges legacy, 3 patches legacy. Ver Design §3.1–3.5.

### Steps
1. Insertar 17 achievements con criteria JSONB, xp_reward y sort_order
2. Insertar 12 shop items (cosmetic + consumable) con coins_cost y battle_pass_only flags
3. Insertar leaderboard_snapshots placeholder
4. Insertar 6 challenges legacy
5. Insertar 3 patches legacy

### Verification
- [ ] `SELECT count(*) FROM achievements` = 17
- [ ] `SELECT count(*) FROM shop_items` = 12
- [ ] `SELECT count(*) FROM challenges` = 6
- [ ] `SELECT count(*) FROM patches` = 3

### Edge Cases
- Shop items con `battle_pass_only = true` no deben comprarse sin BP activo
- Los criteria JSONB deben ser parseables: `{"type": "raids_completed", "count": 1}`

---

## Task: T04 — RLS policies

**Phase:** P0
**Depends on:** T01
**Estimate:** L
**Files:**
- `supabase/migrations/007_rls.sql` — RLS policies completas

### Description
Ejecutar migración 007 del Design (§4) con RLS policies para todas las tablas (~42 tablas, ~100+ políticas). Incluye helper `is_admin()`, matriz de acceso público/propietario/admin/founder. Ver Design §4.1–4.22 y tabla de acceso SDD §5.1.

### Steps
1. Habilitar RLS en todas las tablas via DO block
2. Crear `is_admin()` helper function
3. Implementar policies para tablas existing: users, user_follows, memberships, places, visits, allies, evidence_photos, saved_routes, road_alerts, challenges, user_challenges, patches, user_patches
4. Implementar policies para tablas nuevas: clans (4 policies), clan_members (6 policies), raids (5 policies), raid_participants (6 policies), raid_checkpoints (4 policies), raid_checkpoint_verifications (3 policies), raid_messages (3 policies), clan_messages (3 policies)
5. Implementar policies para seguridad/economía: drive_scores, sos_events, anti_cheat_log, conduct_reports, shop_items, user_purchases, battle_pass, raid_spectators, voice_channels

### Verification
- [ ] `SELECT * FROM users` funciona sin auth (público)
- [ ] `INSERT INTO users (id) VALUES ('...')` sin auth falla
- [ ] `INSERT INTO raids (host_id) VALUES ('auth.uid()')` funciona autenticado
- [ ] `UPDATE raids SET status='active'` por no-host falla
- [ ] `SELECT * FROM anti_cheat_log` sin ser admin falla
- [ ] `INSERT INTO clan_members` por no-miembro en clan privado falla

### Edge Cases
- `is_admin()` checkea `raw_user_meta_data->>'role'` — requiere setear metadata al crear admin
- Las policies de clan_members permiten INSERT a clanes públicos (cm_insert_public) o por invitación de founder/captain (cm_insert_invite)
- Las policies de raids permiten SELECT a participantes, miembros de clan, y host — combination OR

---

## Task: T05 — Storage buckets + RLS

**Phase:** P0
**Depends on:** T01
**Estimate:** M
**Files:**
- `supabase/migrations/008_storage.sql` — storage buckets + policies

### Description
Crear 4 Storage buckets públicos con políticas RLS: clan-logos, profile-images, checkpoint-evidence, place-photos. Ver Design §5 y SDD §8.

### Steps
1. Insertar buckets en `storage.buckets` (ON CONFLICT DO NOTHING)
2. Implementar policies para `clan-logos`: SELECT público, INSERT/DELETE por founder/captain
3. Implementar policies para `profile-images`: SELECT público, INSERT/DELETE por propietario (name LIKE 'userId/%')
4. Implementar policies para `checkpoint-evidence`: SELECT público, INSERT por authenticated (validación real en Edge Function)
5. Implementar policies para `place-photos`: SELECT público, INSERT por authenticated

### Verification
- [ ] Subir archivo a `profile-images/{userId}/avatar.jpg` funciona
- [ ] Subir archivo a `profile-images/{otherUserId}/avatar.jpg` falla
- [ ] Subir archivo a `clan-logos/logo.jpg` como miembro del clan funciona
- [ ] SELECT público de cualquier bucket funciona

### Edge Cases
- `profile-images` policy usa `LIKE auth.uid()::text || '/%'` — asegurar que el path incluye UUID
- `checkpoint-evidence` permite subir a cualquiera autenticado; la validación real ocurre en validate-checkpoint EF

---

## Task: T06 — Configurar Supabase Auth (email/password + Google OAuth)

**Phase:** P0
**Depends on:** T01, T04
**Estimate:** M
**Files:**
- `lib/main.dart` — inicialización de Supabase (modificar)
- Dashboard de Supabase — configuración de Auth

### Description
Configurar Supabase Auth en el dashboard y en Flutter: email/password + Google OAuth. Reemplaza Firebase Auth. Ver Specs F-01 y Design §9.2.

### Steps
1. En Supabase Dashboard → Authentication → Settings: habilitar email/password, deshabilitar "Confirm email" si se desea
2. Configurar Google OAuth: Google Cloud Console → Credentials → OAuth 2.0 Web Client → copiar Client ID a Supabase
3. Configurar Site URL en Supabase Auth (para redirects de OAuth)
4. En Flutter `main.dart`: reemplazar `Firebase.initializeApp()` por `Supabase.initialize(url, anonKey)`
5. Verificar que `Supabase.instance.client.auth.onAuthStateChange` funciona

### Verification
- [ ] `supabase.auth.signInWithPassword(email, password)` crea sesión
- [ ] `supabase.auth.signInWithOAuth('google')` abre browser de Google
- [ ] `supabase.auth.onAuthStateChange` emite eventos SIGNED_IN / SIGNED_OUT
- [ ] Sesión persiste después de cerrar/reabrir app (refresh token automático)
- [ ] `supabase.auth.signOut()` limpia sesión local

### Edge Cases
- Migración de usuarios existentes con SHA256 → forzar magic link de reset de contraseña (Ver SDD §12.1)
- Google OAuth cancelado por usuario → no mostrar error, volver a login
- Sesión expirada → redirigir a login sin perder datos locales
- `supabase_flutter` maneja refresh token automáticamente

---

## Task: T07 — Agregar dependencias Flutter + limpiar viejas

**Phase:** P0
**Depends on:** T06
**Estimate:** S
**Files:**
- `pubspec.yaml` — modificar dependencias

### Description
Modificar `pubspec.yaml`: eliminar dependencias de Firebase/Dio/Cloudinary, agregar supabase_flutter y nuevas dependencias. Ver Design §9.1.

### Steps
1. Eliminar de pubspec.yaml: `dio`, `flutter_secure_storage`, `cloudinary_flutter`, `firebase_core`, `firebase_auth`, `google_sign_in`, `web_socket_channel`, `provider`
2. Agregar: `supabase_flutter: ^2.8.0`, `livekit_client: ^2.6.0`, `drift: ^2.22.0`, `sqlite3_flutter_libs: ^0.5.0`, `path_provider: ^2.1.0`, `flutter_background_service: ^5.0.0`, `audioplayers: ^6.1.0`
3. Mantener: `flutter_map`, `geolocator`, `mobile_scanner`, `image_picker`, `flutter_bloc`, `equatable`, `latlong2`, `flutter_map_marker_cluster`, `url_launcher`
4. Ejecutar `flutter pub get`

### Verification
- [ ] `flutter pub get` sin errores
- [ ] `flutter analyze` sin errores de dependencias faltantes
- [ ] `import 'package:supabase_flutter/supabase_flutter.dart'` funciona

### Edge Cases
- `drift` requiere `build_runner` como dev_dependency para generar código
- `livekit_client` requiere permiso de micrófono en iOS (Info.plist) y Android (AndroidManifest.xml)

---

## Task: T08 — Reemplazar ApiClient/Dio por SupabaseClient en toda la app

**Phase:** P0
**Depends on:** T07
**Estimate:** XL
**Files:**
- `lib/core/network/api_client.dart` — ELIMINAR
- `lib/core/network/auth_interceptor.dart` — ELIMINAR
- `lib/core/network/token_storage.dart` — ELIMINAR
- `lib/features/auth/data/datasources/auth_remote_datasource.dart` — REEMPLAZAR
- `lib/features/auth/data/datasources/firebase_auth_service.dart` — ELIMINAR
- `lib/features/auth/data/datasources/google_auth_repository.dart` — ELIMINAR
- `lib/features/auth/domain/usecases/login_usecase.dart` — REEMPLAZAR
- Todos los datasources existentes (PlaceRemoteDataSource, etc.) — MODIFICAR

### Description
Reemplazar toda la capa de red: eliminar `ApiClient` (Dio), eliminar `auth_interceptor` y `token_storage`. Todos los datasources existentes pasan de usar `ApiClient` a usar `SupabaseClient`. Los repositorios que inyectaban `ApiClient` ahora inyectan `SupabaseClient`. Ver Design §9.4 y SDD §10.4.

### Steps
1. Eliminar `api_client.dart`, `auth_interceptor.dart`, `token_storage.dart`
2. Eliminar `firebase_auth_service.dart`, `google_auth_repository.dart`
3. Reemplazar `auth_remote_datasource.dart`: usar `supabase.auth.signInWithPassword()` y `supabase.auth.signInWithOAuth('google')`
4. Reemplazar `login_usecase.dart`: llamar al nuevo datasource directamente
5. Modificar `PlaceRemoteDataSource`: reemplazar `apiClient.get('/places')` por `supabase.from('places').select()`
6. Modificar `ValidationBloc` datasource: usar `supabase.rpc()` en lugar de API calls
7. Modificar `ChallengesBloc`, `PatchesBloc`, `MembershipBloc`, `AdminBloc` datasources
8. Actualizar providers/inyección de dependencias: eliminar `ApiClient` provider

### Verification
- [ ] `PlaceRemoteDataSource.getNearbyPlaces()` funciona y devuelve lugares
- [ ] `auth.signInWithPassword()` funciona y AuthBloc emite Authenticated
- [ ] Login con Google OAuth abre el diálogo de Google
- [ ] `supabase.auth.currentUser` no es null después de login
- [ ] No hay imports a `dio`, `firebase_auth`, `google_sign_in` en el código

### Edge Cases
- `flutter_secure_storage` ya no se usa — Supabase maneja sesión internamente
- `Provider<ApiClient>` debe reemplazarse por `SupabaseClient` directo o mantener compatibilidad
- Algunos BLoCs existentes pueden tener lógica de refresh token que ya no es necesaria

---

## Task: T09 — Migrar Users (trigger handle_new_user + perfil)

**Phase:** P0
**Depends on:** T06, T08
**Estimate:** M
**Files:**
- `lib/features/auth/` — datasource de auth modificado
- `lib/features/profile/` — pantallas de perfil (modificar)

### Description
Asegurar que el trigger `handle_new_user` crea registro en `users` y `user_xp` al registrarse. Implementar flujo de completar perfil post-registro (username, foto, bio). Ver Specs F-02 y SDD §4.3.

### Steps
1. Verificar que `trg_handle_new_user` trigger ejecuta correctamente (de T02)
2. Implementar pantalla "Completá tu perfil" post-primer-login (username, full_name, bio)
3. Implementar upload de avatar a `profile-images` bucket via Supabase Storage
4. Implementar edición de perfil (UPDATE users via RLS)
5. Implementar vista de perfil público (SELECT de username, avatar, level)
6. Validar unicidad de username con manejo de error `duplicate key value`

### Verification
- [ ] Registrarse crea automáticamente registro en `users` con username autogenerado
- [ ] Subir avatar a `profile-images/{userId}/avatar.jpg` funciona
- [ ] Editar perfil persiste cambios
- [ ] Username duplicado muestra error y sugiere alternativas
- [ ] Vista de perfil público muestra solo datos públicos

### Edge Cases
- Username autogenerado: `motero_` + primeros 8 chars del UUID
- Username solo puede cambiarse cada 30 días (validar cliente + servidor)
- Foto > 5MB: rechazar con mensaje
- Usuario eliminado de auth.users → CASCADE elimina perfil

---

## Task: T10 — Migrar Places (geom → lat/lng, sin PostGIS)

**Phase:** P0
**Depends on:** T08
**Estimate:** M
**Files:**
- `lib/features/places/` — PlaceRemoteDataSource (modificar)
- `supabase/migrations/002_existing_tables.sql` — ya incluye places con lat/lng

### Description
Migrar la tabla `places` del esquema anterior (con geom PostGIS) a lat/lng DOUBLE PRECISION. Implementar `get_nearby_places()` RPC con bounding box + háversine. Migrar datos existentes. Ver Specs F-03 y SDD §4.6.

### Steps
1. Verificar que `places` tabla existe con latitude/longitude DOUBLE PRECISION (de T01)
2. Migrar datos legacy: si los places existentes tenían `geom` PostGIS, extraer ST_X/ST_Y a lat/lng
3. Implementar `get_nearby_places(lat, lng, radius)` en Flutter usando `supabase.rpc()`
4. Actualizar PlaceRemoteDataSource para usar `supabase.rpc('get_nearby_places', params)`
5. Implementar UI de creación de lugar con selector de ubicación en mapa
6. Generar `qr_token` único (UUID v4 truncado a 16 chars)

### Verification
- [ ] `get_nearby_places(40.0, -3.0, 5000)` devuelve lugares ordenados por distancia
- [ ] Crear lugar nuevo persiste con latitude/longitude correctos
- [ ] QR token se genera automáticamente y es único
- [ ] Buscar por categoría funciona (filter por category)

### Edge Cases
- Lugares con coordenadas (0,0) → filtrar como inválidos
- Dos lugares con misma ubicación exacta → ambos se muestran, UX con cluster
- Migración sin datos PostGIS legacy → simplemente empezar con tabla vacía y lat/lng

---

## Task: T11 — CRUD Clanes (crear, unirse, roles, logo upload)

**Phase:** P0
**Depends on:** T08, T05
**Estimate:** L
**Files:**
- `lib/features/clan/` — feature completa nueva (ver Design §9.3–9.8)
- `lib/features/clan/data/datasources/clan_remote_datasource.dart`
- `lib/features/clan/data/models/clan_model.dart`
- `lib/features/clan/data/models/clan_member_model.dart`
- `lib/features/clan/data/repositories/clan_repository_impl.dart`
- `lib/features/clan/domain/` — entities, repository interface, usecases
- `lib/features/clan/presentation/bloc/clan_bloc.dart`
- `lib/features/clan/presentation/screens/` — list, detail, create, settings

### Description
Implementar el feature completo de clanes: crear clan, unirse a clan público, roles (founder → captain → rider → recruit), subir logo a Storage, ver miembros. Ver Specs F-04 y Design §9.3–9.8.

### Steps
1. Crear modelos: `ClanModel`, `ClanMemberModel` con fromJson/toJson
2. Crear datasource: `ClanRemoteDataSource` con createClan, getPublicClans, getClanMembers, joinClan, updateMemberRole, removeMember
3. Crear repository: `ClanRepository` interface + `ClanRepositoryImpl`
4. Crear usecases: CreateClan, JoinClan, LeaveClan, UpdateMemberRole
5. Crear BLoC: `ClanBloc` con eventos CreateClan, JoinClan, LeaveClan, UpdateRole, LoadClan, LoadMyClans, LoadClanMembers
6. Crear screens: `ClanListScreen`, `ClanDetailScreen`, `CreateClanScreen`, `ClanSettingsScreen`
7. Implementar logo upload a `clan-logos` bucket
8. Agregar rutas en el router

### Verification
- [ ] Crear clan con nombre, tag, descripción → inserta en `clans` + `clan_members` con role='founder'
- [ ] Unirse a clan público → INSERT en clan_members con role='recruit'
- [ ] Founder cambia rol de miembro → UPDATE en clan_members
- [ ] Founder/captain expulsa miembro → DELETE en clan_members
- [ ] Logo upload funciona y logo_url se actualiza
- [ ] Salir del clan → DELETE propio
- [ ] Clan privado: unirse falla si no es por invitación

### Edge Cases
- Usuario ya miembro de un clan intenta unirse a otro → UNIQUE constraint
- Founder intenta salirse → debe transferir fundador primero
- Clan lleno (max_members=50) → rechazar join
- Logo > 2MB → rechazar

---

## Task: T12 — CRUD Raids + modos + participantes + lobby

**Phase:** P0
**Depends on:** T08, T11
**Estimate:** L
**Files:**
- `lib/features/raid/` — feature completa nueva (ver Design §9.3–9.8)
- `lib/features/raid/data/datasources/raid_remote_datasource.dart`
- `lib/features/raid/data/models/raid_model.dart`
- `lib/features/raid/data/models/raid_participant_model.dart`
- `lib/features/raid/data/repositories/raid_repository_impl.dart`
- `lib/features/raid/domain/` — entities, repository, usecases
- `lib/features/raid/presentation/bloc/raid_bloc.dart`
- `lib/features/raid/presentation/screens/` — list, create, lobby, results

### Description
Implementar el CRUD completo de raids: creación con 6 modos de juego, join/leave, lobby con ready-up, transición lobby→active. Ciclo planned → lobby → active → completed. Ver Specs F-05 y Design §9.3–9.8.

### Steps
1. Crear modelos: `RaidModel`, `RaidParticipantModel` con todos los campos, fromJson/toJson
2. Crear datasource: `RaidRemoteDataSource` con createRaid, joinRaid, leaveRaid, getRaid, getPublicRaids, getMyRaids, updateReady, finishRaid
3. Crear datasource local: `RaidLocalDataSource` para cache offline
4. Crear repository: `RaidRepository` + `RaidRepositoryImpl`
5. Crear usecases: CreateRaid, JoinRaid, LeaveRaid, StartRaid, FinishRaid, ValidateCheckpoint
6. Crear BLoC: `RaidBloc` con CreateRaid, JoinRaid, LeaveRaid, StartRaid, CancelRaid, FinishRaid, LoadRaidList, UpdateReady
7. Crear screens: `RaidListScreen`, `CreateRaidScreen`, `RaidLobbyScreen`, `RaidResultsScreen`
8. Implementar selector de modo de juego (6 modos) con descripciones
9. Implementar selector de origen/destino en mapa (reutilizando flutter_map existente)
10. Implementar lógica de lobby: lista de participantes, ready-up, host puede iniciar
11. Implementar lobby Realtime: channel `raid:{id}:lobby` con eventos user_joined, user_left, ready_changed, raid_started

### Verification
- [ ] Crear raid → INSERT en raids con host_id = auth.uid(), status = 'planned'
- [ ] Join raid público en lobby → INSERT en raid_participants
- [ ] Ready-up → UPDATE is_ready = true via RLS
- [ ] Host inicia raid → UPDATE status = 'active' + Realtime broadcast
- [ ] Cancelar raid → UPDATE status = 'cancelled'
- [ ] Leave raid → DELETE de raid_participants
- [ ] Lista de raids públicos muestra solo raids en planned/lobby
- [ ] Lobby Realtime: ver cambios en tiempo real

### Edge Cases
- Raid con un solo participante (host) → ready automático, puede iniciar
- Fecha del raid en el pasado → validar scheduled_at > now()
- Participante se une a raid lleno → rechazar con "raid completo"
- Host abandona lobby → si no hay otro host, raid se cancela tras 5 min
- Modo Sobrevivencia requiere mínimo 2 participantes → validar al iniciar

---

# Fase 1 — Core Gameplay (P1)

*Depende de que P0 esté funcionando.*

---

## Task: T13 — Mapa en vivo con Realtime broadcast de posiciones

**Phase:** P1
**Depends on:** T12
**Estimate:** XL
**Files:**
- `lib/features/live_map/` — feature completa nueva
- `lib/features/live_map/data/datasources/live_map_datasource.dart`
- `lib/features/live_map/presentation/bloc/live_map_bloc.dart`
- `lib/features/live_map/presentation/widgets/` — raid_marker, speed_color_indicator, ping_overlay
- `lib/features/raid/presentation/screens/raid_live_screen.dart`

### Description
Implementar mapa en vivo durante raid activo: suscripción Realtime a posiciones de participantes, marcadores con avatar/heading/velocidad, envío de posición propia cada 5s, pings en mapa estilo Apex/Fortnite. Ver Specs F-06 y Design §7.

### Steps
1. Crear `LiveMapBloc`: eventos SubscribePositions, UnsubscribePositions, UpdateOwnPosition, PositionReceived, PingSent
2. Implementar suscripción a `raid:{id}:positions` (Broadcast, selfBroadcast=false)
3. Implementar Timer periódico cada 5s: `Geolocator.getCurrentPosition()` → broadcast
4. Implementar throttling: no enviar si posición cambió < 10m
5. Crear `RaidLiveScreen` con flutter_map + capa de marcadores
6. Crear widget `RaidMarker`: avatar, heading (flecha), velocidad, nombre, color por velocidad
7. Implementar interpolación suave de movimiento de marcadores
8. Implementar pings en mapa: long-press → seleccionar tipo (peligro/check/waypoint) → broadcast
9. Implementar timeout de 30s para pings
10. Implementar badge de "sin señal" para participantes que perdieron conexión

### Verification
- [ ] En raid activo, broadcast de posición cada 5s funciona
- [ ] Otros participantes ven el marcador actualizado en tiempo real
- [ ] Marcadores muestran heading, velocidad, nombre correctamente
- [ ] Colores de marcador varían por velocidad (verde < 40, amarillo 40-80, rojo > 80 km/h)
- [ ] Enviar ping aparece en mapa de todos los participantes
- [ ] Ping desaparece después de 30s
- [ ] selfBroadcast=false: no se recibe la propia posición

### Edge Cases
- Participante pierde conexión → badge "📡 Sin señal" en su última posición
- GPS no disponible → badge "📍 GPS no disponible"
- Múltiples participantes en el mismo punto → cluster de marcadores
- Velocidad negativa → ignorar lecturas speed < 0
- Heading = null → marcador sin flecha de dirección

---

## Task: T14 — Edge Function validate-checkpoint (QR+GPS+foto+XP)

**Phase:** P1
**Depends on:** T01, T12
**Estimate:** L
**Files:**
- `supabase/functions/validate-checkpoint/index.ts` — Edge Function TypeScript
- `lib/features/raid/data/datasources/raid_remote_datasource.dart` — método validateCheckpoint
- `lib/features/raid/presentation/screens/` — UI de verificación de checkpoint

### Description
Implementar Edge Function para validación híbrida de checkpoints: QR + GPS (< radius_meters configurable) + foto opcional. Anti-cheat integrado (speed entre checkpoints, QR replay log). Otorga XP via award_xp(). Ver Specs F-07 y Design §6.1.

### Steps
1. Deployar Edge Function `validate-checkpoint` (ver Design §6.1, código TypeScript completo)
2. Implementar lógica: verificar raid activo → verificar participación → validar distancia háversine → validar QR → validar velocidad entre checkpoints → insertar verificación → otorgar XP
3. Implementar anti-cheat speed: si speed > 300 km/h entre checkpoints → flag + reject
4. Implementar logging de QR replay attempts en anti_cheat_log
5. En Flutter: implementar UI de escaneo QR (reutilizar mobile_scanner)
6. En Flutter: implementar UI de validación GPS automática al llegar al checkpoint
7. En Flutter: implementar captura de foto como evidencia (reutilizar image_picker)
8. Agregar `validateCheckpoint()` a `RaidRemoteDataSource`
9. Manejar estados: valid = true (XP y confirmación), valid = false (mensaje de error)

### Verification
- [ ] POST a validate-checkpoint con datos válidos → valid: true, xp_awarded: 30
- [ ] Participante fuera de radius → valid: false, "Muy lejos del checkpoint"
- [ ] QR incorrecto → valid: false, "Código QR incorrecto"
- [ ] Checkpoint ya capturado → UNIQUE constraint → valid: false
- [ ] Speed > 300 km/h → valid: false + anti_cheat_flags incrementado
- [ ] Foto subida a checkpoint-evidence bucket → URL en verificación

### Edge Cases
- Checkpoint oculto (Ruta Gótica): solo visible a < 200m, XP extra (+30)
- Checkpoint sin QR: validación solo GPS
- Múltiples tipos de validación: 'gps', 'qr', 'gps+qr', 'gps+photo'
- Validación offline: guardar localmente, sincronizar al reconectar

---

## Task: T15 — Chat Realtime raid + clan (tablas + broadcast + persistencia)

**Phase:** P1
**Depends on:** T11, T12
**Estimate:** M
**Files:**
- `lib/features/chat/` — o integrar en raid/clan features
- No requiere Edge Function (manejado por RLS + Realtime publication)

### Description
Implementar chat en tiempo real para raids y clanes con persistencia en DB. Mensajes se insertan en raid_messages/clan_messages y se replican via Realtime broadcast. Ver Specs F-08 y Design §7.

### Steps
1. Verificar que las tablas raid_messages y clan_messages existen (de T01)
2. Verificar que `ALTER PUBLICATION supabase_realtime ADD TABLE raid_messages, clan_messages` está ejecutado (de T02)
3. Implementar suscripción Realtime a `raid:{id}:chat` y `clan:{id}:chat`
4. Implementar envío de mensaje: INSERT en raid_messages/clan_messages → RLS lo permite → Realtime replica
5. Implementar carga de historial (últimos 50 mensajes, paginación al scrollear arriba)
6. Implementar tipos de mensaje: text, ping, system
7. Implementar eliminación de mensaje propio (DELETE via RLS)
8. Implementar bloqueo de escritura a > 15 km/h (modo conducción)
9. Integrar TTS de mensajes entrantes en modo conducción

### Verification
- [ ] Enviar mensaje en raid → aparece en raid_messages y se replica a participantes
- [ ] Enviar mensaje en clan → aparece en clan_messages y se replica a miembros
- [ ] Historial carga mensajes anteriores al abrir chat
- [ ] Eliminar mensaje propio → mensaje desaparece para todos (placeholder)
- [ ] No participante intenta enviar → RLS bloquea silenciosamente
- [ ] Escritura bloqueada a > 15 km/h

### Edge Cases
- Mensaje vacío → validación cliente-side
- Sin conexión → buffer local en SQLite, enviar al reconectar
- Muchos mensajes (>100) → paginación
- Miembro expulsado del clan → ya no puede enviar (RLS lo bloquea)

---

## Task: T16 — Post-raid stats + Edge Function finish-raid

**Phase:** P1
**Depends on:** T12, T13, T14
**Estimate:** L
**Files:**
- `supabase/functions/finish-raid/index.ts` — Edge Function TypeScript
- `lib/features/raid/data/datasources/raid_remote_datasource.dart` — método finishRaid
- `lib/features/raid/presentation/screens/raid_results_screen.dart`

### Description
Implementar Edge Function `finish-raid` que solo el host puede ejecutar. Calcula XP por modo (base + bonus checkpoints + racha multipler + bonus nocturno), actualiza raid_participants, verifica achievements via trigger, genera leaderboard snapshot. Post-raid stats screen. Ver Specs F-09 y Design §6.2.

### Steps
1. Deployar Edge Function `finish-raid` (ver Design §6.2, código TypeScript completo)
2. Implementar lógica XP: baseXp por modo (10-40), bonus checkpoints completos (+50), bonus primer raid del día (+20), multiplicador racha (2x ≥3d, 3x ≥7d), bonus nocturno (+15%)
3. Implementar lógica Rally: clasificar por |tiempo_real - tiempo_objetivo|, ganador +50 XP extra
4. Implementar anti-cheat: si is_flagged=true, XP=0 retenido
5. Implementar generateLeaderboardSnapshot() función helper
6. En Flutter: implementar `RaidResultsScreen` con stats: km, tiempo, velocidad, checkpoints, XP, Drive Score
7. En Flutter: implementar botón "Finalizar raid" solo visible para host

### Verification
- [ ] Host ejecuta finish-raid → raid.status = 'completed'
- [ ] Participantes reciben XP según modo y bonuses
- [ ] Rally: ganador es quien tiene menor |real - objetivo|
- [ ] Racha ≥3: XP ×2; racha ≥7: XP ×3
- [ ] Raid nocturno: XP +15%
- [ ] is_flagged=true: XP=0 retenido
- [ ] Solo host puede ejecutar (403 si no)
- [ ] Leaderboard snapshot se genera

### Edge Cases
- Participante no completó (abandonó) → no recibe XP
- Todos abandonaron menos host → host recibe XP base
- Error en award_xp para un participante → loggear, continuar con los demás
- Modo Rally sin ETA → XP base sin bonus de ganador

---

## Task: T17 — Safety-First: modo conducción, Drive Score, TTS alerts

**Phase:** P1
**Depends on:** T13, T16
**Estimate:** L
**Files:**
- `lib/features/live_map/data/services/offline_gps_buffer.dart` — buffer de acelerómetro
- `lib/core/services/tts_service.dart` — TTS pipeline
- `lib/features/raid/` — integración en RaidBloc

### Description
Implementar Safety-First redesign: Rally por precisión ETA (no velocidad), Drive Score post-raid con acelerómetro+GPS, modo Conducción que bloquea interacción visual a >15 km/h con solo TTS. Ver Specs F-10 y SDD §13.

### Steps
1. Implementar detección de velocidad en GPS listener (cada 3s)
2. Implementar Modo Conducción: umbrales <5 km/h normal, 5-15 reducido, >15 bloqueado
3. Implementar histéresis de 2 km/h para evitar toggle constante cerca del umbral
4. Implementar overlay opaco sobre UI interactiva en modo bloqueado
5. Implementar buffer de acelerómetro para Drive Score (1s intervalos durante raid)
6. Implementar cálculo de Drive Score post-raid (4 componentes con pesos 30/25/25/20)
7. Implementar inserción en `drive_scores` tabla
8. Implementar TTS Service: eventos → cache local → Edge Function tts → reproducción
9. Integrar TTS alerts: checkpoint próximo, desviación de ruta, clima, inicio/fin raid

### Verification
- [ ] A >15 km/h por >5s → interfaz bloqueada, overlay opaco
- [ ] A <5 km/h por >10s → interfaz vuelve gradualmente
- [ ] Drive Score calculado post-raid con 4 componentes
- [ ] TTS reproduce alertas de checkpoint, desviación, clima
- [ ] Rally: ETA calculado con OSRM, ganador por precisión, no velocidad

### Edge Cases
- Copiloto presente → podría usar interfaz normalmente (detección Bluetooth)
- Velocidad fluctúa cerca del umbral (14-16 km/h) → histéresis de 2 km/h
- Drive Score con datos insuficientes (<5 min de raid) → "datos insuficientes"
- TTS en segundo plano (pantalla bloqueada) → mantener canal de audio

---

# Fase 2 — Social + Progresión (P2)

---

## Task: T18 — Crear RaidCheckpoints CRUD + UI

**Phase:** P1 (dependencia de P0 pero agrupado aquí)
**Depends on:** T12
**Estimate:** M
**Files:**
- `lib/features/raid/data/models/checkpoint_model.dart`
- `lib/features/raid/presentation/screens/create_raid_screen.dart` — agregar UI de checkpoints

### Description
Implementar CRUD de checkpoints dentro de un raid: el host puede agregar checkpoints con ubicación, nombre, radio, QR opcional, flag is_hidden. Ver Specs F-07 y Design §1.3.

### Steps
1. Crear modelo `CheckpointModel` con fromJson/toJson
2. Agregar datasource métodos para CRUD de checkpoints (insert, select, delete)
3. Implementar UI en CreateRaidScreen: agregar checkpoints en mapa (tap para ubicar)
4. Implementar propiedades: sort_order, is_hidden, qr_code, radius_meters
5. Implementar UI para definir orden de checkpoints (drag to reorder)

### Verification
- [ ] Host puede agregar checkpoints con ubicación en mapa
- [ ] Host puede definir nombre, radio, QR, is_hidden por checkpoint
- [ ] Checkpoints se guardan con sort_order
- [ ] Host puede eliminar checkpoint
- [ ] Participantes ven checkpoints en raid activo (respetando is_hidden)

### Edge Cases
- Checkpoint oculto: solo visible a <200m del mismo (Ruta Gótica)
- Checkpoint ligado a place existente (place_id opcional)
- Múltiples checkpoints en misma ubicación → sort_order determina orden

---

## Task: T19 — Integrar LiveKit (voice chat rooms, JWT tokens, Flutter SDK)

**Phase:** P2
**Depends on:** T12
**Estimate:** L
**Files:**
- `supabase/functions/on-raid-start/index.ts` — Edge Function (LiveKit room + inicio)
- `supabase/functions/grant-voice-access/index.ts` — Edge Function (LiveKit JWT)
- `lib/core/services/voice_chat_service.dart` — LiveKit client service
- `pubspec.yaml` — agregar livekit_client

### Description
Configurar LiveKit e integrar voice chat: Edge Function `on-raid-start` crea room en LiveKit al iniciar raid y genera JWT tokens. Edge Function `grant-voice-access` para refresh de tokens. VoiceChatService en Flutter para conexión push-to-talk. Ver Specs F-11, SDD §14 y Design §8.

### Steps
1. Configurar LiveKit server (self-hosted o LiveKit Cloud) con LIVEKIT_API_KEY y LIVEKIT_API_SECRET en Supabase
2. Deployar Edge Function `on-raid-start`: crea room LiveKit, genera tokens por participante, guarda en raid_participants.livekit_token/room, cambia raid.status a 'active'
3. Deployar Edge Function `grant-voice-access`: genera JWT para room existente
4. Implementar `VoiceChatService` en Flutter: connect, disconnect, enableMicrophone (push-to-talk), disableMicrophone
5. Integrar con RaidBloc: al recibir raid_started, conectar automáticamente al voice channel
6. Implementar push-to-talk: micrófono deshabilitado por defecto, activar por botón Bluetooth/comando de voz/botón en pantalla (solo detenido)
7. Implementar clan voice channel 24/7 (bajo demanda)

### Verification
- [ ] Al iniciar raid, se crea room en LiveKit
- [ ] Cada participante recibe token JWT válido en raid_participants.livekit_token
- [ ] Cliente Flutter se conecta al room LiveKit
- [ ] Push-to-talk: micrófono deshabilitado por defecto, se activa al presionar botón
- [ ] Clan voice channel: miembros pueden conectarse independientemente de raids

### Edge Cases
- LiveKit no configurado → raid continúa sin voz (fallback)
- Token expira durante raid largo → refresh via grant-voice-access
- Participante sin micrófono → puede escuchar pero no hablar
- Push-to-talk por Bluetooth requiere parear dispositivo como audio

---

## Task: T20 — Edge Function tts (Google Cloud TTS + Storage cache)

**Phase:** P2
**Depends on:** T17, T05
**Estimate:** M
**Files:**
- `supabase/functions/tts/index.ts` — Edge Function TTS
- `lib/core/services/tts_service.dart` — TTS pipeline cliente

### Description
Implementar Edge Function TTS que genera audio desde texto usando Google Cloud TTS, cachea en Storage y devuelve URL. Cliente implementa cache local y reproducción. Ver Design §6.7 y SDD §14.6.

### Steps
1. Configurar GOOGLE_CLOUD_TTS_API_KEY en Supabase Edge Function secrets
2. Deployar Edge Function `tts`: recibe text + lang, busca en cache de Storage, si no existe llama a Google TTS API, sube MP3 a Storage, devuelve URL pública
3. Implementar `TtsService` en Flutter: cache local en Map<String, String>, playTts(eventType, text)
4. Integrar eventos: checkpoint próximo, desviación, clima, inicio/fin raid
5. Reproducir audio con audioplayers incluso en segundo plano

### Verification
- [ ] GET /functions/v1/tts?text=Hola&lang=es-ES → devuelve URL de audio MP3
- [ ] Segunda llamada con mismo texto → devuelve URL cacheada
- [ ] Audio se reproduce correctamente en dispositivo
- [ ] Cache local evita llamadas repetidas a la EF
- [ ] Audio en segundo plano funciona (pantalla bloqueada)

### Edge Cases
- Google Cloud TTS API key sin saldo → mostrar notificación visual como fallback
- TTS con texto muy largo → truncar o dividir en fragmentos
- Audio en segundo plano en iOS → requiere UIBackgroundModes = audio en Info.plist

---

## Task: T21 — Reputation system (trust_score, mentor_relationships, conduct_reports)

**Phase:** P2
**Depends on:** T11, T16
**Estimate:** L
**Files:**
- `lib/features/social/` — nueva feature (o integrar en user/profile)
- ADMINS: `lib/features/admin/`

### Description
Implementar sistema de reputación: trust_score oculto (0-100) en user_xp, mentor/rookie relationships, conduct reports con revisión de admin. Badge público de confianza (🟢/🟡/🔴). Ver Specs F-12 y SDD §15.

### Steps
1. Verificar columna `trust_score` en user_xp (smallint 0-100, default 50) de T01
2. Implementar factores que afectan trust_score: +1 a +3 por raid completado, -10 a -30 por conduct report verificado, -5 por falso reporte, +0.5 por Drive Score >80, +2 por mentoría exitosa
3. Implementar mentor_relationships: mentor (level≥5, trust≥70) invita rookie (level≤2) → bonus XP al completar
4. Implementar conduct_reports: INSERT con reporter_id, reported_id, raid_id, reason, severity (1-5)
5. Implementar UI de conduct report (reportar participante post-raid)
6. Implementar badge público: trust_score ≥80 🟢, 50-79 🟡, <50 🔴
7. Implementar penalización por falso reporte

### Verification
- [ ] trust_score aumenta +1 a +3 al completar raid
- [ ] Conduct report verificado → trust_score del reportado se reduce
- [ ] Falso reporte → trust_score del reporter se reduce -5
- [ ] Mentoría exitosa → bonus XP + trust_score +2
- [ ] Badge público muestra color correcto según trust_score
- [ ] Solos admins ven trust_score numérico

### Edge Cases
- trust_score mínimo = 0 (no puede ser negativo) → CHECK constraint
- Un mismo usuario reportado múltiples veces → acumula reducciones
- Rookie completa raid pero mentor abandona → rookie recibe XP, mentor no

---

## Task: T22 — XP + streaks + achievements + leaderboards

**Phase:** P2
**Depends on:** T16
**Estimate:** L
**Files:**
- `lib/features/progression/` — ProgressionBloc, datasource, UI
- `lib/features/leaderboard/` — LeaderboardBloc, datasource, UI

### Description
Implementar sistema de progresión completo: XP, niveles (xp_to_level), streaks (trigger en raid_participants), 17 achievements con verificación automática vía trigger, leaderboards (general/semanal/mensual/por clan). Ver Specs F-13 y SDD §9.

### Steps
1. Crear `ProgressionDatasource`: loadProgression(userId), loadAchievements(), loadLeaderboard()
2. Crear `ProgressionBloc`: LoadProgression, LoadAchievements
3. Crear `LeaderboardDatasource`: loadGeneral, loadWeekly, loadMonthly, loadClanRankings
4. Crear `LeaderboardBloc`: LoadGeneral, LoadWeekly, LoadMonthly, LoadClanRankings
5. Implementar UI de perfil: XP bar, nivel, streak, logros desbloqueados
6. Implementar UI de leaderboards: top 100 con posición destacada
7. Implementar animación de subida de nivel
8. Implementar notificación de logro desbloqueado

### Verification
- [ ] XP se acumula correctamente vía award_xp()
- [ ] Nivel se recalcula: level = floor(sqrt(total_xp/100)) + 1
- [ ] Streak se actualiza al completar raid consecutivo
- [ ] Multiplicador de racha: 2x (≥3 días), 3x (≥7 días)
- [ ] Achievement se desbloquea automáticamente al cumplir criterio
- [ ] Leaderboard general muestra top 100 por total_xp
- [ ] Leaderboard snapshot se genera diariamente

### Edge Cases
- XP negativo → award_xp ignora (validar p_xp > 0)
- Usuario con 0 XP → level = 1
- Racha se rompe después de 30 días sin raid → reset a 0
- Achievement ya desbloqueado → UNIQUE evita duplicado

---

## Task: T23 — SOS crash detection (acelerómetro + Edge Function + alertas)

**Phase:** P2
**Depends on:** T11, T13
**Estimate:** L
**Files:**
- `lib/features/sos/` — SOS button, crash detection service
- `lib/core/services/` — crash_detection_service.dart

### Description
Implementar sistema SOS: detección automática de caídas (acelerómetro >5G + inmovilidad 30s + ángulo), botón SOS manual, alertas al clan y contacto de emergencia con ubicación. Ver Specs F-14 y SDD §19.1.

### Steps
1. Verificar tabla `sos_events` y columna `emergency_contact_*` en users
2. Implementar Acelerómetro listener: detectar >5G en <100ms
3. Implementar timer de 30s post-impacto: verificar inmovilidad GPS (<1m)
4. Implementar cuenta regresiva de 10s con alarma audible y pantalla "¿Estás bien?"
5. Implementar cancelación de alerta falsa
6. Implementar alerta Realtime al clan: `user:{userId}:notifications` → sos_alert
7. Implementar alerta al contacto de emergencia (Edge Function + Twilio/Vonage/SMS API)
8. Implementar botón SOS manual siempre visible en raid activo

### Verification
- [ ] Impacto simulado >5G + inmovilidad → cuenta regresiva de 10s
- [ ] Cancelar alerta → no se envía notificación
- [ ] No cancelar → sos_events se registra + alerta al clan
- [ ] Botón SOS manual → alerta inmediata
- [ ] Contacto de emergencia recibe ubicación (SMS/llamada)
- [ ] Falso SOS penaliza trust_score -5

### Edge Cases
- Dispositivo en modo ahorro de batería → acelerómetro puede no estar disponible
- Usuario sin contacto de emergencia → solo alerta al clan
- Sin conexión → almacenar localmente, enviar al reconectar
- Múltiples falsos positivos (moto en caminos irregulares) → ajustar threshold

---

## Task: T24 — Modo Espectador

**Phase:** P2
**Depends on:** T13
**Estimate:** M
**Files:**
- `lib/features/raid/` — integración en RaidBloc
- UI: botón "Ver como espectador"

### Description
Implementar modo espectador: usuarios pueden seguir raids en vivo sin interactuar. El host debe habilitar allow_spectators. Ver Specs F-15 y SDD §19.2.

### Steps
1. Verificar tablas `raid_spectators` y columna `raids.allow_spectators`
2. Implementar INSERT en raid_spectators con RLS (auth.uid() = user_id, raid.status='active', allow_spectators=true)
3. Implementar suscripción Realtime de solo lectura a posiciones y chat
4. Implementar UI de espectador: mapa sin botones de interacción, solo visualización
5. Implementar UPDATE left_at al salir

### Verification
- [ ] Unirse como espectador → INSERT en raid_spectators + suscripción a posiciones
- [ ] Espectador ve marcadores en mapa pero no puede interactuar
- [ ] Espectador no puede enviar mensajes ni pings (RLS bloquea)
- [ ] Host habilita/deshabilita espectadores en lobby
- [ ] Espectador sale → UPDATE left_at

### Edge Cases
- Espectador también es participante → prevalece participante
- 100+ espectadores → rate limiting en broadcast
- Host deshabilita espectadores durante raid → no expulsa existentes

---

# Fase 3 — Monetización + Extra (P3)

---

## Task: T25 — In-game economy (coins, shop, compras)

**Phase:** P3
**Depends on:** T16
**Estimate:** L
**Files:**
- `lib/features/shop/` — ShopBloc, screens
- `lib/features/progression/` — integración de coins en UI

### Description
Implementar economía in-game: coins ganados en raids, tienda con items cosméticos/consumibles, compras, equipar títulos. Ver Specs F-16 y SDD §16.

### Steps
1. Verificar tablas `shop_items`, `user_purchases` y columna `coins` en user_xp
2. Implementar otorgar coins en finish-raid EF (10-50 coins según modo y duración)
3. Implementar `ShopRemoteDatasource`: getShopItems, purchaseItem, getUserPurchases
4. Implementar ShopBloc: LoadItems, PurchaseItem, LoadPurchases
5. Implementar ShopScreen: lista de items con precio, tipo, battle_pass_only
6. Implementar lógica de compra: verificar coins suficientes → UPDATE coins → INSERT user_purchases
7. Implementar equipar título: UPDATE users.active_title
8. Implementar UI de inventario: items comprados, títulos equipables

### Verification
- [ ] Completar raid otorga coins (10-50)
- [ ] Shop muestra items activos con precio
- [ ] Comprar item reduce coins y crea user_purchases
- [ ] Item battle_pass_only sin BP activo → rechazar
- [ ] Equipar título → se muestra junto al nombre en raids/chat
- [ ] Item ya poseído → mostrar "Ya tenés este item"

### Edge Cases
- Compra falla a mitad de transacción → rollback (usar transacción SQL o verificación doble)
- Item desactivado (is_active=false) → oculto de la tienda
- Consumible (xp_boost): usar en raid → aplicar en finish_raid

---

## Task: T26 — Battle Pass estacional

**Phase:** P3
**Depends on:** T25, T22
**Estimate:** L
**Files:**
- `lib/features/battle_pass/` — BattlePassBloc, screens
- `lib/features/raid/` — integración de XP en BP progress

### Description
Implementar Battle Pass estacional: temporadas de 3 meses con 50 tiers, progresión por XP, recompensas, misiones diarias/semanales. Ver Specs F-17 y SDD §16.3.

### Steps
1. Verificar tablas: battle_passes, battle_pass_progress, battle_pass_missions, user_missions_progress
2. Implementar inicialización de progreso al primer login en temporada activa
3. Implementar acumulación de XP en battle_pass_progress (por cada award_xp)
4. Implementar UI de Battle Pass: tiers, progreso, recompensas reclamables
5. Implementar reclamar recompensa de tier
6. Implementar misiones diarias y semanales
7. Implementar premium: recompensas duplicadas, tiers extra

### Verification
- [ ] BP activo → XP de raids se acumula en xp_in_season
- [ ] Al cruzar umbral de 500 XP → current_tier aumenta
- [ ] Reclamar recompensa → item se añade a inventario
- [ ] Misión diaria completada → XP de recompensa
- [ ] Premium: recompensas extra disponibles

### Edge Cases
- Usuario se une a mitad de temporada → progresión desde tier 1
- Premium expira → recompensas premium no reclamadas se pierden
- XP suficiente para múltiples tiers en un raid → saltar tiers

---

## Task: T27 — Edge Function get-route-weather (OpenWeather + OSRM)

**Phase:** P3
**Depends on:** T12
**Estimate:** M
**Files:**
- `supabase/functions/get-route-weather/index.ts` — Edge Function TypeScript

### Description
Implementar Edge Function que consulta clima en ruta: obtiene waypoints de OSRM, consulta OpenWeather por tramo, calcula ajuste de ETA. Ver Specs F-18 y Design §6.4.

### Steps
1. Configurar OPENWEATHER_API_KEY en Supabase Edge Function secrets
2. Deployar Edge Function `get-route-weather` (ver Design §6.4, código TypeScript completo)
3. Implementar sampleo de waypoints cada ~10km desde OSRM route
4. Implementar consulta OpenWeather por waypoint
5. Implementar cálculo de ajuste ETA: lluvia +15%, fuerte +25%, viento +5%, nieve +35%, niebla +20%
6. Implementar almacenamiento en raids.weather_conditions (JSONB) y adjusted_eta
7. Integrar en UI de creación de raid: mostrar resumen climático
8. Integrar re-consulta cada 15 min durante raid activo

### Verification
- [ ] POST a get-route-weather con origen/destino → devuelve segments[] con condiciones
- [ ] ETA ajustado incluye multiplicador climático
- [ ] Weather conditions se guardan en raids.weather_conditions
- [ ] Re-consulta durante raid actualiza weather_conditions
- [ ] Cambio climático significativo → broadcast por Realtime

### Edge Cases
- OpenWeather API key sin saldo → raid funciona sin ajuste climático
- Ruta sin cobertura → condiciones default (despejado)
- Fecha muy lejana (>7 días) → pronóstico no disponible
- Lluvia torrencial → sugerir cancelación del raid

---

## Task: T28 — Raids nocturnos (mecánicas + bonus XP)

**Phase:** P3
**Depends on:** T16
**Estimate:** M
**Files:**
- `lib/features/raid/` — UI de badge nocturno, bonus XP

### Description
Implementar mecánicas de raids nocturnos (20:00-06:00): detección automática via trigger, badge 🌙, bonus XP +15%, duración mínima 45min, checkpoints requieren linterna. Ver SDD §17.2.

### Steps
1. Verificar trigger `check_night_raid` de T02 (detecta automáticamente por scheduled_at)
2. Implementar UI: badge 🌙 en raid card y lobby
3. Integrar bonus XP +15% en finish-raid EF (ya implementado en T16)
4. Implementar duración mínima de 45 min para raids nocturnos
5. Implementar UI de "linterna requerida" en checkpoints nocturnos

### Verification
- [ ] Raid con scheduled_at entre 20:00-06:00 → is_night_raid=true + badge 🌙
- [ ] XP nocturno: +15% en finish-raid
- [ ] Duración mínima nocturna: 45 min (no se puede finalizar antes)

### Edge Cases
- Zona horaria del host vs participantes → se calcula con hora local del host
- Raid nocturno + lluvia → ambos multiplicadores se aplican

---

## Task: T29 — Anti-cheat system (mock GPS, speed validation, EXIF cross-check)

**Phase:** P3
**Depends on:** T14
**Estimate:** L
**Files:**
- `lib/features/raid/` — mock GPS detection (cliente-side)
- `supabase/functions/validate-checkpoint/index.ts` — ya incluye speed validation

### Description
Implementar anti-cheat de 3 capas: detección de mock GPS en cliente, validación de velocidad en Edge Function (T14), cross-check EXIF de foto. Ver Specs F-19 y SDD §18.

### Steps
1. Implementar detección de mock GPS en Flutter: `Geolocator.getCurrentPosition().then((pos) { if (pos.isMocked) { ... } })`
2. Implementar logging en anti_cheat_log con check_type='gps_mock'
3. Verificar que speed validation en validate-checkpoint EF funciona (de T14)
4. Implementar EXIF cross-check en validate-checkpoint: extraer GPS + timestamp de foto, comparar con reportado
5. Implementar sistema de flags: 0 = OK, 1 = WARN, 2+ = is_flagged=true, XP retenido
6. Implementar UI de notificación de warning al usuario

### Verification
- [ ] Mock GPS detectado → anti_cheat_log + warning al usuario
- [ ] Speed > 300 km/h entre checkpoints → flag
- [ ] EXIF GPS difiere >10m del reportado → flag
- [ ] EXIF timestamp difiere >30s → flag
- [ ] 2+ flags → is_flagged=true, XP retenido en finish-raid

### Edge Cases
- GPS real reportado como mock por bug de Android → revisión manual de admin
- Foto sin EXIF GPS → FLAG (posible foto de galería)
- Más de 3 raids flagged → trust_score reducido + posible ban

---

## Task: T30 — Replay time-lapse (persistir posiciones + Edge Function generate-replay)

**Phase:** P3
**Depends on:** T13, T16
**Estimate:** M
**Files:**
- `supabase/functions/generate-replay/index.ts` — Edge Function
- `lib/features/live_map/data/services/offline_gps_buffer.dart` — persistencia de posiciones

### Description
Implementar sistema de replay: posiciones se persisten en `raid_position_log` durante el raid, Edge Function `generate-replay` construye JSON con tracks y checkpoints, almacena en Storage. Ver Specs F-20 y Design §6.5.

### Steps
1. Verificar tabla `raid_position_log` (de T01)
2. Implementar logging de posiciones en raid_position_log durante raid activo (cada 5s)
3. Deployar Edge Function `generate-replay` (ver Design §6.5): consulta position_log, agrupa por participante, samplea, construye JSON, sube a Storage
4. Implementar botón "Generar replay" en RaidResultsScreen (solo host)
5. Implementar UI de replay: mapa con líneas de ruta coloreadas por velocidad, checkpoints, timeline
6. Implementar política de retención: 30 días post-raid, luego purgar via cron

### Verification
- [ ] Posiciones se guardan en raid_position_log durante raid activo
- [ ] generate-replay devuelve JSON con tracks de todos los participantes
- [ ] Replay se sube a Storage y devuelve URL pública
- [ ] UI de replay muestra rutas, checkpoints, timeline

### Edge Cases
- Raid sin participantes (solo host) → replay con un solo track
- Replay con datos insuficientes (<5 min) → mensaje "Sin datos suficientes"
- Política de retención: purgar después de 30 días via pg_cron

---

## Task: T31 — Clan territories (guerra de clanes + control de zonas)

**Phase:** P3
**Depends on:** T11, T12
**Estimate:** L
**Files:**
- `lib/features/clan/` — integración de territorios
- `lib/features/live_map/` — visualización de territorios en mapa

### Description
Implementar territorios de clanes: zonas geográficas que los clanes capturan y defienden en modo Guerra de Clanes. Captura requiere raids dentro de la zona. Ver Specs F-21 y SDD §19.5.

### Steps
1. Verificar tabla `clan_territories` (de T01)
2. Implementar CRUD de territorios por admin
3. Implementar lógica de captura: completar raids en zona durante Guerra de Clanes
4. Implementar cálculo de ganador: clan con más checkpoints en zona
5. Implementar visualización en mapa: círculo semitransparente con color del clan
6. Implementar timer de expiración: 7 días post-captura

### Verification
- [ ] Admin puede crear territorio con centro, radio, nombre
- [ ] Guerra de Clanes: raids en zona contribuyen a captura
- [ ] Territorio capturado se muestra en mapa con color del clan
- [ ] Territorio expira después de 7 días sin defensa

### Edge Cases
- Dos clanes con raids simultáneos en misma zona → gana el que más checkpoints tenga
- Territorio sin defensor → captura inmediata

---

## Task: T32 — Admin panel (moderación, conduct reports, anti-cheat review)

**Phase:** P3
**Depends on:** T21, T29
**Estimate:** L
**Files:**
- `lib/features/admin/presentation/screens/admin_panel_screen.dart`
- `lib/features/admin/presentation/bloc/admin_bloc.dart`

### Description
Implementar panel de administración: moderación de conduct reports, revisión de raids flagged, gestión de anti-cheat logs, gestión de shop items, gestión de battle passes. Ver Specs F-22 y SDD §12.

### Steps
1. Implementar restricción de acceso: solo usuarios con `raw_user_meta_data->>'role' = 'admin'`
2. Implementar AdminBloc: LoadReports, VerifyReport, LoadFlaggedRaids, ClearFlags, LoadAntiCheatLogs
3. Implementar AdminScreen con tabs: Reports, Flagged Raids, Anti-Cheat, Shop, Battle Pass
4. Implementar UI de revisión de conduct reports: ver razón, severidad, marcar verified/rejected
5. Implementar UI de revisión de raids flagged: ver detalles, clear flags, otorgar XP retenido
6. Implementar UI de gestión de shop: crear/editar/desactivar items
7. Implementar UI de gestión de battle passes: crear temporada, configurar tiers

### Verification
- [ ] Solo admin puede acceder al panel
- [ ] Admin puede ver conduct reports no verificados
- [ ] Admin puede marcar report como verified → trust_score se ajusta
- [ ] Admin puede revisar raids flagged y otorgar XP retenido
- [ ] Admin puede crear/editar shop items

### Edge Cases
- Admin se reporta a sí mismo → el reporte va a otro admin
- XP retenido de raid flagged: admin decide si otorgar o no
- Batch de anti-cheat logs: paginación para raids con muchos flags

---

# Fase 3+ — Integración Existente

---

## Task: T33 — Refugios (conectar RefugiosBloc a tabla allies real)

**Phase:** P3+
**Depends on:** T08
**Estimate:** M
**Files:**
- `lib/features/refugios/` — RefugiosBloc datasource (modificar)

### Description
Conectar el `RefugiosBloc` existente a la tabla `allies` real en Supabase (antes usaba mock data). La tabla `allies` ya fue creada en T01. Ver Specs F-23.

### Steps
1. Modificar `RefugiosBloc` datasource: reemplazar mock data por `supabase.from('allies').select('*')`
2. Implementar `getNearbyAllies()` usando `get_nearby_places` RPC o query directa con bounding box
3. Verificar que RLS permite SELECT público en allies (de T04)

### Verification
- [ ] RefugiosBloc carga datos de tabla allies real
- [ ] Búsqueda por cercanía funciona
- [ ] Filtro por categoría funciona
- [ ] SELECT público funciona (no requiere auth)

### Edge Cases
- allies sin datos → mostrar "No hay refugios cercanos"
- allies administrado solo por admin → RefugiosBloc solo lectura

---

## Task: T34 — Road Alerts (integrar en mapa de raids)

**Phase:** P3+
**Depends on:** T13
**Estimate:** M
**Files:**
- `lib/features/road_alerts/` — integrar en live map

### Description
Integrar Road Alerts existentes en el mapa de raids en vivo. Mostrar alertas activas (peligros, warning, danger) en el mapa durante raids. Ver Specs F-24.

### Steps
1. Modificar datasource de road_alerts para usar `supabase.from('road_alerts').select()`
2. Implementar overlay de road_alerts en mapa de raids (marcadores con íconos por tipo/severidad)
3. Integrar TTS: alerta de peligro cercano se anuncia por voz
4. Implementar creación de alerta desde el raid (reportar peligro)

### Verification
- [ ] Road alerts activos se muestran en mapa de raids
- [ ] Alertas danger/warning tienen prioridad visual
- [ ] Alerta a 3 km → TTS anuncia
- [ ] Crear alerta desde raid INSERTA en road_alerts

### Edge Cases
- Alertas expiradas no se muestran (expires_at)
- Alertas inactivas (active=false) no se muestran

---

## Task: T35 — Membresía (desbloquear modos exclusivos)

**Phase:** P3+
**Depends on:** T08, T11
**Estimate:** M
**Files:**
- `lib/features/membership/` — MembershipBloc datasource (modificar)

### Description
Conectar sistema de membresía existente a Supabase. Premium desbloquea modos exclusivos, edición de cualquier lugar, y recompensas extra de Battle Pass. Ver Specs F-25.

### Steps
1. Modificar `MembershipBloc` datasource: usar `supabase.from('memberships').select()`
2. Implementar verificación de membresía activa en UI
3. Restringir modos exclusivos (Sobrevivencia, Guerra de Clanes) a premium
4. Restringir edición de lugares ajenos a premium
5. Implementar badge 💎 en perfil de usuario premium

### Verification
- [ ] MembershipBloc carga membresía real de Supabase
- [ ] Premium puede crear raids en modo Sobrevivencia
- [ ] Basic no puede crear Sobrevivencia (UI oculta opción)
- [ ] Premium puede editar cualquier lugar

### Edge Cases
- Membresía expirada → degradar a basic, notificar
- Payment_ref sin implementar → membresía puede crearse manualmente desde admin

---

## Task: T36 — Follows (invitar a raids privados)

**Phase:** P3+
**Depends on:** T08, T12
**Estimate:** M
**Files:**
- `lib/features/social/` — follows integrado en raid invites

### Description
Usar tabla `user_follows` para invitar a raids privados: el host puede invitar a followers al raid. Ver Specs F-26.

### Steps
1. Modificar datasource de follows: usar `supabase.from('user_follows').select()`
2. Implementar UI de invitar: al crear raid privado, seleccionar followers
3. Implementar INSERT en raid_participants con invitación (user_id + raid_id, raid es privado)
4. Enviar notificación Realtime a user:{userId}:notifications con raid_invitation

### Verification
- [ ] Host puede ver lista de followers al crear raid privado
- [ ] Invitar seguidor → INSERTS en raid_participants
- [ ] Invitado recibe notificación Realtime
- [ ] No-follower no puede unirse a raid privado (RLS bloquea)

### Edge Cases
- Follow ya es participante → mostrar "Ya participa"
- Follow no tiene la app → notificación push (vía Edge Function)

---

## Task: T37 — Saved Routes (reutilizar como raids)

**Phase:** P3+
**Depends on:** T12
**Estimate:** M
**Files:**
- `lib/features/raid/` — integrar saved_routes en creación de raid

### Description
Permitir crear raids desde rutas guardadas existentes (saved_routes). Ver Specs F-27 y SDD §4.10.

### Steps
1. Modificar datasource de saved_routes: usar `supabase.from('saved_routes').select()`
2. Implementar UI de "Crear raid desde ruta guardada"
3. Al seleccionar ruta, precargar origen, destino y route_data en formulario de creación

### Verification
- [ ] Saved routes se cargan desde Supabase
- [ ] Al seleccionar ruta guardada, formulario de raid se precarga
- [ ] route_data (polyline) se incluye en raid

### Edge Cases
- Ruta guardada sin polyline → crear raid con solo origen/destino
- Ruta guardada de otro usuario → no visible (RLS)

---

## Task: T38 — Import OSM (Overpass API) via Edge Function

**Phase:** P3+
**Depends on:** T08
**Estimate:** M
**Files:**
- `supabase/functions/osm-import/index.ts` — Edge Function
- `lib/features/admin/` — botón de import OSM en admin panel

### Description
Implementar Edge Function `osm-import` que consulta Overpass API para importar lugares desde OpenStreetMap dentro de un bounding box, categorizados según las categorías de AsfaltoClub. Ver Design §6.3 y Specs F-28.

### Steps
1. Deployar Edge Function `osm-import` (ver Design §6.3, código TypeScript completo)
2. Implementar mapping de categorías OSM → AsfaltoClub (taller, restaurante, hotel, mirador, etc.)
3. Implementar detección de duplicados (verificar lugar existente a <50m)
4. Agregar botón "Importar de OSM" en admin panel
5. Implementar selector de bounding box en mapa (admin)

### Verification
- [ ] Ejecutar osm-import con bounding box → importa lugares nuevos
- [ ] Duplicados (a <50m) se skipean correctamente
- [ ] QRs únicos se generan automáticamente
- [ ] Solo admin puede ejecutar

### Edge Cases
- Overpass API timeout → manejar con timeout de 25s
- Zona sin datos OSM → imported=0
- Overpass API rate limit → esperar entre imports

---

# Infraestructura

---

## Task: T39 — Background location service (Android foreground + iOS Always)

**Phase:** P1
**Depends on:** T13
**Estimate:** L
**Files:**
- `android/app/src/main/AndroidManifest.xml` — permisos foreground service
- `ios/Runner/Info.plist` — permisos location always + background modes
- `lib/core/services/` — background location service

### Description
Implementar servicio de ubicación en segundo plano para mantener el raid en vivo incluso con pantalla apagada. Android: Foreground Service con notificación persistente. iOS: Always permission + UIBackgroundModes location. Ver SDD §20.1.

### Steps
1. Android: agregar `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`, `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />`, `<service android:name="com.baseflow.geolocator.GeolocatorForegroundService" android:foregroundServiceType="location" />`
2. iOS: agregar `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes` con `location` y `audio`
3. Implementar `Geolocator.setForegroundNotificationOptions()` con notificación "AsfaltoClub — Trackeando tu ruta en vivo"
4. Implementar permission request flow: WhenInUse → Always (si raid activo)
5. Implementar stop background service al finalizar raid

### Verification
- [ ] Al iniciar raid, aparece notificación foreground "Trackeando tu ruta"
- [ ] App en background sigue enviando posición cada 5s
- [ ] Al finalizar raid, notificación desaparece
- [ ] iOS: solicita Always permission al iniciar primer raid

### Edge Cases
- Usuario deniega Always permission → usar WhenInUse, mostrar badge "📍 GPS limitado"
- Android mata servicio por batería → usar `flutter_background_service` para mantener vivo

---

## Task: T40 — Batería adaptativa (intervalos dinámicos según velocidad)

**Phase:** P1
**Depends on:** T39
**Estimate:** M
**Files:**
- `lib/features/live_map/` — LiveMapBloc (ajuste de intervalos)

### Description
Implementar ajuste dinámico de frecuencia GPS según velocidad para optimizar batería. Ver SDD §20.2.

### Steps
1. Implementar lógica de intervalos: velocidad >10 km/h → cada 3s; <10 km/h → cada 10s; lobby → cada 30s; background → cada 60s
2. Implementar detección de "estacionado": si velocidad=0 por >30s, pausar envío
3. Implementar modo ahorro de batería: reducir frecuencia a la mitad (opcional para el usuario)
4. Implementar notificación al usuario cuando batería <20%

### Verification
- [ ] Velocidad >10 km/h → broadcast cada 3s
- [ ] Velocidad <10 km/h → broadcast cada 10s
- [ ] Velocidad=0 por >30s → pausar broadcast
- [ ] Modo ahorro reduce frecuencia a la mitad

### Edge Cases
- GPS pierde precisión al reducir frecuencia → mantener mínimo 10s incluso en ahorro
- Transiciones bruscas de velocidad → histéresis de 3s antes de cambiar intervalo

---

## Task: T41 — Offline-first cache (drift SQLite local + batch sync)

**Phase:** P0 (infraestructura base)
**Depends on:** T07
**Estimate:** L
**Files:**
- `lib/core/cache/local_database.dart` — Drift database
- `lib/core/network/connectivity_service.dart` — Connectivity detection
- `lib/features/live_map/data/services/offline_gps_buffer.dart` — GPS buffer
- `pubspec.yaml` — agregar drift + sqlite3_flutter_libs

### Description
Implementar arquitectura offline-first: buffer local SQLite con drift para posiciones GPS, datos de raid, mensajes de chat. Sincronización batch al reconectar. Ver Design §10.

### Steps
1. Configurar Drift: agregar drif t, sqlite3_flutter_libs, path_provider a pubspec.yaml
2. Crear `LocalDatabase` con tablas: LocalPositionBuffer, CachedRaid, CachedProfile, PendingChatMessage
3. Implementar `ConnectivityService`: detectar online/offline, emitir stream
4. Implementar buffer de posiciones: guardar en SQLite local + sync batch al reconectar
5. Implementar cache de raids y perfiles
6. Implementar buffer de mensajes de chat pendientes
7. Implementar estrategia de cache por tipo de dato con TTLs

### Verification
- [ ] Sin conexión: posiciones se guardan en SQLite local
- [ ] Al reconectar: posiciones se sincronizan a raid_position_log
- [ ] Sin conexión: datos de raid se cargan desde cache local
- [ ] Mensajes pendientes se envían al reconectar
- [ ] Cache de perfil tiene TTL de 1 hora

### Edge Cases
- Disco lleno → no se pueden guardar posiciones locales (manejar error)
- Sync parcial (algunos items fallan) → reintentar en próximo sync
- Cache de raids: stale-while-revalidate, mostrar datos cacheados mientras se refresca

---

## Task: T42 — Configurar LiveKit server (self-hosted o cloud)

**Phase:** P2
**Depends on:** T19
**Estimate:** M
**Files:**
- `docker-compose.yml` — configuración de LiveKit (si self-hosted)
- Variables de entorno en Supabase: LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_HOST

### Description
Configurar y desplegar el servidor LiveKit para voice chat. Opciones: LiveKit Cloud (trial free con 10,000 min/mes) o self-hosted en VPS con Docker. Ver SDD §20.5.

### Steps
1. Opción A — LiveKit Cloud: crear cuenta, obtener API Key + Secret, configurar en Supabase
2. Opción B — Self-hosted: desplegar con docker-compose (livekit-server + redis + coturn)
3. Configurar LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_HOST en Supabase Edge Function secrets
4. Verificar que Edge Functions on-raid-start y grant-voice-access pueden crear rooms y generar tokens
5. Configurar WebRTC ports (UDP 7882) en firewall para LiveKit

### Verification
- [ ] LiveKit server responde en LIVEKIT_HOST
- [ ] POST /api/v1/rooms crea room exitosamente
- [ ] AccessToken generado permite conexión WebSocket
- [ ] Audio fluye entre dos participantes en mismo room

### Edge Cases
- LiveKit Cloud free: 10,000 min/mes (~4 raids de 20 pax × 2h)
- Self-hosted: requerir VPS con 2 vCPU, 4GB RAM, puertos UDP abiertos
- TURN server necesario si los participantes están detrás de NAT estricto

---

## Task: T43 — Edge Function on-raid-start (LiveKit room + push notifications + weather)

**Phase:** P2
**Depends on:** T19, T27
**Estimate:** M
**Files:**
- `supabase/functions/on-raid-start/index.ts` — Edge Function TypeScript

### Description
Deployar Edge Function `on-raid-start` que orquesta el inicio del raid: cambia status a 'active', crea room LiveKit, genera tokens, envía notificaciones Realtime, y consulta clima si no se hizo antes. Ver Design §6.6.

### Steps
1. Deployar Edge Function `on-raid-start` (ver Design §6.6, código TypeScript completo)
2. Integrar LiveKit: crear room + generar tokens por participante
3. Enviar notificaciones Realtime a user:{userId}:notifications con raid_started
4. Consultar clima si no se hizo antes: POST a get-route-weather
5. Guardar voice_channel en tabla voice_channels

### Verification
- [ ] Ejecutar on-raid-start → raid.status = 'active'
- [ ] LiveKit room creado con nombre raid-{id}
- [ ] Cada participante tiene livekit_token y livekit_room
- [ ] Notificaciones Realtime enviadas a participantes
- [ ] Clima consultado si no se había hecho antes

### Edge Cases
- LiveKit no configurado → raid continúa sin voz (loggear error)
- Clima falla → raid continúa sin datos climáticos (no crítico)

---

## Task: T44 — Edge Function grant-voice-access (LiveKit JWT refresh)

**Phase:** P2
**Depends on:** T19
**Estimate:** S
**Files:**
- `supabase/functions/grant-voice-access/index.ts` — Edge Function TypeScript

### Description
Deployar Edge Function para refrescar tokens de LiveKit. Útil para raids largos donde el token original puede expirar, o para clan voice channels (24/7). Ver Design §6.8.

### Steps
1. Deployar Edge Function `grant-voice-access` (ver Design §6.8, código TypeScript completo)
2. Implementar: recibir room_name, generar AccessToken con roomJoin+canPublish+canSubscribe, devolver token

### Verification
- [ ] POST a grant-voice-access con room_name → devuelve token JWT válido
- [ ] Token permite conexión al room especificado

### Edge Cases
- LiveKit no configurado → 501 "LiveKit not configured"
- Room no existe → el token se genera igual, conexión falla en cliente

---

## Task: T45 — Navegación + routing de nuevas pantallas

**Phase:** P0
**Depends on:** T07
**Estimate:** M
**Files:**
- `lib/app.dart` — agregar nuevas rutas

### Description
Agregar las nuevas rutas de navegación al router de la app. Ver Design §9.6.

### Steps
1. Agregar rutas: `/raids`, `/raids/create`, `/raids/:id/lobby`, `/raids/:id/live`, `/raids/:id/results`
2. Agregar rutas: `/clans`, `/clans/create`, `/clans/:id`, `/clans/:id/settings`
3. Agregar ruta: `/leaderboard`
4. Agregar ruta: `/admin`
5. Integrar en MainShell: agregar tabs/buttons para raids, clanes, leaderboard

### Verification
- [ ] Navegar a /raids muestra lista de raids
- [ ] Navegar a /clans muestra lista de clanes
- [ ] Navegar a /leaderboard muestra leaderboards
- [ ] Deep linking: /raids/:id/lobby funciona con raid ID real

### Edge Cases
- Ruta no encontrada → mostrar 404 o redirigir a dashboard
- Navegación protegida: /admin requiere role='admin'

---

# Resumen de Estimaciones

| Fase | Tareas | Total estimado |
|------|--------|---------------|
| P0 — Fundación | T01–T12 (12 tasks) | ~7 días |
| P1 — Core Gameplay | T13–T18 (6 tasks) | ~5 días |
| P2 — Social + Progresión | T19–T24 (6 tasks) | ~5 días |
| P3 — Monetización + Extra | T25–T32 (8 tasks) | ~7 días |
| P3+ — Integración Existente | T33–T38 (6 tasks) | ~3 días |
| Infraestructura | T39–T45 (7 tasks) | ~4 días |
| **Total** | **45 tasks** | **~31 días** |

## Dependencias clave para paralelización

- **T01–T05** (SQL/RLS/Storage): en paralelo con **T07** (dependencias Flutter)
- **T06** (Auth) + **T08** (ApiClient): en serie después de T07
- **T11** (Clanes) y **T12** (Raids): pueden hacerse en paralelo después de T08
- **T13** (Mapa) después de T12; **T14** (Checkpoints) después de T01
- **T15** (Chat) después de T11+T12
- **T19–T20** (LiveKit/TTS) independiente de T13–T18
- **T22** (XP) después de T16; **T25** (Economía) después de T22
- **T39–T41** (Infraestructura) pueden empezar temprano después de T07
