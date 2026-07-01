# OPENSPEC — Plataforma Socio-Digital para Moteros

**Definición canónica del sistema.** Describe *qué* es, *por qué* existe, *cómo* funciona y *con qué* se construye. Fuente única de verdad técnica para el proyecto `moteros_app`.

---

## 1. Definición del Sistema

### Propósito

Plataforma móvil multiplataforma exclusiva para la comunidad motera en Colombia que:
- Fomente la **exploración de rutas y lugares de interés**.
- Centralice **recomendaciones curadas y confiables** (talleres, restaurantes, moto-posadas).
- Genere **pertenencia** mediante un modelo de membresía.
- **Gamifique** la experiencia de viaje mediante validación física de destinos (QR + Geolocalización + Evidencias).

### Problema que Resuelve

| Problema | Solución |
|---|---|
| **Dispersión** de información y rutas en grupos de redes sociales | Plataforma centralizada con contenido curado |
| **Falta de confianza** en reseñas de vías, talleres o alojamientos | Validación física de visitas (doble factor: QR + GPS) |
| **Ausencia de incentivos** para el motero viajero | Gamificación con logros y validación de rutas |

### Usuarios Objetivo

| Rol | Descripción |
|---|---|
| **Aspirante** (`aspirant`) | Usuario que desea ingresar a la comunidad y debe cumplir retos de ruta |
| **Miembro** (`member`) | Motero activo con suscripción, acceso a beneficios premium y contenido exclusivo |
| **Aliado** (`ally`) | Comercio (taller, grúa, hotel, restaurante) que ofrece beneficios a los miembros |
| **Administrador** (`admin`) | Moderador de contenido, retos y validación de membresías |

---

## 2. Enfoque Sistémico

```
       [ ENTRADAS ]                  [ PROCESOS ]                  [ SALIDAS ]
 ┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐
 │ • Registro/Pagos     │      │ • Validación de QR   │      │ • Rutas Desbloqueadas│
 │ • Coordenadas GPS    │ ───> │ • Filtros Geo (GIS)  │ ───> │ • Descuentos Aliados │
 │ • Fotos de Evidencia │      │ • Control de Estados │      │ • Perfil / Logros    │
 └──────────────────────┘      └──────────────────────┘      └──────────────────────┘
            ▲                                                           │
            │                      [ RETROALIMENTACIÓN ]                │
            └───────────────────────────────────────────────────────────┘
                             • Métricas de ruta y feedback de usuarios
```

### Límites del Sistema

- **Incluye**: Aplicación móvil (iOS/Android), panel administrativo (Flutter Web), backend (API REST Dart Frog), base de datos relacional/geográfica (PostgreSQL + PostGIS).
- **Excluye**: Procesamiento nativo de pasarelas de pago (delegado a agregadores externos: MercadoPago/PayU). Infraestructura de mapas base (consumidos de proveedores externos: Google Maps/OpenStreetMap).

---

## 3. Stack Tecnológico

| Capa | Tecnología | Justificación |
|---|---|---|
| **Frontend Móvil** | Flutter 3.44.4 / Dart 3.12.2 | Multiplataforma, single codebase iOS + Android |
| **Frontend Web (Admin)** | Flutter Web | Reutilización de widgets, modelos y lógica compartida |
| **Backend** | Dart Frog / Shelf | Unificación del lenguaje Dart (cliente + servidor), modelos compartidos, entorno asíncrono de alto rendimiento |
| **Base de Datos** | PostgreSQL 15 + PostGIS | Soporte geoespacial nativo (índices GIST), Dockerizado para portabilidad |
| **Almacenamiento de Archivos** | Cloudinary (producción) / MinIO (desarrollo local) | Evidencias fotográficas, assets de perfil |

### Dependencias Clave del Proyecto

```yaml
# pubspec.yaml — estado actual
dependencies:
  dio: ^5.7.0           # Cliente HTTP (Dart Frog backend)
  flutter_bloc: ^9.0.0  # Gestión de estado (pendiente de instalación)

dev_dependencies:
  flutter_test: SDK     # Tests unitarios y de widget
  flutter_lints: ^6.0.0 # Linter estándar Flutter
```

### Dependencias Planificadas

| Paquete | Propósito | Feature |
|---|---|---|
| `google_maps_flutter` | Mapa interactivo | places |
| `mobile_scanner` | Escaneo de códigos QR | validation |
| `flutter_secure_storage` | Almacenamiento seguro de tokens JWT | auth |
| `image_picker` | Captura de fotos de evidencia | validation |
| `geolocator` | Obtención de coordenadas GPS del dispositivo | places, validation |

---

## 4. Arquitectura de Software

### 4.1 Clean Architecture por Features

```
lib/
├── main.dart                         # Punto de entrada
├── app.dart                          # Configuración de MaterialApp
├── core/                             # Código compartido transversal
│   ├── network/
│   │   └── api_client.dart           # Cliente Dio con interceptores, baseUrl, auth token
│   └── theme/
│       └── app_theme.dart            # Tema Material 3 (dark + light)
└── features/                         # Módulos funcionales independientes
    ├── auth/                         # Autenticación y registro
    │   ├── domain/
    │   │   ├── entities/user_entity.dart
    │   │   └── usecases/login_usecase.dart
    │   ├── data/
    │   │   ├── datasources/auth_remote_datasource.dart
    │   │   └── models/auth_model.dart
    │   └── presentation/
    │       ├── bloc/auth_bloc.dart
    │       └── screens/login_screen.dart
    ├── places/                       # Lugares, rutas y mapa
    │   ├── domain/
    │   │   ├── entities/place_entity.dart
    │   │   └── usecases/get_nearby_places.dart
    │   ├── data/
    │   │   ├── datasources/place_remote_datasource.dart
    │   │   └── models/place_model.dart
    │   └── presentation/
    │       ├── bloc/places_bloc.dart
    │       └── screens/map_explorer_screen.dart
    ├── validation/                   # Validación de visitas (QR + GPS)
    │   ├── domain/
    │   │   ├── entities/visit_entity.dart
    │   │   └── usecases/validate_visit.dart
    │   ├── data/
    │   │   ├── datasources/validation_remote_datasource.dart
    │   │   └── models/visit_model.dart
    │   └── presentation/
    │       ├── bloc/validation_bloc.dart
    │       └── screens/qr_scanner_screen.dart
    ├── membership/                   # Membresías y pagos
    │   ├── domain/
    │   │   ├── entities/membership_entity.dart
    │   │   └── usecases/activate_membership.dart
    │   ├── data/
    │   │   ├── datasources/membership_remote_datasource.dart
    │   │   └── models/membership_model.dart
    │   └── presentation/
    │       ├── bloc/membership_bloc.dart
    │       └── screens/membership_screen.dart
    └── admin/                        # Panel de administración
        ├── domain/
        │   ├── entities/ally_entity.dart
        │   └── usecases/manage_allies.dart
        ├── data/
        │   ├── datasources/admin_remote_datasource.dart
        │   └── models/ally_model.dart
        └── presentation/
            ├── bloc/admin_bloc.dart
            └── screens/admin_panel_screen.dart
```

### 4.2 Convención de Capas

| Capa | Responsabilidad | Dependencias |
|---|---|---|
| **domain/** | Entidades puras de Dart, casos de uso (lógica de negocio) | Ninguna (independiente de frameworks) |
| **data/** | Implementación de datasources, modelos con serialización JSON | Depende de `domain` |
| **presentation/** | UI Flutter, BLoCs, pantallas | Depende de `domain` y `data` |

**Regla**: `domain` no conoce a `data` ni a `presentation`. `data` implementa contratos definidos en `domain`.

### 4.3 Patrón de Estado: BLoC

- Un BLoC por feature.
- Eventos de entrada (`Event`) → BLoC procesa → Estados de salida (`State`).
- UI reacciona a estados mediante `BlocBuilder` / `BlocListener`.
- Paquete requerido: `flutter_bloc` (PENDIENTE de instalación en `pubspec.yaml`).

---

## 5. Backend — Dart Frog

### 5.1 Rutas de API

| Ruta | Método | Propósito | Feature |
|---|---|---|---|
| `/auth/login` | POST | Autenticación con email/password, retorna JWT + Refresh Token | auth |
| `/auth/register` | POST | Registro de nuevo usuario | auth |
| `/auth/refresh` | POST | Renovación de token JWT expirado | auth |
| `/places` | GET | Consulta de lugares cercanos (params: `lat`, `lng`, `radius`) | places |
| `/places/:id` | GET | Detalle de un lugar específico | places |
| `/validation` | POST | Validación de visita (body: `qr_token`, `latitude`, `longitude`, `evidence_url`) | validation |
| `/memberships` | POST | Webhook de activación tras pago exitoso en pasarela externa | membership |
| `/admin/allies` | GET | Listado de aliados comerciales | admin |
| `/admin/allies` | POST | Crear nuevo aliado | admin |

### 5.2 Autenticación y Seguridad

- **JWT**: Bearer Tokens con expiración de 15 minutos.
- **Refresh Tokens**: Almacenamiento seguro en dispositivo vía `flutter_secure_storage`.
- **Rate Limiting**: Middleware de límite de peticiones por IP/token.
- **HTTPS**: Obligatorio en producción, cifrado TLS 1.3.

### 5.3 Estado Actual

> **El backend NO existe aún.** Los datasources del frontend están implementados como stubs que apuntan a endpoints hipotéticos. La construcción del backend Dart Frog es una tarea pendiente del proyecto.

---

## 6. Base de Datos

### 6.1 Infraestructura — Docker Compose

```yaml
version: '3.8'

services:
  postgres_moteros:
    image: postgis/postgis:15-3.3
    container_name: moteros_db
    restart: always
    environment:
      POSTGRES_USER: admin_motero
      POSTGRES_PASSWORD: TuPasswordSegura2026_!
      POSTGRES_DB: moteros_colombia_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 6.2 Esquema de Datos

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'aspirant', -- aspirant, member, admin, ally
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE places (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100), -- taller, restaurante, hotel, mirador
    geom GEOMETRY(Point, 4326),
    qr_token VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE visits (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    place_id INT REFERENCES places(id) ON DELETE CASCADE,
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    evidence_url VARCHAR(550),
    is_verified BOOLEAN DEFAULT FALSE
);
```

### 6.3 Optimización Geoespacial

- **Índices GIST** sobre `places.geom` para búsquedas espaciales en milisegundos.
- **SRID 4326** (WGS 84) para coordenadas GPS estándar.
- **PostGIS**: Extensión habilitada en toda base de datos nueva.

---

## 7. Flujo Crítico: Validación Anti-Fraude

```
[Motero en Ruta]
      │
      ▼
 Escanea QR del lugar
      │
      ▼
 Captura coordenadas GPS del dispositivo
      │
      ▼
[POST /validation] ─── { qr_token, latitude, longitude, evidence_url }
      │
      ▼
 Backend valida: ¿QR existe? ¿Distancia < 100m?
      │
      ├── SÍ ──> Guarda visita + evidence_url ──> Éxito (200 OK)
      │
      └── NO ──> Bloquea validación por fraude ──> Error (403 Forbidden)
```

### Consulta de Validación Espacial (PostGIS)

```sql
SELECT ST_DWithin(
    geom,
    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
    100  -- metros
)
FROM places
WHERE qr_token = :token;
```

### Reglas de Validación

| Condición | Resultado |
|---|---|
| QR token válido + distancia < 100m | Permite subir foto de evidencia → visita verificada |
| QR token válido + distancia > 100m | Bloquea → posible fraude |
| QR token inválido | Error 404 |
| Mismo usuario + mismo lugar en < 24h | Rechaza → visita duplicada |

---

## 8. Estados del Proyecto por Feature

| Feature | Domain (Entities) | Domain (UseCases) | Data (Models) | Data (Datasources) | BLoC | UI | Tests |
|---|---|---|---|---|---|---|---|
| **auth** | ✅ `user_entity.dart` | 🔶 stub (`UnimplementedError`) | ✅ `auth_model.dart` | ✅ `auth_remote_datasource.dart` | 🔶 placeholder | ✅ `login_screen.dart` | ❌ |
| **places** | ✅ `place_entity.dart` | 🔶 stub | ✅ `place_model.dart` | ✅ `place_remote_datasource.dart` | 🔶 placeholder | 🔶 placeholder | ❌ |
| **validation** | ✅ `visit_entity.dart` | 🔶 stub | ✅ `visit_model.dart` | ✅ `validation_remote_datasource.dart` | 🔶 placeholder | 🔶 placeholder | ❌ |
| **membership** | ✅ `membership_entity.dart` | 🔶 stub | ✅ `membership_model.dart` | ✅ `membership_remote_datasource.dart` | 🔶 placeholder | 🔶 placeholder | ❌ |
| **admin** | ✅ `ally_entity.dart` | 🔶 stub | ✅ `ally_model.dart` | ✅ `admin_remote_datasource.dart` | 🔶 placeholder | 🔶 placeholder | ❌ |

> ✅ Completo | 🔶 Parcial/Stub | ❌ No implementado

---

## 9. Roadmap de Desarrollo

### Fase 1 — Fundación (actual)
- [x] Esqueleto Clean Architecture con 5 features
- [x] Entidades y modelos de datos definidos
- [x] Stubs de datasources con endpoints hipotéticos
- [ ] Instalar `flutter_bloc` en `pubspec.yaml`
- [ ] Implementar repositorios entre datasources y use cases
- [ ] Agregar `equatable` para entidades

### Fase 2 — Backend Core
- [ ] Crear proyecto Dart Frog con rutas definidas en §5.1
- [ ] Configurar Docker Compose con PostgreSQL + PostGIS
- [ ] Implementar migraciones de base de datos (esquema en §6.2)
- [ ] Implementar autenticación JWT completa
- [ ] Conectar frontend con backend real

### Fase 3 — Features Core
- [ ] **auth**: Registro, login, refresh token, pantalla de onboarding
- [ ] **places**: Mapa interactivo, búsqueda geoespacial, detalle de lugar
- [ ] **validation**: Escáner QR, captura GPS, subida de evidencia

### Fase 4 — Monetización
- [ ] **membership**: Integración con pasarela de pago, webhooks, planes
- [ ] **admin**: Panel de gestión de aliados, dashboard de métricas

### Fase 5 — Madurez
- [ ] Gamificación: sistema de logros, badges, leaderboards
- [ ] Tests de integración y E2E
- [ ] CI/CD con GitHub Actions
- [ ] App Store + Google Play deployment

---

## 10. Convenciones del Proyecto

### 10.1 Nomenclatura

| Tipo | Convención | Ejemplo |
|---|---|---|
| Archivos Dart | `snake_case` | `place_remote_datasource.dart` |
| Clases | `PascalCase` | `PlaceRemoteDatasource` |
| Métodos/Variables | `camelCase` | `getNearbyPlaces()` |
| Carpetas | `snake_case` | `lib/features/places/` |
| Rutas API | `kebab-case` | `/auth/refresh-token` |
| Ramas Git | `kebab-case` | `feat/qr-validation-flow` |

### 10.2 Commits

- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Ejemplo: `feat(validation): implement QR scanner with mobile_scanner`

### 10.3 Testing

- **Strict TDD**: `true` (activado en configuración SDD)
- **Framework**: `flutter_test` (widget + unit tests)
- **Comando**: `flutter test`
- **Coverage**: Sin threshold definido aún (objetivo: 80%)
- **Linter**: `flutter analyze` (flutter_lints 6.0.0)
- **Formatter**: `dart format .`

---

## 11. Entorno de Desarrollo

### Requisitos

| Herramienta | Versión |
|---|---|
| Flutter SDK | ≥ 3.44.4 |
| Dart SDK | ≥ 3.12.2 |
| Docker + Docker Compose | Latest |
| PostgreSQL + PostGIS | 15-3.3 (vía Docker) |
| Android Studio / Xcode | Latest stable |

### Levantar el Entorno

```bash
# Clonar e instalar dependencias
flutter pub get

# Levantar base de datos
docker compose up -d

# Ejecutar tests
flutter test

# Análisis estático
flutter analyze

# Correr en dispositivo/emulador
flutter run
```

---

## 12. Referencias Cruzadas

| Documento | Ubicación |
|---|---|
| Configuración SDD | `openspec/config.yaml` |
| Skill Registry | `.atl/skill-registry.md` |
| Gentleman Guardian Angel | `.gga` |
| Analysis Options | `analysis_options.yaml` |

---

> **Última actualización**: 2026-07-01
> **Versión del documento**: 1.0.0
> **Autor**: Equipo Moteros App
