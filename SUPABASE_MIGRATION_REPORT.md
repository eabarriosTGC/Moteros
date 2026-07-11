# AsfaltoClub / Moteros — Reporte Completo de Migración a Supabase

> **Generado:** Julio 2026
> **Propósito:** Mapa completo de todos los touch points, APIs, esquemas, dependencias y lógica de negocio que debe migrarse a Supabase (Auth, Database, Realtime, Storage, Edge Functions).

---

## 1. DATABASE SCHEMA (PostgreSQL + PostGIS → Supabase Postgres)

### 1.1 ENUMs

```sql
user_role      → ENUM ('aspirant', 'member', 'admin', 'ally')
place_category → ENUM ('taller','restaurante','hotel','mirador','moto_posada','grua','reposteria','evento','otro')
membership_plan → ENUM ('basic', 'premium')
```

### 1.2 Tablas y Columnas

#### `users`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| email | VARCHAR(255) | UNIQUE NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| full_name | VARCHAR(150) | |
| profile_image | VARCHAR(550) | |
| role | user_role | DEFAULT 'aspirant' |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

#### `refresh_tokens`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| token | VARCHAR(512) | UNIQUE NOT NULL |
| expires_at | TIMESTAMPTZ | NOT NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

#### `places` ⚠️ **PostGIS**
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| name | VARCHAR(255) | NOT NULL |
| description | TEXT | |
| category | place_category | |
| address | VARCHAR(350) | |
| city | VARCHAR(100) | |
| department | VARCHAR(100) | |
| **geom** | **GEOMETRY(Point, 4326)** | ⚠️ PostGIS |
| qr_token | VARCHAR(255) | UNIQUE NOT NULL |
| created_by | INT | → users(id) ON DELETE SET NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

Índices:
- `idx_places_geom` → GIST (geom) ⚠️ PostGIS
- `idx_places_category` → (category)
- `idx_places_qr_token` → (qr_token)

#### `visits`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| place_id | INT | NOT NULL → places(id) ON DELETE CASCADE |
| verified_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| evidence_url | VARCHAR(550) | |
| is_verified | BOOLEAN | DEFAULT FALSE |

Constraint: `uq_user_place_day` UNIQUE (user_id, place_id, DATE_TRUNC('day', verified_at))

Índices: idx_visits_user, idx_visits_place

#### `memberships`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| plan | membership_plan | DEFAULT 'basic' |
| payment_ref | VARCHAR(255) | |
| start_date | TIMESTAMPTZ | NOT NULL |
| end_date | TIMESTAMPTZ | NOT NULL |
| is_active | BOOLEAN | DEFAULT TRUE |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

Índice: idx_memberships_user

#### `allies` ⚠️ **NO EXISTE CREATE TABLE** en migraciones
Se usa en seed data (002) y endpoints admin/allies y refugios, pero **no tiene CREATE TABLE en ninguna migración**. Columnas inferidas del código:
| Columna | Tipo (inferido) |
|---------|-----------------|
| id | SERIAL PK |
| business_name | VARCHAR |
| category | TEXT (categoría de place_category?) |
| description | TEXT |
| benefit | TEXT |
| address | VARCHAR |
| phone | VARCHAR |
| website | VARCHAR |
| latitude | DOUBLE PRECISION |
| longitude | DOUBLE PRECISION |

#### `challenges`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| title | VARCHAR(255) | NOT NULL |
| description | TEXT | |
| icon | VARCHAR(50) | DEFAULT '🏁' |
| ruta | VARCHAR(255) | |
| sort_order | INT | DEFAULT 0 |

Seed: 10 challenges precargados.

#### `user_challenges`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| challenge_id | INT | NOT NULL → challenges(id) ON DELETE CASCADE |
| completed | BOOLEAN | DEFAULT FALSE |
| submitted_at | TIMESTAMPTZ | |

UNIQUE(user_id, challenge_id)

#### `patches`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| name | VARCHAR(255) | NOT NULL |
| icon | VARCHAR(50) | DEFAULT '🏍️' |
| place | VARCHAR(255) | |
| requirement | TEXT | |

Seed: 10 patches precargados.

#### `user_patches`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| patch_id | INT | NOT NULL → patches(id) ON DELETE CASCADE |
| earned | BOOLEAN | DEFAULT FALSE |
| earned_at | TIMESTAMPTZ | |

UNIQUE(user_id, patch_id)

#### `evidence_photos`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| place_id | INT | NOT NULL → places(id) ON DELETE CASCADE |
| photo_url | TEXT | NOT NULL |
| captured_at | TIMESTAMPTZ | NOT NULL |
| latitude | DOUBLE PRECISION | NOT NULL |
| longitude | DOUBLE PRECISION | NOT NULL |
| accuracy_meters | DOUBLE PRECISION | |
| verified | BOOLEAN | DEFAULT FALSE |
| distance_meters | DOUBLE PRECISION | |
| points_awarded | INT | DEFAULT 0 |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

Índices: idx_evidence_photos_user, idx_evidence_photos_place

#### `user_points`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| total_points | INT | DEFAULT 0 |
| visits_count | INT | DEFAULT 0 |
| photos_count | INT | DEFAULT 0 |
| last_visit_at | TIMESTAMPTZ | |

UNIQUE(user_id)

#### `saved_routes`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| name | VARCHAR(255) | |
| total_distance_m | DOUBLE PRECISION | DEFAULT 0 |
| duration_seconds | INT | DEFAULT 0 |
| avg_speed_kmh | DOUBLE PRECISION | DEFAULT 0 |
| max_speed_kmh | DOUBLE PRECISION | DEFAULT 0 |
| points_count | INT | DEFAULT 0 |
| polyline_json | TEXT | JSON array [lat,lng] |
| start_lat | DOUBLE PRECISION | |
| start_lng | DOUBLE PRECISION | |
| end_lat | DOUBLE PRECISION | |
| end_lng | DOUBLE PRECISION | |
| started_at | TIMESTAMPTZ | |
| ended_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

Índice: idx_saved_routes_user

#### `road_alerts`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| user_id | INT | → users(id) ON DELETE SET NULL |
| type | VARCHAR(50) | NOT NULL |
| title | VARCHAR(255) | |
| description | TEXT | |
| latitude | DOUBLE PRECISION | NOT NULL |
| longitude | DOUBLE PRECISION | NOT NULL |
| severity | VARCHAR(20) | DEFAULT 'info' |
| active | BOOLEAN | DEFAULT TRUE |
| expires_at | TIMESTAMPTZ | |
| upvotes | INT | DEFAULT 0 |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

Índices: idx_road_alerts_location(latitude,longitude), idx_road_alerts_active

#### `user_follows`
| Columna | Tipo | Constraints |
|---------|------|-------------|
| id | SERIAL | PK |
| follower_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| followed_id | INT | NOT NULL → users(id) ON DELETE CASCADE |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

UNIQUE(follower_id, followed_id), CHECK(follower_id != followed_id)
Índices: idx_follows_follower, idx_follows_followed

#### `(Missing)` allies table
**⚠️ NO TIENE CREATE TABLE en ninguna migración existente.** Se usa en seed data, admin/allies y refugios endpoints.

---

### 1.3 PostGIS Function

```sql
CREATE OR REPLACE FUNCTION is_within_distance(
    p_geom   GEOMETRY,
    p_lat    DOUBLE PRECISION,
    p_lng    DOUBLE PRECISION,
    p_meters DOUBLE PRECISION DEFAULT 100
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
    SELECT ST_DWithin(
        p_geom::geography,
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        p_meters
    );
$$;
```

---

## 2. API ENDPOINTS (Dart Frog → Supabase Edge Functions)

### 2.1 Auth (NO auth middleware)
| Método | Path | Auth | Params (body/query) | SQL/Acción | Respuesta |
|--------|------|------|---------------------|------------|-----------|
| POST | `/auth/login` | No | email, password | `SELECT ... FROM users WHERE email = @email`, compara SHA256 password, INSERT refresh_token | {token, refreshToken, email, role} |
| POST | `/auth/register` | No | email, password, fullName | INSERT INTO users RETURNING id, INSERT refresh_token | {token, refreshToken, email, role} |
| POST | `/auth/google` | No | id_token, email, full_name, photo_url | Busca o INSERT INTO users (password_hash=''), INSERT refresh_token | {token, refreshToken, email, role} |
| POST | `/auth/refresh` | No | refreshToken | SELECT rt.user_id + u.role, valida expiry, DELETE old + INSERT new refresh_token | {token, refreshToken} |

### 2.2 Middleware de autenticación
Usado por: `validation/*`, `memberships/*`, `admin/*`

```dart
// auth_middleware.dart / validation/_middleware.dart / memberships/_middleware.dart / admin/_middleware.dart
// Extrae header "Authorization: Bearer <token>", verifica JWT manual (HS256), provee userId al handler
```

### 2.3 Dashboard
| Método | Path | Auth | Query | Respuesta |
|--------|------|------|-------|-----------|
| GET | `/dashboard` | Manual* | - | {email, role, fullName, placesVisited, totalPlaces, challengesCompleted, totalChallenges, membershipPlan, membershipDaysLeft} |

*Usa `getUserId()` manual, no middleware.

### 2.4 Places
| Método | Path | Auth | Query | SQL/Acción |
|--------|------|------|-------|------------|
| GET | `/places` | No | lat, lng, radius(default 5000) | `SELECT ... ST_DWithin(geom::geography, ..., @radius)` ordenado por `<->` proximidad, LIMIT 50 ⚠️ PostGIS |
| GET | `/places/[id]` | No | path param id | `SELECT ... FROM places WHERE id = @id` con ST_Y/ST_X |

### 2.5 Visits (manual auth)
| Método | Path | Auth | Body | SQL/Acción |
|--------|------|------|------|------------|
| POST | `/visits` | Manual* | place_id, photo_url, latitude, longitude, accuracy_meters | Haversine (cálculo en Dart, NO PostGIS). INSERT evidence_photos + UPSERT user_points |
| GET | `/visits` | Manual* | - | SELECT evidence_photos + places JOIN, history |

*Usa `getUserId()` manual.

### 2.6 Validation (con authMiddleware)
| Método | Path | Auth | Body | SQL/Acción | PostGIS |
|--------|------|------|------|------------|---------|
| POST | `/validation` | ✅ | qr_token, latitude, longitude, evidence_url | `SELECT id FROM places WHERE qr_token = @token AND is_within_distance(geom, @lat, @lng, 100)` → INSERT visits | **SÍ** usa `is_within_distance` |

### 2.7 Memberships (con authMiddleware)
| Método | Path | Auth | Body | SQL/Acción |
|--------|------|------|------|------------|
| GET | `/memberships` | ✅ | - | SELECT active membership del user |
| POST | `/memberships` | ✅ | payment_id, plan | INSERT membership + UPDATE users SET role='member' |

### 2.8 Admin / Allies (con authMiddleware)
| Método | Path | Auth | Body | SQL/Acción |
|--------|------|------|------|------------|
| GET | `/admin/allies` | ✅ | - | SELECT FROM allies |
| POST | `/admin/allies` | ✅ | businessName, category, desc, benefit, address, phone, website, lat, lng | INSERT INTO allies |

### 2.9 Refugios (SIN auth)
| Método | Path | Auth | SQL/Acción |
|--------|------|------|------------|
| GET | `/refugios` | No | SELECT FROM allies (¡misma tabla que admin!) |

### 2.10 Challenges (manual auth)
| Método | Path | Auth | Body | SQL/Acción |
|--------|------|------|------|------------|
| GET | `/challenges` | Manual* | - | SELECT c + LEFT JOIN user_challenges |
| POST | `/challenges` | Manual* | challenge_id, evidence_url | INSERT/UPDATE user_challenges |

*Usa `getUserId()` manual.

### 2.11 Patches (manual auth)
| Método | Path | Auth | SQL/Acción |
|--------|------|------|------------|
| GET | `/patches` | Manual* | SELECT p + LEFT JOIN user_patches |

*Usa `getUserId()` manual.

### 2.12 Tracks (manual auth)
| Método | Path | Auth | Body | SQL/Acción |
|--------|------|------|------|------------|
| POST | `/tracks` | Manual* | name, distance, duration, avgSpeed, maxSpeed, points, polyline, start/end lat/lng | INSERT INTO saved_routes |
| GET | `/tracks` | Manual* | - | SELECT FROM saved_routes WHERE user_id |

*Usa `getUserId()` manual. Nota: endpoint montado en `/tracks` pero Flutter llama a `/routes`.

### 2.13 Follows (manual auth)
| Método | Path | Auth | Query/Body | SQL/Acción |
|--------|------|------|------------|------------|
| GET | `/follows` | Manual* | type=followers\|following, user_id, check | SELECT followers/following o check if following |
| POST | `/follows` | Manual* | user_id | INSERT INTO user_follows |
| DELETE | `/follows` | Manual* | ?user_id=X | DELETE FROM user_follows |

*Usa `getUserId()` manual.

### 2.14 Alerts (manual auth)
| Método | Path | Auth | Body | SQL/Acción |
|--------|------|------|------|------------|
| GET | `/alerts` | No (opcional) | - | SELECT FROM road_alerts WHERE active=true |
| POST | `/alerts` | Manual* | type, title, desc, lat, lng, severity | INSERT INTO road_alerts |

*userId puede ser null (GET público).

### 2.15 Import
| Método | Path | Auth | Body | Acción |
|--------|------|------|------|--------|
| POST | `/import` | No | department, city (opcional) | Llama a Overpass API de OSM, mapea tags → categorías, INSERT INTO places con ST_SetSRID |
| POST | `/import/manual` | Manual* | name, category, latitude, longitude | INSERT INTO places con ST_SetSRID, genera QR token manual |

*Usa `getUserId()` manual.

### 2.16 Root
| Método | Path | Auth |
|--------|------|------|
| GET | `/` | No → {service, version, status} |

---

## 3. AUTH FLOW (JWT Manual → Supabase Auth)

### Estado actual
- **Password hashing:** SHA256 (librería `crypto` package, función `hashPassword`)
- **JWT creation:** Manual HS256 con `crypto` HMAC. Header: `{alg: HS256, typ: JWT}`. Payload: `{sub: userId, role, iat, exp}`.
- **JWT secret:** `JWT_SECRET` env var (default 'cambia-esto')
- **JWT expiration:** `JWT_EXPIRATION_MINUTES` env var (default 15 min)
- **Token verification:** Parse manual de 3 partes, HMAC verify, chequeo exp
- **Refresh tokens:** Generados con SHA256 de 64 bytes aleatorios, almacenados en tabla `refresh_tokens`, expiran a 30 días, con rotación (delete + insert en cada refresh)
- **Google Sign-In:** Flutter usa `google_sign_in` + `firebase_auth` para obtener ID token de Google. El token se envía al backend (`/auth/google`) que NO verifica el token contra Firebase Admin SDK (comentario lo indica como "opcional").
- **Flutter token storage:** `flutter_secure_storage` con claves `jwt_token` y `refresh_token`.
- **Auth interceptor (Flutter):** `AuthInterceptor` de Dio agrega `Authorization: Bearer` a cada request y maneja refresh automático en 401.

### Lo que debe reemplazarse
| Componente Actual | Supabase Replacement |
|------------------|---------------------|
| JWT manual HS256 | `supabase.auth` — JWT de Supabase |
| refresh_tokens table | `supabase.auth` session management |
| SHA256 password hashing | `supabase.auth.signUp()` / `signInWithPassword()` |
| Google Sign-In manual | `supabase.auth.signInWithOAuth('google')` |
| flutter_secure_storage | `supabase.auth` session auto-storage |
| AuthInterceptor (Dio) | `supabase.auth` token management built-in |

---

## 4. WEBSOCKET / REALTIME (Chat)

### Estado actual
- **Servidor standalone** en puerto 8082 (`ws_server.dart`)
- **No usa** el server Dart Frog principal; es un `HttpServer` independiente
- **Chat Hub** (`chat_hub.dart`) singleton in-memory para manejar conversaciones por `conversationId`
- **Flutter:** `web_socket_channel` package, conecta a `ws://192.168.101.5:8082/ws?room=X&user=Y`
- **Mensajes:** JSON con type, message, user, timestamp
- **Sin persistencia:** Los mensajes NO se guardan en DB. Son volátiles en memoria.
- **Sin autenticación:** El WebSocket no verifica JWT.
- **Fallback local:** Si no puede conectar, el ChatBloc muestra mensajes mock.

### Migración a Supabase
| Feature Actual | Supabase Realtime |
|---------------|-------------------|
| WebSocket server standalone | `supabase.realtime` channels |
| ChatHub in-memory | Broadcast via Realtime |
| Mensajes volátiles | INSERT en tabla `chat_messages` + Realtime broadcast |
| Sin auth | Realtime usa JWT de Supabase (RLS) |

---

## 5. FILE STORAGE (Imágenes)

### Estado actual
- **Cloudinary** (`cloudinary_flutter` en pubspec.yaml) **declarado pero NO implementado** en ningún archivo de la app.
- **Fotos de evidencia:** Se envían como path local `photo_url: 'capture://...'` al backend — NO se suben a ningún servicio cloud.
- **Imágenes de perfil:** columna `profile_image` en users, no hay lógica de upload.
- **Imágenes de lugares:** campo `imageUrl` en el modelo PlaceModel pero nunca se setea desde el backend.

### Migración a Supabase
- **Supabase Storage** para todas las imágenes
- Buckets: `place-photos`, `evidence-photos`, `profile-images`
- Las URLs actuales de Cloudinary (si se usaran) → URLs públicas de Supabase Storage

---

## 6. FLUTTER DATASOURCES (Feature → Endpoint Map)

### 6.1 Auth Feature
| Datasource/Bloc | Endpoint | Método | Body |
|----------------|----------|--------|------|
| `AuthRemoteDataSource.login()` | `/auth/login` | POST | {email, password} |
| `AuthBloc._onRegisterRequested()` | `/auth/register` | POST | {email, password, fullName} |
| `GoogleAuthRepository.signInWithGoogle()` | `/auth/google` | POST | {id_token, email, full_name, photo_url} |
| `AuthInterceptor._refresh()` | `/auth/refresh` | POST | {refreshToken} |

### 6.2 Places Feature
| Datasource/Bloc | Endpoint | Método | Query |
|----------------|----------|--------|-------|
| `PlaceRemoteDataSource.getNearbyPlaces()` | `/places` | GET | {lat, lng, radius} |

### 6.3 Validation Feature
| Datasource/Bloc | Endpoint | Método | Body |
|----------------|----------|--------|------|
| `ValidationRemoteDataSource.validateQr()` | `/validation` | POST | {qr_token, latitude, longitude, evidence_url} |

### 6.4 Verification (Evidence Screen) — ✅ **POST /visits**
| Bloc/Screen | Endpoint | Método | Body |
|------------|----------|--------|------|
| `ScanBloc._confirm()` | `/visits` | POST | {place_id, photo_url, latitude, longitude, accuracy_meters} |

### 6.5 Membership Feature
| Datasource/Bloc | Endpoint | Método |
|----------------|----------|--------|
| `MembershipRemoteDataSource.getCurrent()` | `/memberships` | GET |
| `MembershipRemoteDataSource.activate()` | `/memberships` | POST |

### 6.6 Dashboard Feature
| Bloc | Endpoint | Método |
|------|----------|--------|
| `DashboardBloc._onLoadDashboard()` | `/dashboard` | GET |

### 6.7 Admin Feature
| Datasource/Bloc | Endpoint | Método |
|----------------|----------|--------|
| `AdminRemoteDataSource.getAllies()` | `/admin/allies` | GET |
| `AdminRemoteDataSource.createAlly()` | `/admin/allies` | POST |

### 6.8 Challenges Feature
| Bloc | Endpoint | Método |
|------|----------|--------|
| `ChallengesBloc._onLoad()` | `/challenges` | GET |
| `ChallengesBloc._onComplete()` | `/challenges` | POST |

### 6.9 Patches Feature
| Bloc | Endpoint | Método |
|------|----------|--------|
| `PatchesBloc (LoadPatches)` | `/patches` | GET |

### 6.10 Tracker Feature
| Bloc | Endpoint | Método |
|------|----------|--------|
| `TrackerBloc._save()` | `/tracks` (Flutter usa `/routes`) | POST |

### 6.11 Follows Feature
Ya implementado como endpoint `/follows` con GET/POST/DELETE.

### 6.12 Alerts Feature
Endpoint `/alerts` con GET (público) y POST (auth manual).

### 6.13 Refugios Feature
- `RefugiosBloc` actualmente usa **datos mock hardcodeados** (no llama al backend)
- Endpoint real: `GET /refugios` (público, consulta tabla `allies`)

---

## 7. GEOLOCATION TOUCH POINTS (PostGIS → Supabase PostGIS)

### 7.1 Lugares de Proximidad
| Ubicación | Uso | Tipo |
|-----------|-----|------|
| `places.geom` GEOMETRY(Point,4326) | Almacenar ubicación de cada lugar | PostGIS Column |
| `idx_places_geom` GIST index | Indexación espacial | PostGIS Index |
| `GET /places?lat=&lng=&radius=` | `ST_DWithin(geom::geography, ..., @radius)` + `ORDER BY geom <-> ...` | PostGIS Query |
| `GET /places/[id]` | `ST_Y(geom), ST_X(geom)` para extraer lat/lng | PostGIS Function |
| `POST /import` | `ST_SetSRID(ST_MakePoint(@lon, @lat), 4326)` para insertar | PostGIS Function |
| `POST /import/manual` | `ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)` | PostGIS Function |
| `002_seed_data.sql` | `ST_SetSRID(ST_MakePoint(...), 4326)` en seed data | PostGIS Function |

### 7.2 Validation con proximidad
| Ubicación | Uso |
|-----------|-----|
| `is_within_distance(geom, lat, lng, meters)` | Función que envuelve `ST_DWithin(::geography, ::geography, meters)` |
| `POST /validation` | `WHERE ... AND is_within_distance(geom, @lat, @lng, 100)` — verifica QR + GPS < 100m |

### 7.3 Cálculo Haversine (Dart — NO PostGIS)
| Ubicación | Uso |
|-----------|-----|
| `POST /visits` (backend) | Cálculo de distancia Haversine manual en Dart (NO usa PostGIS) |
| No usa `is_within_distance` ni `ST_DWithin` para visits |

### 7.4 Tablas con coordenadas (sin PostGIS)
| Tabla | Columnas |
|-------|----------|
| `evidence_photos` | latitude DOUBLE PRECISION, longitude DOUBLE PRECISION |
| `road_alerts` | latitude DOUBLE PRECISION, longitude DOUBLE PRECISION |
| `allies` | latitude DOUBLE PRECISION, longitude DOUBLE PRECISION |
| `saved_routes` | start_lat, start_lng, end_lat, end_lng |

### Resumen PostGIS → Supabase
- Supabase **soporta PostGIS nativamente** (extensión habilitada por defecto)
- La migración directa de `GEOMETRY(Point, 4326)`, `ST_DWithin`, `ST_SetSRID`, `ST_MakePoint`, `ST_X`/`ST_Y`, GIST indexes funciona sin cambios
- `is_within_distance` puede convertirse a función SQL o implementarse en Edge Function
- La función Haversine en Dart (para visits) puede reemplazarse por `ST_DWithin` también

---

## 8. DEPENDENCIES

### 8.1 Backend (`backend/pubspec.yaml`)
```yaml
dependencies:
  crypto: ^3.0.7          # SHA256 / HMAC para JWT y password hashing
  dart_frog: ^1.1.0        # HTTP framework (routes/middleware)
  dotenv: ^4.2.0           # Variables de entorno (.env)
  postgres: ^3.5.12        # Cliente PostgreSQL nativo
```
**Al migrar a Supabase:**
- `dart_frog` → Edge Functions (o `supabase_functions` SDK)
- `postgres` → `supabase` SDK (maneja pool, auth, RLS)
- `crypto` → No necesario (Supabase Auth maneja JWT)
- `dotenv` → Variables de entorno de Supabase / Edge Functions

### 8.2 Flutter (`pubspec.yaml`)
```yaml
dependencies:
  dio: ^5.7.0                 # HTTP client → Reemplazar por supabase_flutter
  flutter_secure_storage: ^10.3.1  # → supabase_flutter maneja sesión
  flutter_bloc: ^9.1.1        # → Se mantiene (gestión de estado)
  equatable: ^2.0.8           # → Se mantiene
  mobile_scanner: ^7.2.0      # → Se mantiene (lector QR nativo)
  flutter_map: ^8.3.1         # → Se mantiene (mapa OSM)
  flutter_map_marker_cluster: ^8.2.2  # → Se mantiene
  geolocator: ^14.0.3         # → Se mantiene (GPS nativo)
  latlong2: ^0.9.1            # → Se mantiene (coordenadas)
  image_picker: ^1.2.3        # → Se mantiene (cámara)
  web_socket_channel: ^3.0.2  # → Reemplazar por supabase.realtime
  cloudinary_flutter: ^1.3.0  # → Eliminar (NO implementado, reemplazar por Supabase Storage)
  firebase_core: ^4.11.0      # → Eliminar (reemplazar por Supabase Auth)
  firebase_auth: ^6.5.4       # → Eliminar (reemplazar por Supabase Auth)
  google_sign_in: ^7.2.0      # → Eliminar (Supabase OAuth lo maneja)
  url_launcher: ^6.3.0        # → Se mantiene
  provider: ^6.1.2            # → Se mantiene o reemplazar completamente por BLoC
  cupertino_icons: ^1.0.8     # → Se mantiene
```

---

## 9. ISSUES Y HALLAZGOS CRÍTICOS

### 🔴 Crítico: Tabla `allies` sin CREATE TABLE
La tabla `allies` se referencia en seed data (002), endpoints `admin/allies` y `refugios`, pero **no existe CREATE TABLE en ninguna migración**. Esto provocará error al ejecutar migraciones limpias.

### 🔴 Crítico: Cloudinary declarado pero NO implementado
`cloudinary_flutter` está en pubspec.yaml pero **no hay código que lo use**. Las fotos de evidencia se envían con URL local (`capture://...`). No hay upload a ningún servicio cloud.

### 🟡 Medio: Endpoint mismatch
- Flutter `TrackerBloc._save()` llama a `POST /routes` pero el endpoint real está montado en `POST /tracks`
- El dashboard espera campo `alerts[]` del backend pero el endpoint `/dashboard` no devuelve alerts

### 🟡 Medio: RefugiosBloc usa datos mock
El BLoC de refugios tiene datos hardcodeados en lugar de llamar al endpoint `/refugios`.

### 🟡 Medio: WebSocket sin persistencia ni auth
El chat es completamente volátil y sin autenticación. No hay tabla `chat_messages` en DB.

### 🟢 Info: LoginUseCase sin implementar
`LoginUseCase.execute()` lanza `UnimplementedError`. La lógica real de login está en `AuthBloc` directamente.

### 🟢 Info: Auth remoto duplicado
`AuthRemoteDataSource.login()` llama a `/auth/login` pero el `AuthBloc` hace la misma llamada directamente sin usar este datasource.

---

## 10. ORDEN DE MIGRACIÓN RECOMENDADO

1. **Database Schema** → Migrar todas las tablas a Supabase PostgreSQL (con PostGIS)
   - Crear tabla `allies` faltante
   - Convertir ENUMs a TEXT con CHECK constraints (Supabase no tiene ENUMs nativos en el dashboard)

2. **Auth** → Reemplazar JWT manual + refresh_tokens por Supabase Auth
   - Configurar Google OAuth en Supabase
   - Migrar usuarios existentes (password_hash SHA256 → Supabase Auth admin API)
   - Eliminar `firebase_auth`, `google_sign_in`, `firebase_core`

3. **Edge Functions** → Reemplazar endpoints Dart Frog
   - Prioridad: auth/login → Supabase Auth (no necesita Edge Function)
   - Validation + PostGIS queries
   - Dashboard, Places, Challenges, Patches

4. **Realtime** → Reemplazar WebSocket server por Supabase Realtime
   - Crear tabla `chat_messages`
   - Configurar Realtime broadcast

5. **Storage** → Configurar Supabase Storage buckets
   - profile-images, evidence-photos, place-photos

6. **Flutter client** → Reemplazar Dio/API Client por `supabase_flutter`
   - Eliminar `AuthInterceptor`, `TokenStorage`
   - Actualizar todos los datasources para usar `SupabaseClient`
   - Mantener BLoCs (solo reemplazar la capa de datos)

---

## 11. ARCHIVOS DEL PROYECTO (Inventario)

### Backend (21 archivos de código)
| Archivo | Propósito |
|---------|-----------|
| `backend/lib/auth.dart` | JWT generation/verification, password hashing |
| `backend/lib/database.dart` | PostgreSQL connection (Connection pool singleton) |
| `backend/lib/middleware/auth_middleware.dart` | Auth middleware handler |
| `backend/lib/chat_hub.dart` | In-memory chat hub (singleton) |
| `backend/ws_server.dart` | Standalone WebSocket server (puerto 8082) |
| `backend/routes/index.dart` | GET / (health check) |
| `backend/routes/auth/login.dart` | POST /auth/login |
| `backend/routes/auth/register.dart` | POST /auth/register |
| `backend/routes/auth/google.dart` | POST /auth/google |
| `backend/routes/auth/refresh.dart` | POST /auth/refresh |
| `backend/routes/places/index.dart` | GET /places (proximity query con PostGIS) |
| `backend/routes/places/[id].dart` | GET /places/:id |
| `backend/routes/visits/index.dart` | GET+POST /visits (Haversine en Dart) |
| `backend/routes/validation/index.dart` | POST /validation (PostGIS proximity) |
| `backend/routes/validation/_middleware.dart` | Auth middleware para validation |
| `backend/routes/memberships/index.dart` | GET+POST /memberships |
| `backend/routes/memberships/_middleware.dart` | Auth middleware para memberships |
| `backend/routes/admin/_middleware.dart` | Auth middleware para admin |
| `backend/routes/admin/allies.dart` | GET+POST /admin/allies |
| `backend/routes/dashboard/index.dart` | GET /dashboard |
| `backend/routes/tracks/index.dart` | GET+POST /tracks |
| `backend/routes/follows/index.dart` | GET+POST+DELETE /follows |
| `backend/routes/refugios/index.dart` | GET /refugios |
| `backend/routes/challenges/index.dart` | GET+POST /challenges |
| `backend/routes/patches/index.dart` | GET /patches |
| `backend/routes/alerts/index.dart` | GET+POST /alerts |
| `backend/routes/import/index.dart` | POST /import (Overpass API) |
| `backend/routes/import/manual.dart` | POST /import/manual |

### Backend Migrations (6 archivos SQL)
| Archivo | Tablas |
|---------|--------|
| `001_initial_schema.sql` | users, refresh_tokens, places (PostGIS), visits, memberships + is_within_distance function |
| `002_seed_data.sql` | Seed data: admin user, 5 places, 1 ally |
| `003_challenges_patches.sql` | challenges, user_challenges, patches, user_patches + seed (10 challenges, 10 patches) |
| `004_evidence_photos.sql` | evidence_photos, user_points |
| `005_routes_alerts.sql` | saved_routes, road_alerts |
| `006_user_follows.sql` | user_follows |

### Flutter Features (11 módulos)
| Feature | Datasource | BLoC |
|---------|-----------|------|
| `auth/` | AuthRemoteDataSource, GoogleAuthRepository, FirebaseAuthService | AuthBloc |
| `places/` | PlaceRemoteDataSource | PlacesBloc |
| `validation/` | ValidationRemoteDataSource | ValidationBloc |
| `verification/` | (ScanBloc directo con ApiClient) | ScanBloc |
| `membership/` | MembershipRemoteDataSource | MembershipBloc |
| `dashboard/` | (directo con ApiClient) | DashboardBloc |
| `admin/` | AdminRemoteDataSource | AdminBloc |
| `challenges/` | (directo con ApiClient) | ChallengesBloc |
| `patches/` | (directo con ApiClient) | PatchesBloc |
| `chat/` | (web_socket_channel) | ChatBloc |
| `tracker/` | (directo con ApiClient) | TrackerBloc |
| `refugios/` | (mock data) | RefugiosBloc |
| `profile/` | ProfileScreen (solo UI) | - |

### Flutter Core
| Archivo | Propósito |
|---------|-----------|
| `lib/core/network/api_client.dart` | Dio wrapper con AuthInterceptor |
| `lib/core/network/token_storage.dart` | flutter_secure_storage wrapper |
| `lib/core/network/auth_interceptor.dart` | Bearer token injector + 401 auto-refresh |

---

## 12. RESUMEN DE TOUCH POINTS POR CATEGORÍA

### Supabase Auth
- [ ] Reemplazar 4 endpoints auth (login, register, google, refresh)
- [ ] Reemplazar JWT manual (HS256, crypto package)
- [ ] Reemplazar refresh_tokens table
- [ ] Reemplazar SHA256 password hashing
- [ ] Reemplazar Google Sign-In flow (firebase_auth + google_sign_in) → Supabase OAuth
- [ ] Migrar flutter_secure_storage → Supabase session
- [ ] Migrar AuthInterceptor → Supabase token management

### Supabase Database
- [ ] Migrar 16 tablas (incluyendo tabla allies faltante)
- [ ] Migrar 3 ENUMs
- [ ] Migrar 1 función PostGIS (is_within_distance)
- [ ] Migrar 6 GIST/B-tree indexes
- [ ] Migrar 4 UNIQUE constraints
- [ ] Migrar seed data (1 admin user, 5 places, 1 ally, 10 challenges, 10 patches)
- [ ] Configurar Row Level Security (RLS) en todas las tablas

### Supabase Realtime
- [ ] Reemplazar WebSocket standalone server (puerto 8082)
- [ ] Crear tabla chat_messages con persistencia
- [ ] Migrar ChatHub in-memory → Realtime broadcasts
- [ ] Eliminar web_socket_channel dependency

### Supabase Storage
- [ ] Configurar buckets (evidence-photos, profile-images, place-photos)
- [ ] Implementar upload de fotos de evidencia (actualmente no implementado)
- [ ] Migrar (o implementar) Cloudinary → Supabase Storage

### Supabase Edge Functions
- [ ] Migrar 23 endpoints REST de Dart Frog
- [ ] Migrar PostGIS proximity queries (5 endpoints)
- [ ] Migrar Overpass API import (1 endpoint)
- [ ] Migrar Haversine distance calculation (1 endpoint)

### Flutter Client
- [ ] Reemplazar Dio/ApiClient → supabase_flutter client
- [ ] Actualizar 10 BLoCs data sources
- [ ] Eliminar: firebase_core, firebase_auth, google_sign_in, cloudinary_flutter
- [ ] Mantener: flutter_map, mobile_scanner, geolocator, flutter_bloc
