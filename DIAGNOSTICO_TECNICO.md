# Diagnóstico Técnico — Moteros / AsfaltoClub

**Fecha:** Julio 16, 2026
**Stack:** Flutter (Dart) + Supabase (PostgreSQL 15) + PostgREST
**Repositorio:** `eabarriosTGC/Moteros` (GitHub)

---

## Síntomas reportados

1. **No deja crear raid** — El botón de crear raid falla, no se persiste en base de datos.
2. **No carga los botones del perfil** — La pantalla de perfil (Showcase) no renderiza las opciones de botones/vitrina.

---

## Resumen ejecutivo

Hay **dos bugs independientes** con causas raíz diferentes:

| # | Síntoma | Causa raíz | Tipo |
|---|---------|-----------|------|
| 1 | No crea raid | Columna `position` inexistente en INSERT + fallback RLS roto | Código + RLS |
| 2 | No carga perfil | Falta política RLS de INSERT en tabla `user_showcase` | RLS (política faltante) |

Ambos son bugs introducidos en el ciclo de desarrollo del 15-16 de julio. El problema #1 es evidente (columna fantasma en el INSERT), el #2 es una omisión en la migración 011.

---

## Problema #1: No deja crear raid

### Código que falla

**Archivo:** `lib/features/raids/presentation/bloc/raid_bloc.dart`, líneas 111-148

```dart
Future<void> _onCreateRaid(CreateRaid event, Emitter<RaidState> emit) async {
  emit(RaidLoading());
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final response = await Supabase.instance.client.from('raids').insert({
      'origin_lat': event.originLat,
      'origin_lng': event.originLng,
      'dest_lat': event.destLat,
      'dest_lng': event.destLng,
      'mode': event.gameMode,
      'scheduled_at': event.dateTime.toIso8601String(),
      'is_public': event.isPublic,
      'host_id': userId,
      'status': 'lobby',
      'description': event.title,
    }).select().single();

    final raid = response as Map<String, dynamic>;

    // ⚠️ AQUÍ FALLA: 'position' NO EXISTE en la tabla
    await Supabase.instance.client.from('raid_participants').insert({
      'raid_id': raid['id'],
      'user_id': userId,
      'is_ready': true,
      'position': 1,               // ← COLUMNA FANTASMA
    });

    emit(RaidLobby(/* ... */));
  } catch (e) {
    emit(RaidError(e.toString()));  // ← el error se muestra en UI
  }
}
```

### Qué pasa

1. El INSERT en `raids` **funciona** (RLS está deshabilitada en esta tabla por la migración 014).
2. El INSERT en `raid_participants` incluye el campo `'position': 1`, **pero la tabla `raid_participants` no tiene una columna `position`**. Tiene `finished_position INT` (para almacenar la posición final al terminar), pero no `position`.
3. PostgREST rechaza el INSERT con un error tipo: `"column 'position' of relation 'raid_participants' does not exist"`.
4. El catch emite `RaidError` y el raid ya creado en `raids` queda huérfano (sin participantes).

### Definición real de la tabla raid_participants

**Archivo:** `supabase/migrations/003_core_tables.sql`, líneas 129-151

```sql
CREATE TABLE IF NOT EXISTS raid_participants (
    id                BIGSERIAL PRIMARY KEY,
    raid_id           BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_ready          BOOLEAN DEFAULT FALSE,
    finished_position INT,           -- ← se llama finished_position, NO position
    xp_earned         INT DEFAULT 0,
    km_traveled       DOUBLE PRECISION DEFAULT 0.0,
    time_seconds      INT DEFAULT 0,
    checkpoints_taken INT DEFAULT 0,
    is_completed      BOOLEAN DEFAULT FALSE,
    last_lat          DOUBLE PRECISION,
    last_lng          DOUBLE PRECISION,
    last_heading      DOUBLE PRECISION,
    last_speed_kmh    DOUBLE PRECISION,
    last_position_at  TIMESTAMPTZ,
    livekit_token     TEXT,
    livekit_room      TEXT,
    anti_cheat_flags  INT NOT NULL DEFAULT 0,
    is_flagged        BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(raid_id, user_id)
);
```

**No existe la columna `position`.** La columna que almacena posición es `finished_position`.

### Fix propuesto

Opción A (mínima): Quitar `'position': 1` del INSERT en `raid_bloc.dart` línea 135.

```dart
await Supabase.instance.client.from('raid_participants').insert({
  'raid_id': raid['id'],
  'user_id': userId,
  'is_ready': true,
  // 'position': 1,   ← ELIMINAR esta línea
});
```

Opción B (si se necesita orden de llegada): Agregar migración que añada columna `position INT DEFAULT 0` y luego mantener el código actual.

---

## Problema #2: No carga los botones del perfil

### Código que falla

**Archivo:** `lib/features/showcase/data/datasources/showcase_remote_datasource.dart`, líneas 69-78

```dart
/// Upsert — create row if missing, update if exists.
Future<ShowcaseModel> ensureShowcase(String userId) async {
  final existing = await fetchShowcase(userId);
  if (existing != null) return existing;

  // ⚠️ ESTE INSERT FALLA: no hay política RLS de INSERT
  await _client.from('user_showcase').insert({
    'user_id': userId,
  });
  return (await fetchShowcase(userId))!;
}
```

**Archivo:** `lib/features/showcase/presentation/bloc/showcase_bloc.dart`, línea 68

```dart
// Ensure showcase row exists
final ensuredShowcase = showcase ?? await _ds.ensureShowcase(userId);
```

### Qué pasa

1. Al cargar el perfil, se hace `fetchShowcase(userId)` que hace un `SELECT` de `user_showcase`. El SELECT funciona (política `usc_select_public` permite lectura pública).
2. Si el usuario **no tiene** fila en `user_showcase` (usuario nuevo), `fetchShowcase` retorna `null`.
3. Se llama a `ensureShowcase(userId)` que intenta un `INSERT INTO user_showcase`.
4. **No existe política RLS de INSERT para `user_showcase`.** Solo existen SELECT y UPDATE.
5. PostgREST rechaza el INSERT con `403 Forbidden` o `"new row violates row-level security policy"`.
6. El catch en el BLoC emite `ShowcaseError` y **la pantalla de perfil muestra un error en vez de los botones**.

### Políticas RLS actuales de user_showcase

**Archivo:** `supabase/migrations/011_battle_pass_economy.sql`, líneas 251-256

```sql
ALTER TABLE user_showcase ENABLE ROW LEVEL SECURITY;
CREATE POLICY "usc_select_public" ON user_showcase FOR SELECT USING (true);
CREATE POLICY "usc_update_own" ON user_showcase FOR UPDATE USING (auth.uid() = user_id);
-- ❌ FALTA: CREATE POLICY "usc_insert_own" ON user_showcase FOR INSERT WITH CHECK (auth.uid() = user_id);
```

Hay SELECT (público) y UPDATE (propietario), pero **NO hay INSERT**.

### Fix propuesto

Agregar la política faltante en una nueva migración:

```sql
CREATE POLICY "usc_insert_own" ON user_showcase 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

---

## Contexto adicional: RLS Recursion (problema de fondo)

Aunque no es la causa directa de los síntomas actuales, existe un **tercer problema estructural** que afecta las tablas `raids` y `raid_participants`:

### Historial de fallos RLS

| Migración | Fecha | Acción |
|-----------|-------|--------|
| `007_rls.sql` | Original | Creó políticas con referencias circulares entre `raids` y `raid_participants` |
| `012_fix_rls_recursion.sql` | 15-jul | Eliminó políticas recursivas: `rp_select_raid_participants`, `raids_select_participant` |
| `013_fix_rls_recursion_v2.sql` | 15-jul | Recreó `rp_select_raid_host` usando función `SECURITY DEFINER` para romper recursión |
| `014_disable_rls_debug.sql` | 15-jul | **Deshabilitó RLS por completo** en `raids` y `raid_participants` como medida temporal |

### Estado actual

```sql
ALTER TABLE raid_participants DISABLE ROW LEVEL SECURITY;  -- RLS OFF
ALTER TABLE raids DISABLE ROW LEVEL SECURITY;              -- RLS OFF
```

Esto es una **medida temporal de debugging**. Las tablas no tienen protección RLS actualmente. Las políticas están rotas y necesitan ser rediseñadas desde cero con un enfoque que evite la recursión.

### Patrón de recursión (ya corregido parcialmente)

El problema original era:
```
raids_select_participant  →  SELECT de raid_participants  →  rp_select_raid_participants  →  SELECT de raid_participants  →  ∞
rp_select_raid_host       →  SELECT de raids              →  raids_select_participant    →  SELECT de raid_participants  →  ∞
```

---

## Tablas afectadas y sus dependencias

```
raids
├── host_id → users(id)
├── clan_id → clubs(id) [antes clans, renombrado en migración 010]
├── status CHECK: planned | lobby | active | completed | cancelled
└── mode CHECK: free_ride | rally | ruta_gotica | convoy | sobrevivencia | guerra_clanes

raid_participants
├── raid_id → raids(id) ON DELETE CASCADE
├── user_id → users(id) ON DELETE CASCADE
└── UNIQUE(raid_id, user_id)

user_showcase
├── user_id → users(id) ON DELETE CASCADE UNIQUE
└── RLS: SELECT ✓ | UPDATE ✓ | INSERT ✗
```

---

## Acciones recomendadas (orden de prioridad)

### Inmediatas (fixean los síntomas)

1. **Fix #1 (raid creation):** Quitar `'position': 1` de la línea 135 de `raid_bloc.dart` — o agregar columna `position` a la tabla.
2. **Fix #2 (perfil):** Crear migración con política `usc_insert_own` para `user_showcase`.

### Estructurales (después de los fixes inmediatos)

3. Rediseñar las políticas RLS de `raids` y `raid_participants` usando el patrón `SECURITY DEFINER` donde sea necesario, eliminando toda referencia circular.
4. Re-habilitar RLS en ambas tablas.
5. Revisar que las políticas que referencian `clan_members`/`clans` estén actualizadas post-renombre a `club_members`/`clubs` (migración 010).

---

## Archivos clave para el profesor

| Archivo | Contenido |
|---------|-----------|
| `lib/features/raids/presentation/bloc/raid_bloc.dart:111-148` | Código de creación de raid (bug #1) |
| `lib/features/showcase/data/datasources/showcase_remote_datasource.dart:69-78` | `ensureShowcase` - INSERT sin política (bug #2) |
| `supabase/migrations/003_core_tables.sql:97-154` | Definición de tablas `raids` y `raid_participants` |
| `supabase/migrations/007_rls.sql:159-197` | Políticas RLS originales |
| `supabase/migrations/011_battle_pass_economy.sql:224-256` | Tabla `user_showcase` + sus políticas |
| `supabase/migrations/012_fix_rls_recursion.sql` | Primer intento de fix RLS |
| `supabase/migrations/013_fix_rls_recursion_v2.sql` | Segundo intento (SECURITY DEFINER) |
| `supabase/migrations/014_disable_rls_debug.sql` | RLS deshabilitado (estado actual) |
| `supabase/migrations/010_comunidad_y_rutas.sql:16-21` | Renombre clans→clubs, clan_members→club_members |
