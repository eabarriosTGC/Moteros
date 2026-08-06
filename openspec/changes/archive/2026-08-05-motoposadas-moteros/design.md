# SDD Technical Design — Casa de Motero: CRUD Propio, Visibilidad en Mapa Difuminada & Contacto WhatsApp

> **Proyecto:** Moteros / AsfaltoClub
> **Documento:** Technical Design para `motoposadas-moteros`
> **Base:** `proposal.md` + 3 delta specs (`motoposada-crud`, `mapa-casa-motero`, `contacto-whatsapp`)
> **Estado:** ✅ Aprobado para implementación

---

## 1. F-M9 — CRUD de casa_motero (max-1, RLS owner-only, disclaimer, sin cédula)

### 1.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Ubicación de datos privados | Tabla compañera `casa_motero_details` (lat_exact/lng_exact/whatsapp_phone) con RLS owner-only | Columnas `lat_exact`/`lng_exact` en `motoposadas` + GRANT a nivel columna | **Opción A — tabla separada** | El precedente del repo es RLS a nivel tabla (009/010/007); no hay precedente de GRANTs por columna y un `select('*')` futuro (o un SECURITY DEFINER) filtraría las columnas exactas. Separación física = las coords exactas son *inalcanzables* desde cualquier query pública aunque alguien use `select('*')` (M-MAPA-1, M-CRUD-5). |
| RLS de `casa_motero_details` | Columna directa `user_id` en la tabla + políticas `user_id = auth.uid()` | Política con subquery `EXISTS (SELECT 1 FROM motoposadas WHERE user_id = auth.uid())` | **Columna directa `user_id`** | Todas las políticas propias del repo (routes_insert_own, mileage_update_own…) son igualdad simple de columna. Las políticas con subquery cruzada fueron exactamente la clase de bug que obligó a las migraciones 012/013 (fix RLS recursion). Columna directa = un solo índice, sin recursión. La consistencia `details.user_id = motoposadas.user_id` la garantiza el RPC (único path de INSERT). |
| Invariante max-1 | Índice único parcial `ON motoposadas(user_id) WHERE poi_type='casa_motero'` | Trigger BEFORE INSERT | **Índice único parcial** | Es el invariante a nivel DB (M-CRUD-1): imposible de eludir por cliente, cero código. Trigger rechazado (más pesado y race-prone en alta concurrencia). App-only rechazado (spam bypass). 23505 → mensaje amigable. |
| Create | RPC `create_casa_motero(...)` SECURITY DEFINER, firma fija estrecha | INSERT directo a `motoposadas` + `casa_motero_details` | **RPC atómico** | Necesita: atomicidad (dos filas, M-CRUD-2 sin escritura parcial), `disclaimer_accepted_at` NOT NULL, `user_id = auth.uid()` (sin parámetro de user), y el chequeo ≥300 m server-side. INSERT directo no puede imponer el floor de blur ni la atomicidad. |
| Update / toggle / delete | Policies existentes (`mp_update_own`, `mp_delete_own` 009) + `cmd_update_own`/`cmd_delete_own` nuevas + trigger de blur floor | RPCs de update | **Policies existentes + trigger** | Coincide con el approach de la proposal y con el patrón del repo (007/009). El floor de blur en edit paths lo cubre un trigger (ver 2.2) — el invariante vive en la DB, igual que el max-1. |
| Disclaimer | Checkbox obligatorio en el form + `disclaimer_accepted_at` persistido por el RPC (NOT NULL en la tabla) | Flag boolean `disclaimer_accepted` | **Timestamp** | M-CRUD-3 exige persitir la aceptación; un timestamp es auditable y no puede ser un "phantom flag" (mismo bug class que `onboarding_complete`, ADR-001 del archivo previo). El RPC rechaza NULL. |
| Cédula / identidad | No existe campo cédula ni documento en ningún form/model/payload | — | **Ausencia por construcción** | Continuidad con OP-R2 archivado (Ley 1581 de 2012) — decisión registrada, no se re-litiga (M-CRUD-4). El RPC no recibe ni persiste identidad; guard test como `no_cedula_guard_test.dart`. |
| Dirección exacta | El form de casa_motero NO tiene campo address; RPC escribe `address = NULL` | Campo address opcional | **Nunca se recolecta** | M-WA-3: la app no transmite dirección exacta. Si no se recolecta, no puede filtrarse. El `address` público de motoposadas queda vacío para casa_motero. |

### 1.2 Supabase migration — SQL exacto

File: `supabase/migrations/026_casa_motero.sql` (siguiente ordinal tras `025_`).

```sql
-- MIGRATION 026: casa_motero (F-M9/F-M10/F-M11)
-- Additiva e idempotente. Depende de haversine_distance (001).
BEGIN;

-- ── 1. Invariante max-1 (M-CRUD-1): un solo casa_motero por usuario ──
CREATE UNIQUE INDEX IF NOT EXISTS uq_motoposadas_casa_motero_user
    ON motoposadas(user_id)
    WHERE poi_type = 'casa_motero';

-- Reviewer fix (2026-08-05): mp_insert_own (009) es WITH CHECK sin
-- restricción de poi_type → un POST directo podía crear casa_motero con
-- coords exactas, eludiendo disclaimer + blur floor. Se re-crea con la
-- exclusión; el RPC (SECURITY DEFINER, BYPASSRLS como 025) queda como
-- ÚNICO path de INSERT de casa_motero.
DROP POLICY IF EXISTS mp_insert_own ON motoposadas;
CREATE POLICY "mp_insert_own" ON motoposadas
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND poi_type IS DISTINCT FROM 'casa_motero'
    );

-- ── 2. Tabla privada: coords exactas + WhatsApp + disclaimer ──
CREATE TABLE IF NOT EXISTS casa_motero_details (
    id                      BIGSERIAL PRIMARY KEY,
    motoposada_id           BIGINT NOT NULL UNIQUE
                            REFERENCES motoposadas(id) ON DELETE CASCADE,
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lat_exact               DOUBLE PRECISION NOT NULL,
    lng_exact               DOUBLE PRECISION NOT NULL,
    whatsapp_phone          TEXT NOT NULL
                            CHECK (whatsapp_phone ~ '^\+?[0-9]{7,15}$'),
    disclaimer_accepted_at  TIMESTAMPTZ NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cmd_user ON casa_motero_details(user_id);

ALTER TABLE casa_motero_details ENABLE ROW LEVEL SECURITY;

-- Owner-only (M-CRUD-2). Columna directa user_id: sin subqueries cruzadas
-- (precedente de recursión RLS 012/013).
CREATE POLICY "cmd_select_own" ON casa_motero_details
    FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "cmd_update_own" ON casa_motero_details
    FOR UPDATE USING (user_id = auth.uid());
-- Reviewer fix: SIN cmd_delete_own — un DELETE directo de details dejaría
-- un casa_motero público huérfano (marker renderiza, Contactar=NULL, edits
-- futuros mueren con casa_motero_details_missing). El borrado legítimo es
-- vía mp_delete_own en motoposadas + FK CASCADE (atómico, §1.4).
-- Sin policy de INSERT: el único path de creación es create_casa_motero()
-- (SECURITY DEFINER). Un INSERT directo del owner podría eludir el floor
-- de blur y el disclaimer — se bloquea por ausencia de policy.

-- ── 3. RPC create (M-CRUD-3/M-CRUD-5, M-MAPA-1) ──
-- SECURITY DEFINER con firma fija estrecha: el server deriva user_id de
-- auth.uid() (no se acepta como parámetro), valida disclaimer, teléfono,
-- capacidad y el floor de >=300 m entre approx y exact (anti-defeat del blur).
CREATE OR REPLACE FUNCTION public.create_casa_motero(
    p_title                 TEXT,
    p_description           TEXT,
    p_max_guests            INT,
    p_lat                   DOUBLE PRECISION,  -- approx (público, difuminado)
    p_lng                   DOUBLE PRECISION,
    p_lat_exact             DOUBLE PRECISION,  -- exacto (privado)
    p_lng_exact             DOUBLE PRECISION,
    p_whatsapp_phone        TEXT,
    p_disclaimer_accepted_at TIMESTAMPTZ
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_id  BIGINT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_disclaimer_accepted_at IS NULL THEN
        RAISE EXCEPTION 'disclaimer_not_accepted';
    END IF;
    IF p_whatsapp_phone IS NULL OR p_whatsapp_phone !~ '^\+?[0-9]{7,15}$' THEN
        RAISE EXCEPTION 'invalid_whatsapp_phone';
    END IF;
    IF p_max_guests < 1 THEN
        RAISE EXCEPTION 'invalid_max_guests';
    END IF;
    -- Floor de blur: frontera de seguridad SERVER-side (M-MAPA-1).
    IF haversine_distance(p_lat, p_lng, p_lat_exact, p_lng_exact) < 300 THEN
        RAISE EXCEPTION 'blur_floor_violation';
    END IF;

    -- Fila pública: coords difuminadas; address NULL (nunca se recolecta);
    -- is_active = disponible (TRUE); visibility forzada 'public'; poi_type
    -- 'casa_motero' sobre type='casa' (CHECK 009 intacto).
    INSERT INTO motoposadas (
        user_id, type, title, description, lat, lng,
        address, max_guests, is_active, visibility, poi_type
    ) VALUES (
        v_uid, 'casa', p_title, p_description, p_lat, p_lng,
        NULL, p_max_guests, TRUE, 'public', 'casa_motero'
    ) RETURNING id INTO v_id;

    -- Fila privada. Dos INSERTs en una sola llamada = transacción implícita:
    -- si el segundo falla, el primero se revierte (sin escritura parcial,
    -- M-CRUD-2). El 23505 del índice parcial revierte todo también.
    INSERT INTO casa_motero_details (
        motoposada_id, user_id, lat_exact, lng_exact,
        whatsapp_phone, disclaimer_accepted_at
    ) VALUES (
        v_id, v_uid, p_lat_exact, p_lng_exact,
        p_whatsapp_phone, p_disclaimer_accepted_at
    );

    RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_casa_motero(
    TEXT, TEXT, INT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    DOUBLE PRECISION, TEXT, TIMESTAMPTZ) FROM public;
GRANT EXECUTE ON FUNCTION public.create_casa_motero(
    TEXT, TEXT, INT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    DOUBLE PRECISION, TEXT, TIMESTAMPTZ) TO authenticated;

-- ── 4. RPC contacto (F-M11): teléfono ON DEMAND ──
-- SECURITY DEFINER tradeoff documentado: bypasea RLS por diseño (lee la tabla
-- privada sin policy SELECT para el caller). Mitigación: firma de un solo id,
-- guard activo + tipo, retorna SOLO whatsapp_phone (nunca coords exactas).
-- Devuelve NULL para inexistente / inactivo / no-casa_motero (sin oráculo de
-- existencia: mismo resultado que un id inválido).
CREATE OR REPLACE FUNCTION public.get_motoposada_whatsapp(p_id BIGINT)
RETURNS TEXT
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
    SELECT d.whatsapp_phone
    FROM motoposadas m
    JOIN casa_motero_details d ON d.motoposada_id = m.id
    WHERE m.id = p_id
      AND m.poi_type = 'casa_motero'
      AND m.is_active = TRUE
$$;

REVOKE ALL ON FUNCTION public.get_motoposada_whatsapp(BIGINT) FROM public;
GRANT EXECUTE ON FUNCTION public.get_motoposada_whatsapp(BIGINT) TO authenticated;

COMMIT;
```

> Nota apply: `motoposadas.is_approved` es una columna ad-hoc en prod (la escribe `_onCreateTouristPoi`, ninguna migración la declara — precedente igual a `bike_model`/`phone` en 025). Casa_motero no la usa; verificar en apply si conviene declararla en esta migración para que el trail coincida con la realidad.

### 1.3 Flujo max-1 UX (pre-check + 23505)

- **Pre-check (UX)**: al abrir el form de casa_motero, el bloc despacha `CheckCasaMoteroEligibility` → `SELECT id FROM motoposadas WHERE user_id = auth.uid() AND poi_type='casa_motero'` → si existe, el form muestra estado bloqueado con link "IR A MI CASA" (escenario spec M-CRUD-1). No es la frontera de seguridad — solo UX.
- **23505 (frontera real)**: `PostgrestException.code == '23505'` en el handler de create → estado `CasaMoteroAlreadyExists` → SnackBar "Ya tienes una casa de motero publicada" + link. Nunca crash.

### 1.4 Edición / toggle / delete (M-CRUD-2, M-CRUD-5)

- **Público** (title, description, max_guests, lat/lng approx, is_active): `UpdateCasaMotero` → `mp_update_own` (009). El evento actual `UpdateMotoposada` no lleva lat/lng → nuevo evento con lat/lng approx (el form vuelve a jitterear antes de guardar). `is_active` = toggle disponible.
- **Privado** (whatsapp_phone, lat_exact, lng_exact): `UpdateCasaMoteroDetails` → `cmd_update_own` directo (owner-only). El floor de blur en ambos paths lo cubre el trigger (2.2).
- **Delete**: `DeleteMotoposada` existente → `mp_delete_own`; `casa_motero_details` se borra en cascada (FK CASCADE). Atómico.

---

## 2. F-M10 — Mapa difuminado (marker, card, floor de blur)

### 2.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Dónde se difumina | **Cliente**: jitter 300–500 m antes de enviar (UX); **servidor**: chequeo ≥300 m en el RPC (frontera de seguridad) | Solo cliente / solo servidor | **Cliente (UX) + servidor (seguridad)** | M-MAPA-1: el cliente jitterea para que el mapa público muestre coords distintas; el servidor valida el floor para que un cliente malicioso no pueda publicar coords exactas. El jitter es función pura unit-testable con `Random` inyectable. |
| Función de distancia server | `haversine_distance` existente (001, `LANGUAGE sql IMMUTABLE PARALLEL SAFE`, devuelve metros) | `ST_Distance` PostGIS | **haversine_distance** | Ya existe, ya la usa `suggest_motoposadas_for_route` (010) y `is_within_distance` (001). No hay PostGIS en el trail de migraciones (verificado: ninguna `CREATE EXTENSION postgis`); añadir una extensión para un solo chequeo es sobre-provisión. Mismo algoritmo en el espejo Dart de tests. |
| Algoritmo de jitter (cliente) | Ángulo aleatorio θ∈[0,2π), distancia uniforme d∈[300,500] m; offset lat = d·cos(θ)/111320, offset lng = d·sin(θ)/(111320·cos(lat)) | Cuadrícula fija / redondeo de dígitos | **Polar uniforme** | Distribución uniforme en el anillo 300–500 m: sin sesgo direccional, sin patrón detectable; función pura `blurCoordinates(lat, lng, {minMeters, maxMeters, random})`. |
| Invariante blur en edit paths | Trigger `BEFORE UPDATE OF lat,lng` en motoposadas + `BEFORE INSERT OR UPDATE OF lat_exact,lng_exact` en details | Confiar en que el cliente jitterea siempre | **Triggers (defensa en profundidad)** | El floor ≥300 m es requisito MUST (M-MAPA-1). Sin trigger, un UPDATE directo del owner (mp_update_own/cmd_update_own) podría dejar approx = exact y desenmascarar la ubicación. Mismo criterio que el max-1: invariantes de DB viven en la DB. En create el trigger NO dispara sobre INSERT de motoposadas (el RPC ya validó; el details row aún no existe — evitaría orden circular), y sí valida en el INSERT de details contra la fila pública ya creada. |
| Marker | Nuevo `CasaMoteroMarker` (icono home en color `secondary` + chip "casa") distinto de `TouristPoiMarker` (estrella warning) y del marker curado (home primary) | Reusar TouristPoiMarker | **Nuevo widget** | M-MAPA-2 exige distinción visual explícita. El switch en rodar_screen se vuelve 3 vías: `isTourist` → TouristPoiMarker; `isCasaMotero` → CasaMoteroMarker; si no → `_buildMotoposadaMarker`. La capa ya filtra `m.isActive` (línea 210) → casa_motero inactivo nunca aparece (M-MAPA-2). |
| Card | Nuevo `CasaMoteroCard` (bottom sheet widget propio con BlocListener) reusando `TrustSignalsRow` | Extender `_showMotoposadaCard` inline | **Widget propio** | La card de casa_motero tiene flujo asíncrono (Contactar → RPC → wa.me) y restricciones distintas (sin phone/address). Widget separado = testable de forma aislada (M-MAPA-3, M-WA-1/2). `TrustSignalsRow` ya existe y es dumb (sin dependencia Supabase) — se alimenta de los host fields ya presentes en `MotoposadaModel` (verificado: hostName/hostLevel/hostMemberSince/hostKm/hostTrips/hostBadges desde F-M13). |
| Navegación | Botones Waze/Google Maps con `mp.lat/mp.lng` (approx) — reutiliza `NavigationHandler` + `_buildNavRow` pattern | Navegar a coords exactas | **Approx** | Las coords públicas SON las approx; navegar con ellas mantiene la privacidad (la zona aproximada es el destino visible). El card muestra nota "Ubicación aproximada". |

### 2.2 Trigger blur floor — SQL exacto (misma migración 026)

```sql
-- Floor de blur en edit paths (M-MAPA-1). Dispara sobre UPDATE de coords
-- públicas (motoposadas) y sobre INSERT/UPDATE de coords exactas (details).
-- SECURITY DEFINER: el chequeo no puede eludirse vía RLS del invocador.
CREATE OR REPLACE FUNCTION public.enforce_casa_motero_blur_floor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exact_lat DOUBLE PRECISION;
    v_exact_lng DOUBLE PRECISION;
BEGIN
    SELECT lat_exact, lng_exact INTO v_exact_lat, v_exact_lng
    FROM casa_motero_details WHERE motoposada_id = NEW.id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'casa_motero_details_missing';
    END IF;
    IF haversine_distance(NEW.lat, NEW.lng, v_exact_lat, v_exact_lng) < 300 THEN
        RAISE EXCEPTION 'blur_floor_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_casa_motero_blur_floor ON motoposadas;
-- No dispara en INSERT: en create el RPC ya validó y la fila details aún no
-- existe (evita el orden circular motoposadas→details).
-- Reviewer fix: incluye poi_type en la columna lista — sin esto, un UPDATE
-- podía FLIPEAR una fila existente a casa_motero (el trigger con column-list
-- lat,lng no disparaba) y desenmascarar coords exactas vía marker público.
-- El flip-in ahora muere con 'casa_motero_details_missing' (no hay details
-- row). Caso residual aceptable y documentado: flip-out de casa_motero queda
-- permitido (huérfana details y libera el slot max-1).
CREATE TRIGGER trg_casa_motero_blur_floor
    BEFORE UPDATE OF lat, lng, poi_type ON motoposadas
    FOR EACH ROW
    WHEN (NEW.poi_type = 'casa_motero')
    EXECUTE FUNCTION public.enforce_casa_motero_blur_floor();

CREATE OR REPLACE FUNCTION public.enforce_casa_motero_details_blur_floor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_public_lat DOUBLE PRECISION;
    v_public_lng DOUBLE PRECISION;
BEGIN
    SELECT lat, lng INTO v_public_lat, v_public_lng
    FROM motoposadas WHERE id = NEW.motoposada_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'motoposada_missing';
    END IF;
    IF haversine_distance(NEW.lat_exact, NEW.lng_exact, v_public_lat, v_public_lng) < 300 THEN
        RAISE EXCEPTION 'blur_floor_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_casa_motero_details_blur_floor ON casa_motero_details;
CREATE TRIGGER trg_casa_motero_details_blur_floor
    BEFORE INSERT OR UPDATE OF lat_exact, lng_exact ON casa_motero_details
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_casa_motero_details_blur_floor();
```

### 2.3 Blur — función pura cliente

```dart
// lib/core/location/blur_coordinates.dart
/// Jitter UX (NUNCA frontera de seguridad — el floor lo valida el server).
class BlurredCoordinates {
  final double lat;
  final double lng;
  final double offsetMeters;
  const BlurredCoordinates({required this.lat, required this.lng, required this.offsetMeters});
}

/// Ángulo aleatorio + distancia uniforme en [minMeters, maxMeters] (anillo).
BlurredCoordinates blurCoordinates(
  double lat, double lng, {
  double minMeters = 300,
  double maxMeters = 500,
  math.Random? random,
}) {
  final rng = random ?? math.Random();
  final d = minMeters + rng.nextDouble() * (maxMeters - minMeters);
  final theta = rng.nextDouble() * 2 * math.pi;
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(lat * math.pi / 180);
  return BlurredCoordinates(
    lat: lat + d * math.cos(theta) / mPerDegLat,
    lng: lng + d * math.sin(theta) / mPerDegLng,
    offsetMeters: d,
  );
}

/// Espejo Dart de haversine_distance (001) — SOLO para tests del jitter.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1), dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return r * 2 * math.asin(math.sqrt(a));
}
```

### 2.4 Marker y card

```dart
// lib/features/refugios/presentation/widgets/casa_motero_marker.dart
/// Distinto del marker curado (home primary) y del TouristPoiMarker (estrella
/// warning): icono home en AppColors.secondary + chip "casa".
class CasaMoteroMarker extends StatelessWidget { /* Column: chip + círculo secondary con Icons.home_rounded */ }

/// Selector puro 3-vías usado por rodar_screen — unit-testable sin mapa.
MarkerKind markerKindFor(MotoposadaModel m) =>
    m.isTourist ? MarkerKind.tourist
    : m.isCasaMotero ? MarkerKind.casaMotero
    : MarkerKind.standard;
```

- `MotoposadaModel` (state) gana: `bool get isCasaMotero => poiType == 'casa_motero';` y `String get poiTypeLabel => isCasaMotero ? 'Casa de motero' : typeLabel;` — sin campo de teléfono (M-WA-1: el modelo público NUNCA lleva phone).
- `rodar_screen.dart`: el builder del `MarkerLayer` usa `markerKindFor(m)`; la card se abre con `CasaMoteroCard(mp: m)` (nuevo widget) en vez de `_showMotoposadaCard` cuando `isCasaMotero`.
- `CasaMoteroCard` muestra: alias, badge "Casa de motero", descripción (M-MAPA-3 — reviewer fix: estaba omitida en §2.4), capacidad, `TrustSignalsRow(signals: TrustSignals(memberSince: mp.hostMemberSince, trips: mp.hostTrips, km: mp.hostKm, badges: mp.hostBadges))`, nota "Ubicación aproximada", nav Waze/Google Maps con `mp.lat/mp.lng`, y botón "Contactar". **Sin** teléfono, **sin** dirección (M-MAPA-3).
- `featured_motoposada_card.dart`: badge usa `poiTypeLabel`; para casa_motero la línea de ubicación muestra "Ubicación aproximada" en vez de address/coords (nunca address).

---

## 3. F-M11 — WhatsApp on demand (wa.me + fallback)

### 3.1 Architecture decisions

| Decisión | Opción A | Opción B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Cuándo se obtiene el teléfono | RPC `get_motoposada_whatsapp(id)` al tocar "Contactar" | Teléfono en el payload de la lista/card | **On demand** | M-WA-1: el phone no aparece en payloads públicos; si estuviera en la lista se filtraría en cada query pública del mapa. El RPC retorna SOLO `whatsapp_phone` (nunca coords), con guard activo+tipo. |
| `MotoposadaModel` | Sin campo phone (ausencia por construcción) | Campo nullable | **Sin campo** | Si el modelo no tiene la key, ningún bug de UI puede renderizarla (mismo criterio que trust_score en TS-R3). La card lo obtiene en el tap vía estado `CasaMoteroWhatsappLoaded`. |
| URL | `https://wa.me/<digitos>?text=<mensaje codificado>` | `whatsapp://send` | **wa.me** | Funciona con app instalada Y con fallback web; `whatsapp://` falla sin app. Los dígitos se normalizan (strip no-dígitos, quitar `+`). El mensaje pre-cargado de disponibilidad NO incluye coords ni dirección (M-WA-3) — si el host comparte su dirección, es decisión suya fuera de la app. |
| Fallback (M-WA-2) | `canLaunchUrl` del wa.me → false (o throw) → bottom sheet "Abrir WhatsApp Web" (`web.whatsapp.com/send?phone=…&text=…`) + "Copiar mensaje" (Clipboard) | SnackBar solo | **Fallback con dos acciones** | Sin fallo silencioso (M-WA-2): el usuario siempre puede contactar (web) o llevarse el mensaje. Sigue el patrón `_buildNavRow` de rodar_screen (canLaunch + mensaje claro). |

### 3.2 Código cliente — builder y lanzador

```dart
// lib/core/services/whatsapp_launcher.dart
/// wa.me con dígitos normalizados + mensaje codificado. NUNCA coords/address.
String buildWhatsAppUrl(String phone, String message) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
}

/// Mensaje de disponibilidad sin datos de ubicación (M-WA-3).
String buildAvailabilityMessage(String hostAlias) =>
    'Hola $hostAlias 👋 Vi tu casa de motero en Moteros. ¿Está disponible?';

/// Lanzamiento + fallback: si canLaunchUrl falla o lanza, ofrece WhatsApp Web
/// (web.whatsapp.com) y copiar el mensaje — nunca silencio.
Future<void> launchWhatsAppContact(BuildContext context, String phone, String message) async {
  final waUri = Uri.parse(buildWhatsAppUrl(phone, message));
  try {
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}
  // Fallback: WhatsApp Web + copiar mensaje (M-WA-2)
  final webUri = Uri.parse(
      'https://web.whatsapp.com/send?phone=${phone.replaceAll(RegExp(r'[^0-9]'), '')}&text=${Uri.encodeComponent(message)}');
  // showModalBottomSheet con: "Abrir WhatsApp Web" (launchUrl webUri) +
  // "Copiar mensaje" (Clipboard.setData) + mensaje claro "WhatsApp requerido".
}
```

---

## 4. Diagramas de secuencia

### (a) Create casa_motero — form → jitter → RPC → filas → max-1

```
CreateCasaMoteroScreen      MotoposadasBloc        create_casa_motero (DB)    motoposadas        casa_motero_details
      │ initState → CheckCasaMoteroEligibility          │                         │                     │
      │─────────────────────────>│                      │                         │                     │
      │                          │ SELECT id WHERE user_id=auth.uid() AND poi_type='casa_motero'        │
      │                          │─────────────────────>│                         │                     │
      │<─────────────────────────│ row? (null=ok)       │                         │                     │
      │  (si existe → UI bloqueada + link "IR A MI CASA")                        │                     │
      │  owner elige punto exacto en MapPickerScreen                             │                     │
      │  blurCoordinates(exact) → approx (función pura, jitter 300–500 m)        │                     │
      │  disclaimer checkbox (submit bloqueado si no)                            │                     │
      │  CreateCasaMotero(title, desc, cap, approx, exact, phone, acceptedAt)    │                     │
      │─────────────────────────>│                      │                         │                     │
      │                          │ rpc create_casa_motero(...)                   │                     │
      │                          │─────────────────────>│                         │                     │
      │                          │                      │ haversine(approx,exact)<300 → RAISE 'blur_floor_violation'
      │                          │                      │ INSERT (user_id=auth.uid(), lat/lng=approx,    │
      │                          │                      │   address=NULL, is_active=TRUE, poi_type='casa_motero')
      │                          │                      │────────────────────────>│                     │
      │                          │                      │ INSERT (lat_exact, lng_exact, phone,           │
      │                          │                      │   disclaimer_accepted_at)                      │
      │                          │                      │──────────────────────────────────────────────>│
      │                          │<─────────────────────│ id (o 23505 del índice parcial → rollback)     │
      │<─────────────────────────│ MotoposadaCreated(id)│                         │                     │
      │  pop(true) — SnackBar ✅                        │                         │                     │
      │  23505 → PostgrestException.code=='23505' → CasaMoteroAlreadyExists →     │                     │
      │  "Ya tienes una casa de motero publicada" (nunca crash)                   │                     │
```

### (b) Mapa render + tap marker → card (signals del join, sin phone)

```
RodarScreen initState        MotoposadasBloc        Supabase (motoposadas × users × user_xp × counts)    MarkerLayer     CasaMoteroCard
      │ LoadMotoposadas            │                            │                                            │               │
      │───────────────────────────>│                            │                                            │               │
      │                             │ SELECT *, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))
      │                             │───────────────────────────>│                                            │               │
      │                             │<───────────────────────────│ filas con signals anidadas (sin phone,    │               │
      │                             │                            │  sin lat_exact/lng_exact — cols privadas) │               │
      │                             │ rpc get_trip_counts([hostIds])                                          │               │
      │                             │───────────────────────────>│                                            │               │
      │                             │<───────────────────────────│ [{user_id, trips}]                        │               │
      │                             │ fromMap() → hostMemberSince/hostKm/hostTrips/hostBadges (F-M13)         │               │
      │<───────────────────────────│ MotoposadasLoaded            │                                            │               │
      │                             │                            │                                            │               │
      │  BlocBuilder → .where(m.isActive) → markerKindFor(m)     │                                            │               │
      │  casa_motero → CasaMoteroMarker at LatLng(m.lat, m.lng)  │          (approx — nunca exact)           │               │
      │────────────────────────────────────────────────────────────────────────────────────────────────────>│               │
      │  tap marker ─────────────────────────────────────────────────────────────────────────────────────────────────────────>│
      │                             │                            │                                            │               │
      │                             │                            │              TrustSignalsRow(signals:    │               │
      │                             │                            │                memberSince, trips, km,    │               │
      │                             │                            │                badges) ← host fields del  │               │
      │                             │                            │                modelo (join), sin phone   │               │
      │                             │                            │              alias + capacidad + "Ubicación aproximada"
```

### (c) Contactar → RPC phone → wa.me → fallback

```
CasaMoteroCard            MotoposadasBloc        get_motoposada_whatsapp (DB)    casa_motero_details      WhatsApp
      │ Contactar tap            │                            │                         │                     │
      │ FetchCasaMoteroWhatsapp(id)                          │                         │                     │
      │─────────────────────────>│                            │                         │                     │
      │                          │ rpc get_motoposada_whatsapp({'p_id': id})           │                     │
      │                          │───────────────────────────>│                         │                     │
      │                          │                            │ SELECT phone WHERE id=p_id AND                │
      │                          │                            │   poi_type='casa_motero' AND is_active=TRUE   │
      │                          │                            │────────────────────────>│                     │
      │                          │<───────────────────────────│ phone (NULL si inactivo/otro tipo/inexistente)│
      │<─────────────────────────│ CasaMoteroWhatsappLoaded(phone)                                          │
      │  phone==null → SnackBar "El anfitrión no está disponible"                                            │
      │  buildWhatsAppUrl(phone, buildAvailabilityMessage(alias))                                            │
      │  canLaunchUrl(wa.me) ───────────────────────────────────────────────────────────────────────────────>│
      │  true → launchUrl(wa.me/…?text=…) ──────────────────────────────────────────────────────────────────>│ abre chat
      │  false/throw → bottom sheet: "Abrir WhatsApp Web" (web.whatsapp.com) + "Copiar mensaje" (Clipboard)  │
```

---

## 5. File changes

| File | Acción | Descripción |
|------|--------|-------------|
| `supabase/migrations/026_casa_motero.sql` | Create | Índice único parcial max-1; `casa_motero_details` + RLS owner-only; `create_casa_motero` (≥300 m, disclaimer, auth.uid); `get_motoposada_whatsapp`; triggers blur floor |
| `lib/core/location/blur_coordinates.dart` | Create | `blurCoordinates` (jitter 300–500 m, Random inyectable) + espejo `haversineMeters` para tests |
| `lib/core/services/whatsapp_launcher.dart` | Create | `buildWhatsAppUrl`, `buildAvailabilityMessage` (sin ubicación), `launchWhatsAppContact` + fallback web/copiar |
| `lib/features/refugios/presentation/widgets/casa_motero_marker.dart` | Create | `CasaMoteroMarker` (secondary + home) + `markerKindFor` puro |
| `lib/features/refugios/presentation/widgets/casa_motero_card.dart` | Create | Bottom sheet card: alias/capacidad/`TrustSignalsRow`/nav approx/Contactar + BlocListener del phone |
| `lib/features/refugios/presentation/bloc/motoposadas_event.dart` | Modify | `CreateCasaMotero`, `UpdateCasaMotero` (con lat/lng approx), `UpdateCasaMoteroDetails`, `FetchCasaMoteroWhatsapp`, `CheckCasaMoteroEligibility`, `LoadCasaMoteroDetails` (reviewer fix: path del prefill del edit form) |
| `lib/features/refugios/presentation/bloc/motoposadas_state.dart` | Modify | `isCasaMotero`/`poiTypeLabel` en el modelo (sin phone); estados `CasaMoteroEligibilityLoaded`, `CasaMoteroWhatsappLoaded`, `CasaMoteroAlreadyExists`, `CasaMoteroDetailsLoaded` (reviewer fix: prefill del edit form) |
| `lib/features/refugios/presentation/bloc/motoposadas_bloc.dart` | Modify | Handlers: pre-check, create vía RPC (mapeo 23505), update público/privado, fetch phone on demand |
| `lib/features/refugios/presentation/screens/create_motoposada_screen.dart` | Modify | Modo casa_motero (`CreateMotoposadaScreen(mode: casaMotero, existing:)`): alias/desc/capacidad/WhatsApp/checklist disclaimer/map picker con jitter; SIN address, SIN cédula; modo edición reutilizado |
| `lib/features/refugios/presentation/screens/my_motoposada_screen.dart` | Modify | Entrada "Ofrecer casa de motero" + edit/toggle/delete propio de casa_motero |
| `lib/features/dashboard/presentation/screens/rodar_screen.dart` | Modify | Switch 3-vías `markerKindFor`; abre `CasaMoteroCard` para casa_motero |
| `lib/features/explorar/presentation/widgets/featured_motoposada_card.dart` | Modify | Badge `poiTypeLabel`; casa_motero → "Ubicación aproximada" (nunca address) |

**Totales:** 5 NEW, 7 MODIFIED, 0 DELETED.

## 6. Testing strategy (strict TDD — `flutter test`, RED first; mapeado por escenario)

| Capa | Spec | Test | Approach |
|------|------|------|----------|
| Unit | M-MAPA-1 | `blurCoordinates`: distancia ∈ [300,500] m (espejo haversine, tolerancia ±10 m — el haversine del punto jittereado es ≈d, no exactamente d; assert estricto flakearía en bordes), determinista con `Random(seed)`, coords ≠ exact | `flutter_test`, función pura |
| Unit | M-MAPA-1 | Payload builder público: keys `lat_exact/lng_exact/whatsapp_phone` ausentes del payload del form/event de create; `address` ausente (M-WA-3) | Inspección de payload |
| Unit | M-WA-1/M-WA-3 | `buildWhatsAppUrl`: `wa.me/<digitos>?text=<msg>`; normaliza `+`/espacios; mensaje sin coords ni address | Puro |
| Unit | M-WA-2 | `launchWhatsAppContact`: canLaunch=false → fallback web + copiar; throw → mismo fallback (nunca silencio) | Mock `url_launcher` (mocktail) |
| Unit | M-CRUD-4 | Form casa_motero: ninguna key cédula/documento en form, evento y payload RPC | Extiende patrón `no_cedula_guard_test.dart` |
| Widget | M-CRUD-3 | Form: submit bloqueado con disclaimer desmarcado + mensaje; aceptado → `disclaimer_accepted_at` no nulo en el evento | `create_casa_motero_screen_test.dart` |
| Widget | M-CRUD-1 | Pre-check: `CasaMoteroEligibilityLoaded(has: true)` → UI bloqueada + link "IR A MI CASA"; 23505 → SnackBar amigable, sin crash | Fake bloc estados |
| Widget | M-CRUD-2/M-CRUD-5 | Edición (My casa): edit/toggle/delete del owner; el form muestra phone/exact solo al owner (prefill vía details SELECT) | `my_motoposada_casa_motero_test.dart` |
| Widget | M-MAPA-2 | `CasaMoteroMarker` visible solo con `isActive=true` y distinto de TouristPoiMarker/curated (icono+color); `markerKindFor` 3-vías | `casa_motero_marker_test.dart` |
| Widget | M-MAPA-3 | `CasaMoteroCard`: alias, desc, capacidad, `TrustSignalsRow` (4 valores); sin phone ni address en el árbol | `casa_motero_card_test.dart` |
| Widget | M-WA-1 | Card: tap Contactar → dispara `FetchCasaMoteroWhatsapp` → con phone renderiza URL wa.me | Con fake bloc |
| Widget | M-WA-2 | Card: phone null → mensaje "no disponible"; canLaunch=false → fallback visible | Mock launcher |
| Datasource/RLS (noSuchMethod) | M-CRUD-2 | Fake `SupabaseClient` (patrón `raid_bloc_test.dart`): UPDATE/DELETE con `user_id != auth.uid()` → error propagado, sin escritura parcial; create RPC invocado con params exactos (approx jittereados + exact + disclaimer) | Fakes `FakeSupabaseClient/FakeQueryBuilder/FakeFilterBuilder` |
| Datasource/RLS (noSuchMethod) | M-WA-1 | `get_motoposada_whatsapp`: fake RPC devuelve NULL para id inactivo/no-casa_motero → estado "no disponible"; phone para activo | Fake `rpc` |
| Datasource | M-MAPA-1 | Bloc create: payload del RPC lleva coords approx (no exact en `motoposadas`); select de lista sin keys privadas (assert del select string) | Assert de select string en fake |

Command gates: `flutter test` (all) + `flutter analyze` (`config.yaml`: `apply.strict_tdd: true`, `verify.test_command`). La validación del floor ≥300 m en SQL se verifica por contrato (test del espejo Dart + assert del RPC) y manualmente en apply con `psql` (no hay infraestructura pgTAP en el repo). Reviewer fix: añadir un assert de contenido de migración en CI (grep de `haversine_distance` + `< 300` en `026_casa_motero.sql`) — el floor SQL es la frontera de seguridad y no tiene test automatizado directo. El cliente DEBE normalizar el teléfono (strip no-dígitos) ANTES de llamar al RPC (el regex SQL `^\+?[0-9]{7,15}$` rechaza espacios/guiones).

## 7. Migration / rollout

- Migración 026 aditiva: índice, tabla, RPCs, triggers. No toca CHECK existentes (`poi_type` sin constraint — precedente 024); no afecta filas no-casa_motero; `lat/lng` semántica intacta para los demás tipos.
- Deploy order: migración 026 ANTES del release de la app (el create RPC y el select de details dependen de ella).
- Rollback: `DROP TRIGGER …; DROP FUNCTION create_casa_motero/get_motoposada_whatsapp; DROP TABLE casa_motero_details; DROP INDEX uq_motoposadas_casa_motero_user;` + revertir UI (marker/card/form). Sin migración destructiva ni de datos.

## 8. Implementation order

| Fase | Trabajo | Rationale |
|------|---------|-----------|
| 1 | Migración 026 + `blur_coordinates.dart` + tests unit del jitter + payload | Fundación; desbloquea todo |
| 2 | `whatsapp_launcher.dart` + tests (URL, mensaje, fallback) | Capa pura, independiente |
| 3 | Eventos/estados/handlers del bloc + tests noSuchMethod (create/23505/eligibility/phone) | Lógica central |
| 4 | Form create/edición + My casa + tests widget (disclaimer, max-1, sin cédula, edit/toggle/delete) | CRUD consumible |
| 5 | Marker + card + rodar_screen + featured card + tests widget (M-MAPA-2/3, M-WA-1/2) | Último porque toca queries de lista y el mapa |

## 9. Open Questions

- [ ] `motoposadas.is_approved` (ad-hoc en prod, escrita por `_onCreateTouristPoi`, sin migración): ¿declararla en 026 con `ADD COLUMN IF NOT EXISTS` para que el trail coincida con prod? (casa_motero no la usa — verificar en apply)
- [ ] Convención de params nombrados de PostgREST para `get_motoposada_whatsapp(p_id)`: verificar que `{'p_id': id}` es el nombre de parámetro aceptado (fallback: posición/`id`).
- [ ] `canLaunchUrl` en wa.me sin app de WhatsApp instalada: típicamente true vía browser (wa.me cae a web) — el fallback cubre los casos false/throw; confirmar comportamiento en dispositivo en apply.
- [ ] Prod `users`/`profiles` ad-hoc: confirmar que `casa_motero_details.user_id` no choca con ningún objeto existente.
