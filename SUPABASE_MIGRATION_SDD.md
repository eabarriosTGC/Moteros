# SDD — Propuesta de Migración: Dart Frog + PostGIS → Supabase

> **Proyecto:** Moteros / AsfaltoClub  
> **Documento:** Propuesta de Cambio — Migración a Supabase (sin PostGIS)  
> **Autor:** Hermes Agent / Nous Research  
> **Fecha:** Julio 2026  
> **Estado:** ✅ Propuesta (Pendiente de aprobación)

---

## 1. TÍTULO Y OBJETIVO

**Migrar Moteros/AsfaltoClub de Dart Frog + PostGIS a Supabase**

### Objetivo

Reemplazar el stack auto-hospedado actual (Dart Frog REST API + PostgreSQL 15 + PostGIS + JWT manual + WebSocket standalone + Firebase Auth) por Supabase como plataforma unificada, eliminando PostGIS en favor de columnas `latitude`/`longitude` + índices B-tree + función háversine SQL pura, y resolviendo bugs existentes identificados en `SUPABASE_MIGRATION_REPORT.md`.

---

## 2. ALCANCE

### ✅ QUÉ se migra

| Componente | Origen | Destino |
|---|---|---|
| Base de datos | PostgreSQL 15 + PostGIS (Docker) | Supabase PostgreSQL (sin PostGIS) |
| API REST | 23 endpoints Dart Frog | RLS policies + Edge Functions (donde RLS no alcanza) |
| Autenticación | JWT manual HS256 + Firebase Auth + Google Sign-In | Supabase Auth (JWT nativo + OAuth) |
| WebSocket / Chat | Servidor standalone puerto 8082 (sin persistencia) | Supabase Realtime |
| Almacenamiento | Cloudinary (declarado, no implementado) | Supabase Storage |
| Flutter client | Dio + flutter_secure_storage + firebase_auth | supabase_flutter SDK |

### ❌ QUÉ NO se migra

| Componente | Razón |
|---|---|
| UI/UX (pantallas, widgets) | No dependen del backend |
| BLoCs (gestión de estado) | Se mantienen intactos — solo cambia datasource |
| Mapa OSM (flutter_map) | Cliente-side, independiente del backend |
| QR Scanner (mobile_scanner) | Funcionalidad nativa del dispositivo |
| Geolocator (GPS) | Funcionalidad nativa del dispositivo |
| Image picker | Funcionalidad nativa del dispositivo |

### 🔧 QUÉ se arregla (bugs existentes)

| Bug | Descripción | Arreglo en migración |
|---|---|---|
| `allies` sin CREATE TABLE | Tabla referenciada en seed y endpoints, no existe en migraciones | Crear tabla en schema inicial |
| Cloudinary no implementado | Declarado en pubspec, jamás usado | Reemplazar por Supabase Storage con implementación real |
| RefugiosBloc usa mock | Datos hardcodeados, nunca conecta a `/refugios` | Conectar a consulta RLS directa sobre `allies` |
| Endpoint mismatch: `/routes` vs `/tracks` | Flutter llama a `/routes`, backend monta `/tracks` | Unificar en tabla `saved_routes`, Flutter apunta a consulta RLS |
| WebSocket sin persistencia | Mensajes volátiles en memoria, sin auth | Tabla `chat_messages` + Realtime broadcast + RLS |
| LoginUsecase sin implementar | Lanza `UnimplementedError` | Eliminar o redirigir a Supabase Auth |
| AuthRemoteDataSource duplicado | AuthBloc hace petición directa sin usar el datasource | Reemplazar ambos por `supabase.auth` |

---

## 3. ESTRATEGIA DE MIGRACIÓN

### 3.1 Sustitución de PostGIS

```
┌─────────────────────────┐       ┌──────────────────────────┐
│       ANTES             │       │        DESPUÉS           │
│                         │       │                          │
│ places.geom             │  ──►  │ places.latitude          │
│   GEOMETRY(Point,4326)  │       │ places.longitude         │
│                         │       │   DOUBLE PRECISION       │
│ idx_places_geom GIST    │  ──►  │ idx_places_location      │
│                         │       │   BTREE(lat, lng)        │
│ is_within_distance()    │  ──►  │ haversine_distance()     │
│   ST_DWithin            │       │   SQL pura (sin PostGIS) │
│                         │       │                          │
│ ST_DWithin / <-> /      │  ──►  │ WHERE ... AND           │
│ ORDER BY geom <->       │       │ haversine_distance(...)  │
│                         │       │   <= radius              │
│                         │       │ ORDER BY distance ASC    │
└─────────────────────────┘       └──────────────────────────┘
```

### 3.2 Sustitución de Auth

```
┌─────────────────────┐       ┌─────────────────────────┐
│       ANTES         │       │        DESPUÉS           │
│                     │       │                         │
│ JWT manual HS256    │  ──►  │ Supabase Auth JWT       │
│ SHA256 passwords    │  ──►  │ supabase.auth.signUp()  │
│ refresh_tokens tbl  │  ──►  │ Gestión nativa sesión   │
│ Firebase Auth       │  ──►  │ Eliminado               │
│ google_sign_in      │  ──►  │ signInWithOAuth(google) │
│ flutter_secure_...  │  ──►  │ supabase_flutter sess.  │
│ AuthInterceptor Dio │  ──►  │ SupabaseClient built-in │
└─────────────────────┘       └─────────────────────────┘
```

### 3.3 Sustitución de APIs

```
┌─────────────────────────┐       ┌────────────────────────────┐
│     ANTES (23 e/s)     │       │       DESPUÉS              │
│                         │       │                            │
│ 23 endpoints Dart Frog  │  ──►  │ RLS policies (16 tablas)   │
│                         │       │ + 3 Edge Functions         │
│ Middleware JWT manual   │  ──►  │ Supabase Auth RLS          │
│                         │       │                            │
│ WebSocket standalone    │  ──►  │ Supabase Realtime          │
│ (chat, sin persist.)    │       │ + tabla chat_messages      │
└─────────────────────────┘       └────────────────────────────┘
```

### 3.4 Estrategia de capas

| Capa | Acción |
|---|---|
| **Flutter UI** | Sin cambios |
| **Flutter BLoC** | Sin cambios |
| **Flutter DataSources** | Reemplazar implementación: Dio → supabase_flutter |
| **Supabase Edge Functions** | Solo 3 funciones para lo que RLS no alcanza |
| **Supabase RLS** | Control de acceso principal |
| **Supabase Auth** | Reemplazar JWT manual + Firebase |
| **Supabase DB** | Schema sin PostGIS |

---

## 4. ARQUITECTURA TARGET

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          FLUTTER APP                                     │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    BLoCs (sin cambios)                            │   │
│  │  AuthBloc │ PlacesBloc │ ValidationBloc │ ScanBloc │ ChatBloc…   │   │
│  └──────────┬──────────────────────────────┬────────────────────────┘   │
│             │                              │                             │
│             ▼                              ▼                             │
│  ┌─────────────────────┐    ┌───────────────────────────┐               │
│  │  supabase_flutter   │    │  Flutter Map / Geolocator  │               │
│  │  (auth, db, realtime)│    │  (mantenido, client-side)  │               │
│  └──────────┬──────────┘    └───────────────────────────┘               │
└─────────────┼────────────────────────────────────────────────────────────┘
              │
              │ HTTPS / WebSocket
              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE PLATFORM                                │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                      SUPABASE AUTH                               │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐   │   │
│  │  │ Email/Pass  │  │ Google OAuth │  │ Session Management   │   │   │
│  │  └─────────────┘  └──────────────┘  └──────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     SUPABASE DATABASE (Postgres)                  │   │
│  │                                                                  │   │
│  │  ┌──────────────────────────────────────────────────────┐       │   │
│  │  │  16 tablas + 3 ENUMS (como TEXT CHECK) + RLS        │       │   │
│  │  │  Sin PostGIS. lat/lng en places. B-tree indexes     │       │   │
│  │  │  Función háversine_distance() SQL                   │       │   │
│  │  └──────────────────────────────────────────────────────┘       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                  SUPABASE EDGE FUNCTIONS (3)                     │   │
│  │  ┌─────────────────┐ ┌──────────────┐ ┌──────────────────┐     │   │
│  │  │ POST /validation│ │ POST /import │ │ GET /dashboard   │     │   │
│  │  │ (QR+distancia)  │ │ (Overpass    │ │ (agregaciones)   │     │   │
│  │  │                 │ │  OSM API)    │ │                  │     │   │
│  │  └─────────────────┘ └──────────────┘ └──────────────────┘     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │              SUPABASE REALTIME                                   │   │
│  │  Tabla chat_messages + Broadcast por conversation_id            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │              SUPABASE STORAGE                                    │   │
│  │  3 buckets: place-photos, evidence-photos, profile-images       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 5. MIGRACIÓN DE ESQUEMA — SQL TARGET COMPLETO

### 5.1 Schema completo (sin PostGIS, con lat/lng + háversine)

```sql
-- ============================================================
-- SUPABASE MIGRATION: FULL SCHEMA (NO POSTGIS)
-- ============================================================

-- 5.1.1 ENUMs como TEXT CHECK (Supabase no expone ENUMs en dashboard)
-- Se mantienen como CHECK constraints para compatibilidad

-- 5.1.2 TABLA: users
CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255),  -- nullable: solo para usuarios migrados de SHA256
    full_name       VARCHAR(150),
    profile_image   VARCHAR(550),  -- Supabase Storage URL
    role            TEXT NOT NULL DEFAULT 'aspirant'
                    CHECK (role IN ('aspirant', 'member', 'admin', 'ally')),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Nota: Supabase Auth maneja auth.users aparte.
-- Esta tabla `users` es el PERFIL del usuario (1:1 con auth.users)
-- La relación se hace por email o por user_id cuando se migren usuarios.

-- 5.1.3 TABLA: refresh_tokens — ELIMINADA (Supabase Auth la maneja)

-- 5.1.4 TABLA: places (SIN PostGIS)
CREATE TABLE IF NOT EXISTS places (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    category        TEXT CHECK (category IN (
                        'taller','restaurante','hotel','mirador','moto_posada',
                        'grua','reposteria','evento','otro'
                    )),
    address         VARCHAR(350),
    city            VARCHAR(100),
    department      VARCHAR(100),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    qr_token        VARCHAR(255) UNIQUE NOT NULL,
    created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Índices B-tree (reemplazan GIST)
CREATE INDEX IF NOT EXISTS idx_places_location ON places(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_places_category ON places(category);
CREATE INDEX IF NOT EXISTS idx_places_qr_token ON places(qr_token);
CREATE INDEX IF NOT EXISTS idx_places_city_dept ON places(city, department);

-- 5.1.5 TABLA: visits
CREATE TABLE IF NOT EXISTS visits (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    verified_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    evidence_url    VARCHAR(550),
    is_verified     BOOLEAN DEFAULT FALSE,
    CONSTRAINT uq_user_place_day UNIQUE (user_id, place_id, DATE_TRUNC('day', verified_at))
);

CREATE INDEX IF NOT EXISTS idx_visits_user ON visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_place ON visits(place_id);

-- 5.1.6 TABLA: memberships
CREATE TABLE IF NOT EXISTS memberships (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan            TEXT NOT NULL DEFAULT 'basic'
                    CHECK (plan IN ('basic', 'premium')),
    payment_ref     VARCHAR(255),
    start_date      TIMESTAMPTZ NOT NULL,
    end_date        TIMESTAMPTZ NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships(user_id);

-- 5.1.7 TABLA: allies (CREADA — arregla bug de tabla faltante)
CREATE TABLE IF NOT EXISTS allies (
    id              BIGSERIAL PRIMARY KEY,
    business_name   VARCHAR(255) NOT NULL,
    category        TEXT CHECK (category IN (
                        'taller','restaurante','hotel','mirador','moto_posada',
                        'grua','reposteria','evento','otro'
                    )),
    description     TEXT,
    benefit         TEXT,
    address         VARCHAR(350),
    phone           VARCHAR(50),
    website         VARCHAR(255),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_allies_location ON allies(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_allies_category ON allies(category);

-- 5.1.8 TABLA: challenges
CREATE TABLE IF NOT EXISTS challenges (
    id              BIGSERIAL PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    icon            VARCHAR(50) DEFAULT '🏁',
    ruta            VARCHAR(255),
    sort_order      INT DEFAULT 0
);

-- 5.1.9 TABLA: user_challenges
CREATE TABLE IF NOT EXISTS user_challenges (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    challenge_id    BIGINT NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    completed       BOOLEAN DEFAULT FALSE,
    submitted_at    TIMESTAMPTZ,
    UNIQUE(user_id, challenge_id)
);

-- 5.1.10 TABLA: patches
CREATE TABLE IF NOT EXISTS patches (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    icon            VARCHAR(50) DEFAULT '🏍️',
    place           VARCHAR(255),
    requirement     TEXT
);

-- 5.1.11 TABLA: user_patches
CREATE TABLE IF NOT EXISTS user_patches (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    patch_id        BIGINT NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
    earned          BOOLEAN DEFAULT FALSE,
    earned_at       TIMESTAMPTZ,
    UNIQUE(user_id, patch_id)
);

-- 5.1.12 TABLA: evidence_photos
CREATE TABLE IF NOT EXISTS evidence_photos (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    photo_url       TEXT NOT NULL,  -- Supabase Storage URL
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    accuracy_meters DOUBLE PRECISION,
    verified        BOOLEAN DEFAULT FALSE,
    distance_meters DOUBLE PRECISION,
    points_awarded  INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_evidence_photos_user ON evidence_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_evidence_photos_place ON evidence_photos(place_id);

-- 5.1.13 TABLA: user_points
CREATE TABLE IF NOT EXISTS user_points (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    total_points    INT DEFAULT 0,
    visits_count    INT DEFAULT 0,
    photos_count    INT DEFAULT 0,
    last_visit_at   TIMESTAMPTZ,
    UNIQUE(user_id)
);

-- 5.1.14 TABLA: saved_routes (renombrada de tracks, unifica endpoint mismatch)
CREATE TABLE IF NOT EXISTS saved_routes (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name            VARCHAR(255),
    total_distance_m DOUBLE PRECISION DEFAULT 0,
    duration_seconds INT DEFAULT 0,
    avg_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    max_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    points_count    INT DEFAULT 0,
    polyline_json   TEXT,
    start_lat       DOUBLE PRECISION,
    start_lng       DOUBLE PRECISION,
    end_lat         DOUBLE PRECISION,
    end_lng         DOUBLE PRECISION,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_saved_routes_user ON saved_routes(user_id);

-- 5.1.15 TABLA: road_alerts
CREATE TABLE IF NOT EXISTS road_alerts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    type            VARCHAR(50) NOT NULL,
    title           VARCHAR(255),
    description     TEXT,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    severity        VARCHAR(20) DEFAULT 'info'
                    CHECK (severity IN ('info', 'warning', 'danger')),
    active          BOOLEAN DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    upvotes         INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_road_alerts_location ON road_alerts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_road_alerts_active ON road_alerts(active);

-- 5.1.16 TABLA: user_follows
CREATE TABLE IF NOT EXISTS user_follows (
    id              BIGSERIAL PRIMARY KEY,
    follower_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    followed_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, followed_id),
    CHECK (follower_id != followed_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed ON user_follows(followed_id);

-- 5.1.17 TABLA: chat_messages (NUEVA — reemplaza WebSocket standalone)
CREATE TABLE IF NOT EXISTS chat_messages (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    sender_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_conversation ON chat_messages(conversation_id, created_at);

-- 5.1.18 TABLA: conversation_participants (NUEVA — para RLS de chat)
CREATE TABLE IF NOT EXISTS conversation_participants (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(conversation_id, user_id)
);
```

### 5.2 Función Háversine SQL (reemplaza PostGIS `is_within_distance`)

```sql
-- ============================================================
-- HAVERSINE DISTANCE FUNCTION (SQL pura, sin PostGIS)
-- ============================================================

CREATE OR REPLACE FUNCTION haversine_distance(
    lat1 DOUBLE PRECISION,
    lng1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT 6371000.0 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(lat2 - lat1) / 2), 2)
        + COS(RADIANS(lat1)) * COS(RADIANS(lat2))
        * POWER(SIN(RADIANS(lng2 - lng1) / 2), 2)
    ));
$$;

-- Función de conveniencia: ¿está dentro de N metros?
CREATE OR REPLACE FUNCTION is_within_distance(
    p_lat    DOUBLE PRECISION,
    p_lng    DOUBLE PRECISION,
    q_lat    DOUBLE PRECISION,
    q_lng    DOUBLE PRECISION,
    p_meters DOUBLE PRECISION DEFAULT 100
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT haversine_distance(p_lat, p_lng, q_lat, q_lng) <= p_meters;
$$;
```

### 5.3 Seed Data (migrado, sin PostGIS)

```sql
-- ============================================================
-- SEED DATA (SIN PostGIS)
-- ============================================================

-- Admin user (se crea vía Supabase Auth UI o API)
-- NOTA: La creación de usuarios debe hacerse a través de Supabase Auth
-- para obtener el UUID correcto en auth.users

-- Lugares de prueba (con lat/lng en vez de geom)
INSERT INTO places (name, description, category, address, city, department,
                    latitude, longitude, qr_token, created_by)
VALUES
    ('Taller Moteros Garage',
     'Taller especializado en motos de alta cilindrada',
     'taller', 'Calle 80 #15-20', 'Bogota', 'Cundinamarca',
     4.60971, -74.08175, 'QR-TALLER-MOTEROS-001',
     (SELECT id FROM auth.users WHERE email = 'admin@moteros.com' LIMIT 1)),
    ('Moto-Posada El Viajero',
     'Alojamiento para moteros con parqueadero seguro',
     'moto_posada', 'Km 12 Via La Calera', 'La Calera', 'Cundinamarca',
     4.72076, -73.96932, 'QR-POSADA-VIAJERO-002',
     (SELECT id FROM auth.users WHERE email = 'admin@moteros.com' LIMIT 1)),
    ('Restaurante La Parrilla del Motero',
     'Comida tipica colombiana, parqueadero para motos',
     'restaurante', 'Carrera 7 #72-50', 'Bogota', 'Cundinamarca',
     4.65403, -74.05995, 'QR-REST-PARRILLA-003',
     (SELECT id FROM auth.users WHERE email = 'admin@moteros.com' LIMIT 1)),
    ('Mirador del Cerro',
     'Vista panoramica de Bogota, punto de encuentro motero',
     'mirador', 'Cerro de Monserrate', 'Bogota', 'Cundinamarca',
     4.60534, -74.05535, 'QR-MIRADOR-CERRO-004',
     (SELECT id FROM auth.users WHERE email = 'admin@moteros.com' LIMIT 1)),
    ('Gruas Motero Express',
     'Servicio de grua 24/7 para motos',
     'grua', 'Av. Caracas #45-20', 'Bogota', 'Cundinamarca',
     4.63230, -74.07309, 'QR-GRUA-EXPRESS-005',
     (SELECT id FROM auth.users WHERE email = 'admin@moteros.com' LIMIT 1))
ON CONFLICT (qr_token) DO NOTHING;

-- Aliado de prueba
INSERT INTO allies (business_name, category, description, benefit,
                    address, phone, website, latitude, longitude)
VALUES (
    'Moteros Garage',
    'taller',
    'Taller especializado en motos de alta cilindrada',
    '15% de descuento en mano de obra para miembros',
    'Calle 80 #15-20, Bogota',
    '6015551234',
    'https://moterosgarage.com',
    4.60971,
    -74.08175
);

-- Challenges (10) — sin cambios, no dependen de PostGIS
INSERT INTO challenges (title, description, icon, ruta, sort_order) VALUES
    ('Ruta de la Sabana', 'Visita 2 pueblos de la Sabana de Bogotá en un día', '🏞️', 'Bogotá → Chía → Cajicá → Tabio → Neusa', 1),
    ('Curvas del Alto del Vino', 'Llega al mirador del Alto del Vino y tómate una foto con tu moto', '🏔️', 'Bogotá → Alto del Vino → La Vega', 2),
    ('El Reto del Páramo', 'Sube hasta el Parque Nacional Chingaza en moto', '❄️', 'Bogotá → La Calera → Chingaza', 3),
    ('Ruta Colonial', 'Viaja a Villa de Leyva y visita la Plaza Mayor', '🏛️', 'Bogotá → Tunja → Villa de Leyva', 4),
    ('La Cascada Oculta', 'Encuentra la Cascada La Chorrera en Choachí', '🌊', 'Bogotá → Choachí → La Chorrera', 5),
    ('Ruta Termal', 'Llega a las termales de Paipa y relájate', '♨️', 'Bogotá → Tunja → Paipa', 6),
    ('El Embalse', 'Rodea el Embalse del Neusa en moto', '🌅', 'Bogotá → Zipaquirá → Neusa', 7),
    ('Noche en la Posada', 'Pasa una noche en una Moto Posada del club', '🏠', 'Cualquier Moto Posada afiliada', 8),
    ('Soporte en Ruta', 'Ayuda a otro motero varado en carretera', '🤝', 'En cualquier ruta', 9),
    ('Corona de los Andes', 'Completa todas las rutas del club', '👑', 'Todas las rutas', 10)
ON CONFLICT DO NOTHING;

-- Patches (10) — sin cambios
INSERT INTO patches (name, icon, place, requirement) VALUES
    ('Sabana Explorer', '🏞️', 'Sabana de Bogotá', 'Completa la Ruta de la Sabana'),
    ('Alto del Vino', '🏔️', 'Alto del Vino', 'Llega al mirador del Alto del Vino'),
    ('Páramo Rider', '❄️', 'Chingaza', 'Sube al Parque Chingaza'),
    ('Colonial Master', '🏛️', 'Villa de Leyva', 'Viaja a Villa de Leyva'),
    ('Cascada Legend', '🌊', 'La Chorrera', 'Encuentra la Cascada La Chorrera'),
    ('Termal King', '♨️', 'Paipa', 'Llega a las termales de Paipa'),
    ('Embalse Hero', '🌅', 'Embalse del Neusa', 'Rodea el Embalse del Neusa'),
    ('Moto Posada', '🏠', 'Red de Refugios', 'Pasa la noche en una Moto Posada'),
    ('Ángel Guardián', '🤝', 'Carreteras', 'Ayuda a otro motero en ruta'),
    ('Rey de la Ruta', '👑', 'Todas las rutas', 'Completa todos los parches')
ON CONFLICT DO NOTHING;
```

### 5.4 Notas sobre `users` vs `auth.users`

| Concepto | Supabase Auth | Tabla `users` (custom) |
|---|---|---|
| ID | `auth.users.id` (UUID) | Migrar columna a UUID, 1:1 con auth.users |
| Email | `auth.users.email` | Mantener como referencia |
| Password | Supabase la maneja (bcrypt) | Columna `password_hash` nullable para migración |
| Role | — | Columna `role` para lógica de negocio |
| Profile | `raw_user_meta_data` | Columna `full_name`, `profile_image` |

**Estrategia de migración de usuarios SHA256 → Supabase Auth:**
1. Crear usuarios en Supabase Auth con `supabase.auth.admin.createUser()` (permite override de password)
2. Migrar password hashes usando el Admin API con password hash pre-hasheado (SHA256 → SHA256 con prefijo)
3. O alternativa: forzar reset de password para todos los usuarios existentes

---

## 6. RLS POLICY DESIGN

### Principios generales

- **SELECT**: Usuarios autenticados pueden leer datos públicos y sus propios datos
- **INSERT**: Usuarios autenticados pueden crear sus propios registros
- **UPDATE**: Solo el dueño del registro o admin
- **DELETE**: Solo el dueño del registro o admin
- **Público (sin auth)**: Solo tablas de solo lectura (places, allies, road_alerts)

### 6.1 Tabla: `places`

```sql
-- READ: cualquier usuario autenticado
CREATE POLICY "places_select_auth" ON places
    FOR SELECT USING (auth.role() = 'authenticated');

-- INSERT: solo admin/ally
CREATE POLICY "places_insert_admin" ON places
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'ally'))
    );

-- UPDATE: solo admin
CREATE POLICY "places_update_admin" ON places
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- DELETE: solo admin
CREATE POLICY "places_delete_admin" ON places
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
```

### 6.2 Tabla: `visits`

```sql
-- READ: propia o admin
CREATE POLICY "visits_select_own" ON visits
    FOR SELECT USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- INSERT: propia (Edge Function puede insertar en nombre del usuario)
CREATE POLICY "visits_insert_own" ON visits
    FOR INSERT WITH CHECK (user_id = auth.uid());
```

### 6.3 Tabla: `memberships`

```sql
-- READ: propia o admin
CREATE POLICY "memberships_select_own" ON memberships
    FOR SELECT USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- INSERT: admin (Edge Function o webhook de pago)
CREATE POLICY "memberships_insert_admin" ON memberships
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
```

### 6.4 Tabla: `allies`

```sql
-- READ: cualquier usuario autenticado
CREATE POLICY "allies_select_auth" ON allies
    FOR SELECT USING (auth.role() = 'authenticated');

-- INSERT/UPDATE/DELETE: solo admin
CREATE POLICY "allies_insert_admin" ON allies
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
CREATE POLICY "allies_update_admin" ON allies
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
CREATE POLICY "allies_delete_admin" ON allies
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
```

### 6.5 Tabla: `user_challenges` y `user_patches`

```sql
-- READ/INSERT/UPDATE: propia
CREATE POLICY "user_challenges_own" ON user_challenges
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_patches_own" ON user_patches
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
```

### 6.6 Tabla: `evidence_photos`

```sql
-- READ: propia o admin
CREATE POLICY "evidence_photos_select_own" ON evidence_photos
    FOR SELECT USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- INSERT: propia
CREATE POLICY "evidence_photos_insert_own" ON evidence_photos
    FOR INSERT WITH CHECK (user_id = auth.uid());
```

### 6.7 Tabla: `saved_routes`

```sql
-- READ/INSERT/UPDATE/DELETE: propia
CREATE POLICY "saved_routes_own" ON saved_routes
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
```

### 6.8 Tabla: `road_alerts`

```sql
-- READ: cualquier usuario autenticado (solo activas)
CREATE POLICY "road_alerts_select_active" ON road_alerts
    FOR SELECT USING (
        auth.role() = 'authenticated' AND active = TRUE
    );

-- INSERT: propia
CREATE POLICY "road_alerts_insert_own" ON road_alerts
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- UPDATE/DELETE: propia o admin
CREATE POLICY "road_alerts_update_own" ON road_alerts
    FOR UPDATE USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
CREATE POLICY "road_alerts_delete_own" ON road_alerts
    FOR DELETE USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
```

### 6.9 Tabla: `user_follows`

```sql
-- READ: propia
CREATE POLICY "user_follows_select_own" ON user_follows
    FOR SELECT USING (follower_id = auth.uid());

-- INSERT/UPDATE/DELETE: propia
CREATE POLICY "user_follows_insert_own" ON user_follows
    FOR INSERT WITH CHECK (follower_id = auth.uid());
CREATE POLICY "user_follows_delete_own" ON user_follows
    FOR DELETE USING (follower_id = auth.uid());
```

### 6.10 Tabla: `user_points`

```sql
-- READ: propia o admin
CREATE POLICY "user_points_select_own" ON user_points
    FOR SELECT USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- INSERT/UPDATE: Edge Function o trigger
CREATE POLICY "user_points_insert_admin" ON user_points
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
CREATE POLICY "user_points_update_own" ON user_points
    FOR UPDATE USING (user_id = auth.uid());
```

### 6.11 Tabla: `chat_messages`

```sql
-- READ: solo participantes de la conversación
CREATE POLICY "chat_messages_select_participant" ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversation_participants
            WHERE conversation_id = chat_messages.conversation_id
            AND user_id = auth.uid()
        )
    );

-- INSERT: solo participantes
CREATE POLICY "chat_messages_insert_participant" ON chat_messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM conversation_participants
            WHERE conversation_id = chat_messages.conversation_id
            AND user_id = auth.uid()
        )
    );
```

### 6.12 Tablas de solo catálogo: `challenges`, `patches`

```sql
-- READ: cualquier autenticado
CREATE POLICY "challenges_select_auth" ON challenges
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "patches_select_auth" ON patches
    FOR SELECT USING (auth.role() = 'authenticated');
```

---

## 7. EDGE FUNCTIONS NECESARIAS

Solo 3 funciones, para lógica que RLS no puede manejar:

### 7.1 `POST /validation` — Validación anti-fraude

**Propósito:** Verificar QR token + distancia GPS < 100m + crear visita + actualizar puntos

```typescript
// supabase/functions/validation/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // Obtener usuario autenticado del JWT
  const authHeader = req.headers.get('Authorization')!
  const token = authHeader.replace('Bearer ', '')
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user) return new Response('Unauthorized', { status: 401 })

  const { qr_token, latitude, longitude, evidence_url } = await req.json()

  // 1. Buscar el lugar por QR
  const { data: place, error: placeError } = await supabase
    .from('places')
    .select('id, latitude, longitude, name')
    .eq('qr_token', qr_token)
    .single()

  if (placeError || !place) {
    return new Response(JSON.stringify({ error: 'QR token inválido' }), { status: 404 })
  }

  // 2. Calcular distancia con háversine
  const { data: distance } = await supabase.rpc('haversine_distance', {
    lat1: latitude,
    lng1: longitude,
    lat2: place.latitude,
    lng2: place.longitude,
  })

  if (distance > 100) {
    return new Response(JSON.stringify({ error: 'Demasiado lejos del lugar', distance }), { status: 403 })
  }

  // 3. Verificar duplicado (mismo user + lugar en < 24h)
  const { data: existingVisit } = await supabase
    .from('visits')
    .select('id')
    .eq('user_id', user.id)
    .eq('place_id', place.id)
    .gte('verified_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .maybeSingle()

  if (existingVisit) {
    return new Response(JSON.stringify({ error: 'Ya visitaste este lugar hoy' }), { status: 409 })
  }

  // 4. Insertar visita
  const { data: visit, error: visitError } = await supabase
    .from('visits')
    .insert({
      user_id: user.id,
      place_id: place.id,
      evidence_url,
      is_verified: true,
    })
    .select()
    .single()

  if (visitError) throw visitError

  // 5. Actualizar user_points (UPSERT)
  await supabase.rpc('increment_visit_points', {
    p_user_id: user.id,
  })

  return new Response(JSON.stringify({
    success: true,
    visit,
    place_name: place.name,
    distance_meters: Math.round(distance),
  }), { headers: { 'Content-Type': 'application/json' } })
})
```

**CRON / Trigger para increment_visit_points:**

```sql
CREATE OR REPLACE FUNCTION increment_visit_points(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_points (user_id, total_points, visits_count, last_visit_at)
    VALUES (p_user_id, 10, 1, CURRENT_TIMESTAMP)
    ON CONFLICT (user_id) DO UPDATE SET
        total_points = user_points.total_points + 10,
        visits_count = user_points.visits_count + 1,
        last_visit_at = CURRENT_TIMESTAMP;
END;
$$;
```

### 7.2 `POST /import` — Importación desde Overpass OSM API

**Propósito:** Llamar a Overpass API de OpenStreetMap, mapear tags → categorías, insertar places

```typescript
// supabase/functions/import/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CATEGORY_MAP: Record<string, string> = {
  'motorcycle=repair': 'taller',
  'shop=motorcycle_repair': 'taller',
  'amenity=restaurant': 'restaurante',
  'amenity=hotel': 'hotel',
  'tourism=hotel': 'hotel',
  'tourism=viewpoint': 'mirador',
  'highway=rest_area': 'moto_posada',
  'amenity=fast_food': 'restaurante',
  'shop= pastry': 'reposteria',
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { department, city } = await req.json()
  
  // Construir query Overpass
  const overpassQuery = `[out:json];area["name"="${department}"];node(area)[~"^(amenity|shop|tourism|motorcycle)$"~"."](if: number(t["lat"]) > 0);out center;`
  
  const overpassResp = await fetch('https://overpass-api.de/api/interpreter', {
    method: 'POST',
    body: `data=${encodeURIComponent(overpassQuery)}`,
  })
  
  const data = await overpassResp.json()
  
  const places = data.elements
    .filter((el: any) => el.lat && el.lon)
    .map((el: any) => {
      const tagKey = Object.keys(CATEGORY_MAP).find(k => {
        const [key, val] = k.split('=')
        return el.tags?.[key] === val
      })
      return {
        name: el.tags?.name || el.tags?.operator || `Lugar ${el.id}`,
        description: el.tags?.description || '',
        category: tagKey ? CATEGORY_MAP[tagKey] : 'otro',
        address: [el.tags?.['addr:street'], el.tags?.['addr:housenumber']].filter(Boolean).join(' '),
        city: city || el.tags?.['addr:city'] || '',
        department: department,
        latitude: el.lat,
        longitude: el.lon,
        qr_token: `QR-OSM-${el.id}-${Date.now()}`,
      }
    })

  // Insertar en batch
  const { data: inserted, error } = await supabase
    .from('places')
    .upsert(places, { onConflict: 'qr_token', ignoreDuplicates: true })
    .select()

  return new Response(JSON.stringify({ imported: inserted?.length || 0, total: places.length }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

### 7.3 `GET /dashboard` — Agregación multi-tabla

**Propósito:** Reemplazar el endpoint `/dashboard` de Dart Frog que agrega datos de múltiples tablas

```typescript
// supabase/functions/dashboard/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
  )

  const authHeader = req.headers.get('Authorization')!
  const token = authHeader.replace('Bearer ', '')
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user) return new Response('Unauthorized', { status: 401 })

  const [
    { data: profile },
    { count: placesVisited },
    { count: totalPlaces },
    { data: challenges },
    { data: membership },
    { data: points },
  ] = await Promise.all([
    supabase.from('users').select('email, full_name, role').eq('id', user.id).single(),
    supabase.from('visits').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
    supabase.from('places').select('*', { count: 'exact', head: true }),
    supabase.from('user_challenges').select('challenge_id, completed'),
    supabase.from('memberships').select('plan, end_date').eq('user_id', user.id).eq('is_active', true).maybeSingle(),
    supabase.from('user_points').select('total_points, visits_count').eq('user_id', user.id).maybeSingle(),
  ])

  return new Response(JSON.stringify({
    email: profile?.email,
    fullName: profile?.full_name,
    role: profile?.role,
    placesVisited: placesVisited || 0,
    totalPlaces: totalPlaces || 0,
    challengesCompleted: challenges?.filter(c => c.completed).length || 0,
    totalChallenges: challenges?.length || 0,
    membershipPlan: membership?.plan || null,
    membershipDaysLeft: membership?.end_date
      ? Math.max(0, Math.floor((new Date(membership.end_date).getTime() - Date.now()) / 86400000))
      : null,
    totalPoints: points?.total_points || 0,
    visitsCount: points?.visits_count || 0,
  }), { headers: { 'Content-Type': 'application/json' } })
})
```

### 7.4 Resumen: endpoints Dart Frog → destino

| Endpoint | Método | Auth | Destino |
|---|---|---|---|
| `/` | GET | No | ❌ Eliminar (no necesario) |
| `/auth/login` | POST | No | Supabase Auth `signInWithPassword()` |
| `/auth/register` | POST | No | Supabase Auth `signUp()` |
| `/auth/google` | POST | No | Supabase Auth `signInWithOAuth('google')` |
| `/auth/refresh` | POST | No | Supabase Auth `refreshSession()` |
| `/places` | GET | No | Consulta RLS directa con `haversine_distance()` |
| `/places/:id` | GET | No | Consulta RLS directa `SELECT * FROM places WHERE id = :id` |
| `/validation` | POST | ✅ | **Edge Function** (lógica anti-fraude) |
| `/visits` | GET | Manual | Consulta RLS directa |
| `/visits` | POST | Manual | Consulta RLS directa |
| `/memberships` | GET | ✅ | Consulta RLS directa |
| `/memberships` | POST | ✅ | Consulta RLS directa |
| `/admin/allies` | GET | ✅ | Consulta RLS directa |
| `/admin/allies` | POST | ✅ | Consulta RLS directa |
| `/dashboard` | GET | Manual | **Edge Function** (agregación) |
| `/tracks` (backend) / `/routes` (Flutter) | GET/POST | Manual | Consulta RLS directa sobre `saved_routes` |
| `/challenges` | GET/POST | Manual | Consulta RLS directa |
| `/patches` | GET | Manual | Consulta RLS directa |
| `/alerts` | GET/POST | Manual | Consulta RLS directa |
| `/follows` | GET/POST/DELETE | Manual | Consulta RLS directa |
| `/refugios` | GET | No | Consulta RLS directa sobre `allies` |
| `/import` | POST | No | **Edge Function** (Overpass OSM) |
| `/import/manual` | POST | Manual | Consulta RLS directa |

---

## 8. REALTIME (CHAT)

### 8.1 Modelo de datos

| Tabla | Propósito |
|---|---|
| `chat_messages` | Almacenamiento persistente de mensajes |
| `conversation_participants` | Control de acceso por conversación |

### 8.2 Configuración Realtime

```sql
-- Habilitar Realtime para la tabla chat_messages
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
```

### 8.3 Broadcast de mensajes

Cuando un participante inserta un mensaje en `chat_messages`, Supabase Realtime hace broadcast automático a todos los suscriptores del canal:

```dart
// Flutter — suscripción al canal de chat
final channel = supabase.channel('chat:${conversationId}');

channel
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'chat_messages',
    filter: PostgresChangeFilter(type: 'eq', column: 'conversation_id', value: conversationId),
    callback: (payload) {
      // Emitir evento al ChatBloc
      chatBloc.add(ChatMessageReceived(payload.newMessage));
    },
  )
  .subscribe();

// Enviar mensaje
await supabase.from('chat_messages').insert({
  conversation_id: conversationId,
  sender_id: user.id,
  message: text,
});
```

### 8.4 Flujo

```
Usuario A escribe mensaje
        │
        ▼
supabase.from('chat_messages').insert(...)
        │
        ├── RLS verifica: ¿Usuario A es participante?
        │
        ├── INSERT exitoso → Realtime broadcast a canal
        │
        └── Usuario B recibe evento en tiempo real
```

---

## 9. STORAGE

### 9.1 Buckets

| Bucket | Público | Tamaño máx. | Tipos permitidos |
|---|---|---|---|
| `place-photos` | ✅ Público (lectura) | 5 MB | image/jpeg, image/png, image/webp |
| `evidence-photos` | ❌ Privado (solo dueño + admin) | 10 MB | image/jpeg, image/png |
| `profile-images` | ✅ Público (lectura) | 2 MB | image/jpeg, image/png, image/webp |

### 9.2 RLS Policies para Storage

```sql
-- BUCKET: place-photos
-- READ: cualquier usuario autenticado
CREATE POLICY "place_photos_select" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'place-photos' AND auth.role() = 'authenticated'
    );

-- INSERT: solo admin/ally
CREATE POLICY "place_photos_insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'place-photos'
        AND auth.role() = 'authenticated'
        AND EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'ally'))
    );

-- BUCKET: evidence-photos
-- READ: solo el dueño o admin
CREATE POLICY "evidence_photos_select" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'evidence-photos'
        AND (auth.uid() = owner OR EXISTS (
            SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
        ))
    );

-- INSERT: propio
CREATE POLICY "evidence_photos_insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'evidence-photos'
        AND auth.uid() = owner
    );

-- BUCKET: profile-images
-- READ: cualquier autenticado
CREATE POLICY "profile_images_select" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'profile-images' AND auth.role() = 'authenticated'
    );

-- INSERT: propio
CREATE POLICY "profile_images_insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-images' AND auth.uid() = owner
    );
```

### 9.3 Upload desde Flutter

```dart
// Ejemplo: subir foto de evidencia
final file = File(photoPath);
final bytes = await file.readAsBytes();
final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

final response = await supabase.storage
    .from('evidence-photos')
    .upload(fileName, bytes, fileOptions: FileOptions(
      contentType: 'image/jpeg',
      upsert: false,
    ));

final publicUrl = supabase.storage.from('evidence-photos').getPublicUrl(fileName);
```

---

## 10. FLUTTER CHANGES

### 10.1 Dependencias

```yaml
# pubspec.yaml — DESPUÉS de la migración
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # SUPABASE (NUEVO)
  supabase_flutter: ^2.8.0          # ← NUEVO: reemplaza Dio + Firebase + flutter_secure_storage + websocket

  # MANTENIDO (no dependen del backend)
  flutter_bloc: ^9.1.1
  equatable: ^2.0.8
  mobile_scanner: ^7.2.0            # QR scanner nativo
  flutter_map: ^8.3.1               # Mapa OSM cliente-side
  flutter_map_marker_cluster: ^8.2.2
  geolocator: ^14.0.3               # GPS nativo
  latlong2: ^0.9.1
  image_picker: ^1.2.3              # Cámara local
  url_launcher: ^6.3.0
  provider: ^6.1.2

# ELIMINADOS:
#   dio: ^5.7.0                     → Reemplazado por supabase_flutter
#   flutter_secure_storage: ^10.3.1 → Reemplazado por supabase_flutter session
#   cloudinary_flutter: ^1.3.0      → Eliminado (nunca implementado)
#   firebase_core: ^4.11.0          → Eliminado
#   firebase_auth: ^6.5.4           → Eliminado
#   google_sign_in: ^7.2.0          → Eliminado
#   web_socket_channel: ^3.0.2      → Reemplazado por supabase.realtime
```

### 10.2 Inicialización

```dart
// main.dart — ANTES
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MoterosApp());
}

// main.dart — DESPUÉS
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xyz.supabase.co',
    anonKey: 'public-anon-key',
  );
  runApp(MoterosApp());
}
```

### 10.3 Reemplazo de capa de datos (Datasources)

```dart
// ANTES: AuthRemoteDataSource con Dio
class AuthRemoteDataSource {
  final ApiClient _client;

  Future<AuthModel> login(String email, String password) async {
    final response = await _client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    return AuthModel.fromJson(response.data);
  }
}

// DESPUÉS: AuthRemoteDataSource con Supabase
class AuthRemoteDataSource {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  Future<AuthResponse> login(String email, String password) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> register(String email, String password, String fullName) async {
    final response = await _auth.signUp(email: email, password: password, data: {
      'full_name': fullName,
    });
    // Crear perfil en tabla users
    if (response.user != null) {
      await Supabase.instance.client.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
        'role': 'aspirant',
      });
    }
    return response;
  }

  Future<AuthResponse> signInWithGoogle() async {
    return await _auth.signInWithOAuth(OAuthProvider.google);
  }
}
```

```dart
// ANTES: PlaceRemoteDataSource con Dio
class PlaceRemoteDataSource {
  final ApiClient _client;

  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng, double radius) async {
    final response = await _client.get('/places', queryParams: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
    });
    return (response.data as List).map((j) => PlaceModel.fromJson(j)).toList();
  }
}

// DESPUÉS: PlaceRemoteDataSource con Supabase (consulta directa con háversine)
class PlaceRemoteDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng, {double radius = 5000}) async {
    // Usar la función háversine en SQL via RPC
    final response = await _client.rpc('get_places_nearby', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_meters': radius,
    });
    return (response as List).map((j) => PlaceModel.fromJson(j)).toList();
  }

  Future<PlaceModel> getPlace(int id) async {
    final response = await _client
        .from('places')
        .select()
        .eq('id', id)
        .single();
    return PlaceModel.fromJson(response);
  }
}
```

### 10.4 Función SQL auxiliar para búsqueda de proximidad

```sql
CREATE OR REPLACE FUNCTION get_places_nearby(
    p_lat           DOUBLE PRECISION,
    p_lng           DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 5000,
    p_limit         INT DEFAULT 50
) RETURNS TABLE(
    id              BIGINT,
    name            VARCHAR,
    description     TEXT,
    category        TEXT,
    address         VARCHAR,
    city            VARCHAR,
    department      VARCHAR,
    latitude        DOUBLE PRECISION,
    longitude       DOUBLE PRECISION,
    qr_token        VARCHAR,
    distance_meters DOUBLE PRECISION
)
LANGUAGE sql STABLE
AS $$
    SELECT
        p.id,
        p.name,
        p.description,
        p.category,
        p.address,
        p.city,
        p.department,
        p.latitude,
        p.longitude,
        p.qr_token,
        haversine_distance(p_lat, p_lng, p.latitude, p.longitude) AS distance_meters
    FROM places p
    WHERE haversine_distance(p_lat, p_lng, p.latitude, p.longitude) <= p_radius_meters
    ORDER BY distance_meters ASC
    LIMIT p_limit;
$$;
```

### 10.5 Reemplazo de ApiClient + AuthInterceptor (eliminación completa)

```dart
// 🗑️ ELIMINAR: lib/core/network/api_client.dart
// 🗑️ ELIMINAR: lib/core/network/token_storage.dart
// 🗑️ ELIMINAR: lib/core/network/auth_interceptor.dart

// Estos archivos ya no son necesarios. Todo se maneja vía SupabaseClient.
// Los BLoCs deben inyectar SupabaseClient directamente o un wrapper thin.
```

### 10.6 ChatBloc — Reemplazo de WebSocket por Realtime

```dart
// ANTES: web_socket_channel
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  WebSocketChannel? _channel;

  void _connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.101.5:8082/ws?room=$conversationId&user=$userId'),
    );
    _channel!.stream.listen((message) {
      add(ChatMessageReceived(ChatMessage.fromJson(jsonDecode(message))));
    });
  }
}

// DESPUÉS: Supabase Realtime
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  RealtimeChannel? _channel;

  void _connect() {
    _channel = supabase.channel('chat:$conversationId');
    _channel!
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: 'eq', column: 'conversation_id', value: conversationId,
        ),
        callback: (payload) {
          add(ChatMessageReceived(ChatMessage.fromJson(payload.newRecord)));
        },
      )
      .subscribe();
  }

  Future<void> _sendMessage(String text) async {
    await supabase.from('chat_messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
```

---

## 11. ORDEN DE IMPLEMENTACIÓN

### Fase 1: Fundación Supabase (Día 1-3)

| Paso | Acción | Archivos/Dependencias |
|---|---|---|
| 1.1 | Crear proyecto Supabase en dashboard.supabase.com | Proyecto nuevo |
| 1.2 | Ejecutar schema SQL completo (sección 5.1) | SQL Editor |
| 1.3 | Crear función háversine + `get_places_nearby` (secciones 5.2, 10.4) | SQL Editor |
| 1.4 | Crear función `increment_visit_points` (sección 7.1) | SQL Editor |
| 1.5 | Ejecutar seed data (sección 5.3) | SQL Editor |
| 1.6 | Configurar RLS policies (sección 6) | SQL Editor |
| 1.7 | Habilitar Realtime para tabla `chat_messages` (sección 8.2) | SQL Editor |
| 1.8 | Crear Storage buckets (sección 9.1) | Supabase Dashboard |

### Fase 2: Autenticación (Día 4-5)

| Paso | Acción | Archivos |
|---|---|---|
| 2.1 | Configurar Google OAuth en Supabase Auth | Supabase Dashboard |
| 2.2 | Configurar Site URL y redirects | Supabase Dashboard |
| 2.3 | Migrar usuarios existentes (SHA256 → Supabase Auth) | Script one-off |
| 2.4 | Implementar `AuthRemoteDataSource` con Supabase Auth | `auth_remote_datasource.dart` |
| 2.5 | Ajustar `AuthBloc` para usar nuevo datasource | `auth_bloc.dart` |
| 2.6 | Eliminar `TokenStorage` y `AuthInterceptor` | Eliminar archivos |

### Fase 3: Storage (Día 6)

| Paso | Acción |
|---|---|
| 3.1 | Implementar upload de fotos a Supabase Storage en `EvidenceScreen` |
| 3.2 | Implementar upload de foto de perfil en `ProfileScreen` |
| 3.3 | Implementar upload de fotos de lugares (admin) |

### Fase 4: Edge Functions (Día 7-9)

| Paso | Acción |
|---|---|
| 4.1 | Crear `supabase/functions/validation/index.ts` |
| 4.2 | Desplegar con `supabase functions deploy validation` |
| 4.3 | Crear `supabase/functions/dashboard/index.ts` |
| 4.4 | Desplegar con `supabase functions deploy dashboard` |
| 4.5 | Crear `supabase/functions/import/index.ts` |
| 4.6 | Desplegar con `supabase functions deploy import` |

### Fase 5: Realtime (Día 10)

| Paso | Acción |
|---|---|
| 5.1 | Implementar `ChatRemoteDataSource` con Supabase Realtime |
| 5.2 | Modificar `ChatBloc` para usar Realtime en vez de `web_socket_channel` |
| 5.3 | Eliminar `ws_server.dart` y `chat_hub.dart` del backend |

### Fase 6: Datasources Flutter (Día 11-13)

| Paso | Acción | Datasource a modificar |
|---|---|---|
| 6.1 | `PlaceRemoteDataSource`: reemplazar Dio → `supabase.rpc('get_places_nearby')` | `place_remote_datasource.dart` |
| 6.2 | `ValidationRemoteDataSource`: apuntar a Edge Function | `validation_remote_datasource.dart` |
| 6.3 | `ScanBloc._confirm()`: apuntar a Supabase `evidence_photos` + `visits` | `scan_bloc.dart` |
| 6.4 | `MembershipRemoteDataSource`: consulta directa RLS | `membership_remote_datasource.dart` |
| 6.5 | `DashboardBloc`: apuntar a Edge Function | `dashboard_bloc.dart` |
| 6.6 | `AdminRemoteDataSource`: consulta directa RLS | `admin_remote_datasource.dart` |
| 6.7 | `ChallengesBloc`: consulta directa RLS | `challenges_bloc.dart` |
| 6.8 | `PatchesBloc`: consulta directa RLS | `patches_bloc.dart` |
| 6.9 | `TrackerBloc`: consulta directa RLS sobre `saved_routes` | `tracker_bloc.dart` (fix `/routes` → tabla `saved_routes`) |
| 6.10 | `RefugiosBloc`: reemplazar mock por consulta RLS sobre `allies` | `refugios_bloc.dart` (fix bug) |

### Fase 7: Limpieza (Día 14)

| Paso | Acción |
|---|---|
| 7.1 | Eliminar `dio`, `firebase_core`, `firebase_auth`, `google_sign_in`, `cloudinary_flutter`, `web_socket_channel`, `flutter_secure_storage` de pubspec.yaml |
| 7.2 | Eliminar archivos: `api_client.dart`, `token_storage.dart`, `auth_interceptor.dart` |
| 7.3 | Eliminar todo el backend Dart Frog (`backend/`) |
| 7.4 | Eliminar `ws_server.dart` y `chat_hub.dart` |
| 7.5 | Eliminar `firebase_options.dart` si existe |
| 7.6 | Ejecutar `flutter pub get` y verificar que compile |
| 7.7 | Ejecutar `flutter analyze` — 0 errores |

---

## 12. RIESGOS Y MITIGACIONES

### 🔴 Riesgo Alto: Migración de usuarios existentes (SHA256 → Supabase Auth)

| Riesgo | Los usuarios existentes tienen passwords hasheados con SHA256. Supabase Auth usa bcrypt. No se puede migrar directamente. |
|---|---|
| **Mitigación A** | Usar Admin API de Supabase con `password_hash` opción (requiere formato específico: `$SHA256$salt$hash`) |
| **Mitigación B** | Forzar reset de password para todos los usuarios existentes vía email (más simple, peor UX) |
| **Mitigación C** | Migración progresiva: mantener users.password_hash como nullable, crear usuarios en Supabase Auth con placeholder, y al primer login migrar password real |
| **Recomendación** | Opción A si se puede reconstruir el hash SHA256. Opción C si se prefiere menor riesgo. |

### 🔴 Riesgo Alto: Data loss en migración de `places.geom`

| Riesgo | Al migrar de `places.geom` (GEOMETRY) a `places.latitude + longitude`, se necesita extraer ST_Y(geom) y ST_X(geom) correctamente |
|---|---|
| **Mitigación** | Ejecutar script SQL de extracción antes de eliminar PostGIS: |
```sql
-- Extraer lat/lng de geom antes de migrar
ALTER TABLE places ADD COLUMN latitude DOUBLE PRECISION;
ALTER TABLE places ADD COLUMN longitude DOUBLE PRECISION;
UPDATE places SET
    latitude = ST_Y(geom),
    longitude = ST_X(geom);
-- Verificar que no hay NULLs
SELECT COUNT(*) FROM places WHERE latitude IS NULL OR longitude IS NULL;
-- Luego eliminar columna geom y recrear índices
```

### 🟡 Riesgo Medio: Performance de háversine vs PostGIS GIST

| Riesgo | La función háversine SQL no puede usar índices B-tree para filtrar por distancia. Cada query scannea todas las filas y calcula distancia. Con 50k+ places, puede ser lento. |
|---|---|
| **Mitigación** | Usar pre-filtro por bounding box aproximado (lat ± grados, lng ± grados) que SÍ usa índice B-tree, y luego háversine para precisión: |
```sql
CREATE OR REPLACE FUNCTION get_places_nearby(
    p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 5000,
    p_limit INT DEFAULT 50
)
RETURNS TABLE(...) AS $$
    -- Pre-filtro por bounding box para usar índice B-tree
    SELECT ... FROM places p
    WHERE p.latitude BETWEEN p_lat - (p_radius_meters / 111320.0)
                         AND p_lat + (p_radius_meters / 111320.0)
      AND p.longitude BETWEEN p_lng - (p_radius_meters / (111320.0 * COS(RADIANS(p_lat))))
                           AND p_lng + (p_radius_meters / (111320.0 * COS(RADIANS(p_lat))))
      AND haversine_distance(p_lat, p_lng, p.latitude, p.longitude) <= p_radius_meters
    ORDER BY haversine_distance(p_lat, p_lng, p.latitude, p.longitude)
    LIMIT p_limit;
$$ LANGUAGE sql STABLE;
```

### 🟡 Riesgo Medio: Overpass API sigue siendo externa

| Riesgo | El endpoint `/import` depende de Overpass API de OSM, que es externa a Supabase. Esto no cambia con la migración, pero la Edge Function hereda esta dependencia externa. |
|---|---|
| **Mitigación** | Implementar timeout en Edge Function (Overpass puede ser lento). Cachear resultados. Considerar cola de trabajos (queue) para imports masivos. |

### 🟢 Riesgo Bajo: Edge Functions cold start

| Riesgo | Las Edge Functions de Deno tienen cold start (~500ms-1s) que afecta la latencia de `/validation` (crítico en flujo de QR scanning) |
|---|---|
| **Mitigación** | Mantener función siempre activa (hit periódico), o usar Supabase DB function + RLS tanto como sea posible. La validación podría dividirse: RLS para verificar QR token, Edge Function solo para lógica anti-fraude compleja. |

### 🟢 Riesgo Bajo: Chat existente pierde historial

| Riesgo | El chat actual no tiene persistencia, no hay historial que migrar. ✅ Sin riesgo real. |
|---|---|
| **Mitigación** | N/A — no hay datos que perder |

---

## APÉNDICE A: Resumen de cambios por archivo

### Archivos a ELIMINAR

| Archivo | Razón |
|---|---|
| `backend/` (todo el directorio) | Reemplazado por Supabase |
| `backend/ws_server.dart` | Reemplazado por Supabase Realtime |
| `backend/lib/chat_hub.dart` | Reemplazado por Supabase Realtime |
| `backend/lib/auth.dart` | Reemplazado por Supabase Auth |
| `backend/lib/database.dart` | Reemplazado por SupabaseClient |
| `lib/core/network/api_client.dart` | Reemplazado por SupabaseClient |
| `lib/core/network/token_storage.dart` | Reemplazado por Supabase session |
| `lib/core/network/auth_interceptor.dart` | Reemplazado por SupabaseClient built-in |
| `firebase_options.dart` (si existe) | Firebase eliminado |

### Archivos a MODIFICAR

| Archivo | Cambio |
|---|---|
| `pubspec.yaml` | Agregar `supabase_flutter`, eliminar 7 dependencias |
| `lib/main.dart` | Inicializar `Supabase.initialize()` en lugar de `Firebase.initializeApp()` |
| `lib/features/auth/.../auth_remote_datasource.dart` | Reemplazar Dio por Supabase Auth |
| `lib/features/auth/.../auth_bloc.dart` | Ajustar para nuevo datasource |
| `lib/features/places/.../place_remote_datasource.dart` | Reemplazar Dio por RPC `get_places_nearby` |
| `lib/features/validation/.../validation_remote_datasource.dart` | Apuntar a Edge Function |
| `lib/features/verification/.../scan_bloc.dart` | Reemplazar Dio por Supabase |
| `lib/features/membership/.../membership_remote_datasource.dart` | Reemplazar Dio por consulta RLS |
| `lib/features/dashboard/.../dashboard_bloc.dart` | Apuntar a Edge Function |
| `lib/features/admin/.../admin_remote_datasource.dart` | Reemplazar Dio por consulta RLS |
| `lib/features/challenges/.../challenges_bloc.dart` | Reemplazar Dio por consulta RLS |
| `lib/features/patches/.../patches_bloc.dart` | Reemplazar Dio por consulta RLS |
| `lib/features/tracker/.../tracker_bloc.dart` | Reemplazar Dio + fix endpoint mismatch |
| `lib/features/chat/.../chat_bloc.dart` | Reemplazar `web_socket_channel` por Supabase Realtime |
| `lib/features/refugios/.../refugios_bloc.dart` | Reemplazar datos mock por consulta RLS |

### Archivos NUEVOS

| Archivo | Propósito |
|---|---|
| `supabase/functions/validation/index.ts` | Edge Function: validación anti-fraude |
| `supabase/functions/dashboard/index.ts` | Edge Function: agregación dashboard |
| `supabase/functions/import/index.ts` | Edge Function: import Overpass OSM |
| `supabase/migrations/001_full_schema.sql` | Schema completo (sin PostGIS) |
| `supabase/migrations/002_seed_data.sql` | Seed data migrado |

---

> **Documento generado por:** Hermes Agent (Nous Research)  
> **Basado en:** `SUPABASE_MIGRATION_REPORT.md` + `OPENSPEC.md` + migraciones SQL existentes  
> **Próximo paso:** Revisar y aprobar → Fase de Spec detallada por feature → Design → Tasks  
