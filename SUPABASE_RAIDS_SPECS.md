# SDD Specs — AsfaltoClub: Battle Ride

> **Especificaciones detalladas de features:** User stories, escenarios Gherkin-like, acceptance criteria, data flows, edge cases y error states.
> **Documento basado en:** `SUPABASE_RAIDS_SDD.md` (2943 líneas)
> **Fecha:** Julio 2026
> **Autor:** Hermes Agent / Nous Research

---

## Tabla de contenidos

- [P0 — Fundación](#p0--fundación)
  - [F-01: Supabase Auth (email/password + Google OAuth)](#f-01-supabase-auth)
  - [F-02: Users table + profile setup](#f-02-users-table--profile-setup)
  - [F-03: Places CRUD](#f-03-places-crud)
  - [F-04: Clubs (clanes) CRUD + miembros + roles](#f-04-clubs-clanes-crud--miembros--roles)
  - [F-05: Raids CRUD + modos + participantes + lobby](#f-05-raids-crud--modos--participantes--lobby)
- [P1 — Core Gameplay](#p1--core-gameplay)
  - [F-06: Mapa en vivo con Realtime positions](#f-06-mapa-en-vivo-con-realtime-positions)
  - [F-07: Checkpoints + validación QR/GPS/foto](#f-07-checkpoints--validación-qrgpsfoto)
  - [F-08: Chat Realtime (raid + clan)](#f-08-chat-realtime-raid--clan)
  - [F-09: Post-raid stats + XP calculation](#f-09-post-raid-stats--xp-calculation)
  - [F-10: Safety-First: Rally time precision, Drive Score, Conducción mode](#f-10-safety-first)
- [P2 — Social + Progresión](#p2--social--progresión)
  - [F-11: Voice Chat (LiveKit) + TTS](#f-11-voice-chat-livekit--tts)
  - [F-12: Reputation system (trust score, mentor/rookie, conduct reports)](#f-12-reputation-system)
  - [F-13: XP + levels + streaks + achievements + leaderboards](#f-13-xp--levels--streaks--achievements--leaderboards)
  - [F-14: SOS crash detection + emergency alerts](#f-14-sos-crash-detection--emergency-alerts)
  - [F-15: Modo Espectador](#f-15-modo-espectador)
- [P3 — Monetización + Extra](#p3--monetización--extra)
  - [F-16: In-game economy (coins, shop, cosmetics)](#f-16-in-game-economy-coins-shop-cosmetics)
  - [F-17: Battle Pass estacional](#f-17-battle-pass-estacional)
  - [F-18: Dynamic context (weather, day/night)](#f-18-dynamic-context-weather-daynight)
  - [F-19: Anti-cheat system](#f-19-anti-cheat-system)
  - [F-20: Replay time-lapse](#f-20-replay-time-lapse)
  - [F-21: Clan territories](#f-21-clan-territories)
  - [F-22: Admin panel (moderación, reports, anti-cheat review)](#f-22-admin-panel)
- [P3+ — Integración existente](#p3--integración-existente)
  - [F-23: Refugios (allies)](#f-23-refugios-allies)
  - [F-24: Road Alerts](#f-24-road-alerts)
  - [F-25: Membresía (basic/premium)](#f-25-membresía-basicpremium)
  - [F-26: Follows (amigos)](#f-26-follows-amigos)
  - [F-27: Saved Routes](#f-27-saved-routes)
  - [F-28: Import OSM (Overpass)](#f-28-import-osm-overpass)

---

# P0 — Fundación

---

## Feature: Supabase Auth
**ID:** F-01
**Prioridad:** P0
**Dependencias:** Ninguna
**Descripción:** Sistema de autenticación de usuario usando Supabase Auth con dos métodos: email/password y Google OAuth. Reemplaza completamente Firebase Auth + JWT manual.

### User Stories
- Como motero, quiero registrarme con mi email y una contraseña para crear una cuenta en AsfaltoClub.
- Como motero, quiero iniciar sesión con Google para no tener que recordar otra contraseña.
- Como motero, quiero cerrar sesión cuando termine de usar la app.
- Como motero, quiero recuperar mi contraseña si la olvido para no perder mi progreso.
- Como usuario existente, quiero usar mi mismo email con una nueva contraseña (migración SHA256 → bcrypt) para no perder mi perfil.

### Escenarios

#### Escenario 1: Registro con email y contraseña exitoso
**Given** que soy un motero nuevo sin cuenta en AsfaltoClub
**When** completo el formulario de registro con un email válido y una contraseña de al menos 8 caracteres
**Then** se crea mi cuenta en Supabase Auth
**And** se crea automáticamente un perfil en la tabla `users` con mi UUID
**And** recibo un email de verificación
**And** veo la pantalla de "verifica tu email"

#### Escenario 2: Inicio de sesión con Google OAuth
**Given** que soy un motero con cuenta de Google
**When** selecciono "Iniciar sesión con Google"
**Then** veo el diálogo de selección de cuenta de Google
**And** al seleccionar mi cuenta, se crea/vincula mi perfil en Supabase Auth
**And** soy redirigido al dashboard principal

#### Escenario 3: Recuperación de contraseña
**Given** que soy un motero registrado que olvidó su contraseña
**When** hago clic en "Olvidé mi contraseña" e ingreso mi email
**Then** recibo un email con un magic link para restablecer mi contraseña
**And** al hacer clic en el link, puedo establecer una nueva contraseña

#### Escenario 4: Migración de usuarios existentes (SHA256 → bcrypt)
**Given** que soy un usuario existente con contraseña hasheada con SHA256
**When** intento iniciar sesión por primera vez en el nuevo sistema
**Then** Supabase Auth rechaza mi contraseña anterior
**And** veo un mensaje "Bienvenido a Battle Ride — creá tu nueva contraseña"
**And** recibo un magic link para establecer una nueva contraseña

#### Escenario 5: Sesión expirada
**Given** que tengo una sesión activa en AsfaltoClub
**When** mi token JWT expira (por inactividad prolongada)
**Then** la app detecta que el token es inválido
**And** soy redirigido a la pantalla de login
**And** no pierdo datos locales del raid en curso

### Acceptance Criteria
- [ ] Soporte para email/password + Google OAuth
- [ ] Registro crea perfil en `users` automático (trigger o callback post-signup)
- [ ] Manejo de sesión con refresh token automático de Supabase
- [ ] Pantalla de "verificar email" post-registro
- [ ] Flujo de "olvidé mi contraseña" funcional
- [ ] Migración de usuarios existentes (SHA256 → magic link)
- [ ] Cierre de sesión limpia todos los datos de sesión local
- [ ] Detección de sesión expirada y redirección a login

### Data Flow
```
[Flutter] → supabase.auth.signInWithPassword(email, password)
          → supabase.auth.signInWithOAuth('google')
          → supabase.auth.onAuthStateChange() listener
          → Session almacenada automáticamente por supabase_flutter
          → Callback post-signup: Edge Function/trigger crea registro en users(id, username)
```

### Edge Cases
- Usuario se registra con email ya existente → mensaje "email ya registrado"
- Google OAuth cancelado por el usuario → volver a pantalla de login sin error
- Sin conexión a Internet al intentar login → mensaje claro "sin conexión"
- Magic link expirado → mensaje "link expirado, solicita uno nuevo"
- Dos cuentas (email + Google) con el mismo email → Supabase las unifica por email automáticamente

### Error States
- `AuthError(code: 'email_taken')` → Mostrar toast: "Este email ya está registrado. Intentá iniciar sesión."
- `AuthError(code: 'invalid_credentials')` → Mostrar: "Email o contraseña incorrectos."
- `AuthError(code: 'weak_password')` → Mostrar: "La contraseña debe tener al menos 8 caracteres."
- `AuthError(code: 'provider_disabled')` → Google OAuth deshabilitado en configuración de Supabase.
- Conexión perdida durante login → Mostrar: "Sin conexión a Internet. Verificá tu conexión e intentá de nuevo."

---

## Feature: Users Table + Profile Setup
**ID:** F-02
**Prioridad:** P0
**Dependencias:** F-01 (Supabase Auth)
**Descripción:** Tabla `users` con perfil 1:1 con `auth.users`. Configuración de perfil: nombre, username único, foto de perfil, bio. Los datos públicos son visibles para todos (SELECT público); los privados solo para el usuario.

### User Stories
- Como motero, quiero elegir un username único para ser identificado en raids y leaderboards.
- Como motero, quiero subir una foto de perfil para personalizar mi cuenta.
- Como motero, quiero escribir una bio para que otros moteros sepan quién soy.
- Como motero, quiero editar mi perfil en cualquier momento.

### Escenarios

#### Escenario 1: Creación de perfil post-registro
**Given** que acabo de registrarme con email/password o Google OAuth
**When** es mi primer inicio de sesión
**Then** veo la pantalla de "completá tu perfil"
**And** puedo ingresar mi nombre completo, username, bio y foto de perfil
**And** si omito el setup, se me asigna un username autogenerado (ej: `motero_123`)

#### Escenario 2: Edición de perfil
**Given** que soy un usuario autenticado con perfil existente
**When** navego a la pantalla de edición de perfil
**Then** puedo modificar mi nombre, bio y foto de perfil
**And** el username SOLO puede cambiarse una vez cada 30 días
**And** los cambios se persisten en `users` vía RLS (UPDATE propio)

#### Escenario 3: Vista de perfil público de otro motero
**Given** que estoy viendo la lista de participantes de un raid
**When** toco el avatar de otro participante
**Then** veo su perfil público: username, nombre, bio, foto, nivel, logros públicos, raids completados
**And** NO veo su email, ubicación actual ni trust_score

### Acceptance Criteria
- [ ] Tabla `users` con 1:1 a `auth.users` y ON DELETE CASCADE
- [ ] SELECT público para datos básicos de perfil (username, avatar, level)
- [ ] UPDATE solo para el propietario del perfil
- [ ] Username único con restricción de cambio cada 30 días
- [ ] Foto de perfil subida a bucket `profile-images` con RLS
- [ ] Trigger post-signup que crea el registro en `users`

### Data Flow
```
[Registro] → auth.users creado → trigger: INSERT INTO users(id) VALUES (NEW.id)
[Setup] → supabase.from('users').upsert({ id, full_name, username, bio })
[Avatar] → supabase.storage.from('profile-images').upload('{userId}/avatar.jpg')
[Lectura] → supabase.from('users').select('username, full_name, profile_image, bio').eq('id', otherUserId)
```

### Edge Cases
- Username duplicado → error de unique constraint, sugerir alternativas
- Usuario intenta cambiar username antes de 30 días → mostrar fecha disponible
- Imagen de perfil > 5MB → rechazar con mensaje de tamaño máximo
- Usuario eliminado de auth.users → CASCADE elimina perfil en `users`

### Error States
- `duplicate key value violates unique constraint "users_username_key"` → "Este username ya está en uso. Probá con otro."
- Archivo de imagen muy grande → "La imagen debe pesar menos de 5 MB."
- Formato de imagen no soportado → "Solo se aceptan imágenes PNG, JPG o WebP."
- Username con caracteres no permitidos → "Solo letras, números y guiones bajos."

---

## Feature: Places CRUD
**ID:** F-03
**Prioridad:** P0
**Dependencias:** F-01 (Auth), F-02 (Users)
**Descripción:** Gestión de lugares (lugares existentes migrados a lat/lng). Un place es un punto geográfico con categoría (taller, restaurante, hotel, mirador, moto_posada, grua, reposteria, evento, otro) que puede ser destino de raid o checkpoint. Se migran los datos existentes agregando coordenadas geográficas.

### User Stories
- Como motero, quiero ver lugares cercanos en el mapa para elegir destinos de raids.
- Como motero, quiero crear un nuevo lugar (taller, restaurante, etc.) para compartirlo con la comunidad.
- Como motero, quiero editar un lugar que yo creé si los datos cambian.
- Como motero premium, quiero editar cualquier lugar para mantener la información actualizada.

### Escenarios

#### Escenario 1: Listar lugares cercanos
**Given** que estoy en el mapa principal de AsfaltoClub
**When** la app detecta mi ubicación actual
**Then** se muestran lugares dentro de un radio de 5 km usando un pre-filtro por bounding box + háversine
**And** puedo filtrar por categoría (taller, restaurante, etc.)
**And** cada lugar muestra: nombre, categoría, distancia desde mi posición

#### Escenario 2: Crear un lugar nuevo
**Given** que soy un usuario autenticado
**When** toco el botón "Agregar lugar" y completo nombre, categoría, dirección y selecciono ubicación en el mapa
**Then** se crea el lugar con mi UUID como `created_by`
**And** se genera un `qr_token` único automáticamente
**And** el lugar aparece en el mapa para todos los usuarios

#### Escenario 3: Editar un lugar propio
**Given** que soy el creador de un lugar
**When** edito su nombre, descripción o categoría
**Then** los cambios se persisten vía RLS (UPDATE donde created_by = auth.uid())
**And** el historial de raids que usaron este lugar como checkpoint NO se ve afectado

### Acceptance Criteria
- [ ] SELECT público para todos los lugares
- [ ] INSERT para cualquier usuario autenticado
- [ ] UPDATE para creador del lugar o usuarios premium
- [ ] DELETE solo para admin
- [ ] Búsqueda por proximidad usando bounding box + háversine
- [ ] QR token único generado automáticamente por lugar
- [ ] Migración de lugares existentes con lat/lng añadidos

### Data Flow
```
[Crear] → supabase.from('places').insert({ name, category, latitude, longitude, qr_token: uuid() })
[Listar cercanos] → supabase.rpc('get_nearby_places', { p_lat, p_lng, p_radius_meters })
                   → Filtro: lat BETWEEN p_lat-Δ AND p_lat+Δ AND lng BETWEEN p_lng-Δ AND p_lng+Δ
                   → Post-filtro: haversine_distance() <= p_radius_meters
[Editar] → supabase.from('places').update({ name, description }).eq('id', placeId).eq('created_by', userId)
```

### Edge Cases
- Lugar con coordenadas (0,0) → filtrar como inválido, no mostrar en mapa
- Dos lugares con la misma ubicación exacta → ambos se muestran, UX resuelve con cluster
- Usuario intenta crear lugar sin conexión → fallar con mensaje, no cachear
- Categoría no válida → validación CHECK en DB, rechazar cliente-side también

### Error States
- Ubicación no seleccionada en mapa → "Seleccioná una ubicación en el mapa."
- Nombre vacío → "El nombre del lugar es obligatorio."
- Error de migración (place sin lat/lng) → marcar como "pendiente de geolocalización"

---

## Feature: Clubs (Clanes) CRUD + Miembros + Roles
**ID:** F-04
**Prioridad:** P0
**Dependencias:** F-01 (Auth), F-02 (Users)
**Descripción:** Sistema de clanes (grupos de moteros) con creación, membresía, roles jerárquicos (founder → captain → rider → recruit), logo, descripción y chat privado. Los clanes pueden ser públicos (cualquiera se une) o privados (solo por invitación).

### User Stories
- Como motero, quiero crear un clan para reunir a mis amigos moteros.
- Como motero, quiero buscar y unirme a clanes públicos para conocer nuevos riders.
- Como fundador de un clan, quiero asignar roles (captain/rider/recruit) para organizar la jerarquía.
- Como capitán de un clan, quiero expulsar miembros problemáticos.
- Como miembro de un clan, quiero ver la lista de miembros y sus roles.
- Como recluta, quiero ser promovido a rider después de demostrar compromiso.

### Escenarios

#### Escenario 1: Creación de clan
**Given** que soy un usuario autenticado sin clan
**When** completo el formulario de creación con nombre, tag (máx 10 chars), descripción y subo un logo
**Then** se crea el clan con `founder_id = auth.uid()`
**And** soy automáticamente añadido a `clan_members` con rol `founder`
**And** el clan aparece en la lista de clanes públicos

#### Escenario 2: Unirse a un clan público
**Given** que soy un usuario autenticado sin clan
**When** toco "Unirse" en la página de un clan público que no está lleno
**Then** se inserta un registro en `clan_members` con rol `recruit`
**And** los miembros del clan ven mi incorporación en el chat del clan

#### Escenario 3: Cambio de rol por fundador
**Given** que soy el fundador de un clan
**When** promuevo a un recruit a rider
**Then** el rol se actualiza vía RLS (UPDATE en clan_members por fundador)
**And** el miembro recibe una notificación del cambio

#### Escenario 4: Límite de miembros alcanzado
**Given** que un clan tiene 50 miembros (max_members)
**When** un nuevo usuario intenta unirse
**Then** la operación es rechazada
**And** ve el mensaje "El clan alcanzó el límite de miembros"

### Acceptance Criteria
- [ ] Creación de clan con founder_id, nombre único, tag único, logo opcional
- [ ] Unión a clanes públicos (RLS: INSERT donde clan.is_public = true)
- [ ] Roles: founder (1), captain (N), rider (N), recruit (N)
- [ ] Cambio de roles solo por founder
- [ ] Expulsión de miembros por founder/captain
- [ ] Salida voluntaria de miembros (DELETE propio)
- [ ] SELECT público de clanes con is_public = true
- [ ] SELECT de miembros para miembros del clan
- [ ] Chat de clan persistente (clan_messages)

### Data Flow
```
[Crear] → INSERT INTO clans (name, tag, founder_id, is_public, max_members)
         → INSERT INTO clan_members (clan_id, user_id, role='founder')
[Unirse] → INSERT INTO clan_members (clan_id, user_id, role='recruit')
[Roles] → UPDATE clan_members SET role='rider' WHERE clan_id=X AND user_id=Y
          (RLS verifica que quien ejecuta es founder del clan)
[Expulsar] → DELETE FROM clan_members WHERE clan_id=X AND user_id=Y
[Listar] → SELECT FROM clans WHERE is_public=true
[Miembros] → SELECT FROM clan_members WHERE clan_id=X
```

### Edge Cases
- Usuario ya miembro de un clan intenta unirse a otro → UNIQUE constraint lo bloquea
- Fundador intenta salirse del clan → debe transferir fundador primero o eliminar el clan
- Clan sin miembros (todos se fueron) → el clan existe pero sin actividad; se puede eliminar tras 30 días
- Tag de clan duplicado → validación UNIQUE en DB
- Nombre de clan duplicado → validación UNIQUE en DB
- Logo > 2MB → rechazar

### Error States
- `duplicate key value violates unique constraint "clans_name_key"` → "Ya existe un clan con ese nombre."
- `duplicate key value violates unique constraint "clans_tag_key"` → "Ese tag ya está en uso."
- Límite de miembros alcanzado → "El clan está lleno (máximo 50 miembros)."
- Fundador intenta salir → "Transferí la fundación a otro miembro antes de irte."
- Solo founder puede cambiar roles → RLS rechaza, UI oculta botón

---

## Feature: Raids CRUD + Modos + Participantes + Lobby
**ID:** F-05
**Prioridad:** P0
**Dependencias:** F-01 (Auth), F-02 (Users), F-03 (Places)
**Descripción:** Sistema central de raids (partidas multijugador). Ciclo de vida: planned → lobby → active → completed → post-raid. Soporta 6 modos de juego: Free Ride, Rally, Ruta Gótica, Convoy, Sobrevivencia, Guerra de Clanes. El lobby permite ready-up, ver participantes, y el host inicia cuando todos están listos.

### User Stories
- Como motero, quiero crear un raid con origen, destino, modo y fecha para invitar a otros riders.
- Como motero, quiero ver raids públicos disponibles para unirme a rutas interesantes.
- Como motero, quiero unirme a un raid en lobby para prepararme con el grupo.
- Como host del raid, quiero ver quién está listo antes de iniciar.
- Como participante, quiero marcar que estoy listo para que el host sepa que puede empezar.
- Como motero, quiero elegir entre 6 modos de juego para diferentes experiencias.

### Escenarios

#### Escenario 1: Creación de raid exitosa
**Given** que soy un usuario autenticado
**When** completo el formulario de creación con: origen (mapa), destino (mapa o place), modo (Free Ride), fecha/hora, público/privado, descripción opcional
**Then** se inserta un raid con status `planned`, `host_id = auth.uid()`
**And** soy añadido automáticamente como participante con `is_ready = false`
**And** el raid aparece en la lista de raids públicos (si es público)

#### Escenario 2: Unirse a un raid público en lobby
**Given** que existe un raid público en estado `lobby` con plazas disponibles
**When** toco "Unirse al raid"
**Then** se inserta mi registro en `raid_participants` con `is_ready = false`
**And** todos los participantes ven mi incorporación via Realtime (lobby broadcast)
**And** veo el lobby con la lista actualizada de participantes

#### Escenario 3: Ready-up y inicio del raid
**Given** que estoy en el lobby de un raid donde soy host
**When** marco "Listo" (ready)
**Then** mi `is_ready` se actualiza a true
**When** todos los participantes están listos
**Then** el host ve habilitado el botón "Iniciar raid"
**When** el host toca "Iniciar raid"
**Then** el raid pasa a estado `active`
**And** todos los participantes reciben una notificación Realtime `raid_started`
**And** se navega automáticamente a la pantalla de mapa en vivo

#### Escenario 4: Cancelar raid por el host
**Given** que soy host de un raid en estado `planned` o `lobby`
**When** selecciono "Cancelar raid"
**Then** el raid pasa a estado `cancelled`
**And** todos los participantes reciben notificación
**And** no se otorga XP a nadie

#### Escenario 5: Salirse de un raid
**Given** que soy participante de un raid en estado `lobby`
**When** selecciono "Salirme del raid"
**Then** mi registro se elimina de `raid_participants`
**And** los demás participantes ven mi salida via Realtime

### Acceptance Criteria
- [ ] INSERT raid con RLS (auth.uid() = host_id)
- [ ] 6 modos de juego validados por CHECK constraint
- [ ] Ciclo planned → lobby → active → completed → (cancelled cualquier estado previo)
- [ ] INSERT participante con RLS (auth.uid() = user_id, raid.status = lobby, plazas disponibles)
- [ ] UPDATE is_ready por el propio participante
- [ ] UPDATE raid.status por el host
- [ ] DELETE participante por sí mismo
- [ ] DELETE raid por el host (solo si status es planned o lobby)
- [ ] Realtime lobby channel: user_joined, user_left, ready_changed, raid_started
- [ ] SELECT raids públicos en estado lobby para lista de descubrimiento

### Data Flow
```
[Crear] → INSERT raids (host_id, origin_lat/lng, dest_lat/lng, mode, scheduled_at, status='planned')
         → INSERT raid_participants (raid_id, user_id, is_ready=false)
[Unirse] → SELECT raids WHERE id=X AND status='lobby' AND is_public=true
           → Verificar count(participants) < max_participants
           → INSERT raid_participants (raid_id, auth.uid())
           → Broadcast: { event: 'user_joined', payload: { user_id, username } }
[Ready] → UPDATE raid_participants SET is_ready=true WHERE user_id=auth.uid() AND raid_id=X
         → Broadcast: { event: 'ready_changed', payload: { user_id, is_ready: true } }
[Iniciar] → UPDATE raids SET status='active' WHERE id=X AND host_id=auth.uid() AND status='lobby'
           → Broadcast: { event: 'raid_started', payload: { raid_id, started_at } }
[Cancelar] → UPDATE raids SET status='cancelled' WHERE id=X AND host_id=auth.uid()
```

### Edge Cases
- Host inicia raid sin que todos estén listos → botón deshabilitado hasta ready universal
- Raid con un solo participante (el host) → puede iniciar igualmente (ready automático)
- Raid privado: solo puede unirse si el host invita (RLS verifica)
- Fecha del raid en el pasado → validar creación: scheduled_at > now()
- Participante se une a raid lleno → rechazar con "raid completo"
- Host abandona el lobby → si no hay otro host, el raid se cancela automáticamente tras 5 min
- Modo Sobrevivencia: requisito mínimo de 2 participantes → validar al iniciar

### Error States
- Raid lleno → "El raid alcanzó el máximo de participantes."
- Raid ya iniciado → "Este raid ya está en curso."
- Fecha en el pasado → "La fecha del raid debe ser futura."
- Usuario ya participa → "Ya sos parte de este raid."
- Solo host puede iniciar → "Solo el organizador puede iniciar el raid."
- Modo Sobrevivencia requiere 2+ → "Se necesitan al menos 2 participantes para Sobrevivencia."

---

# P1 — Core Gameplay

---

## Feature: Mapa en Vivo con Realtime Positions
**ID:** F-06
**Prioridad:** P1
**Dependencias:** F-05 (Raids), Realtime habilitado en Supabase
**Descripción:** Durante un raid activo, las posiciones de todos los participantes se transmiten cada 5 segundos via Realtime Broadcast. El mapa en vivo muestra avatares, heading (dirección), velocidad y distancia al destino. Los pings en mapa (tipo Apex/Fortnite) permiten marcar puntos de interés.

### User Stories
- Como participante de un raid, quiero ver en el mapa dónde están los demás riders para coordinar la ruta.
- Como participante, quiero ver la velocidad y dirección de cada rider para saber si alguien se quedó atrás.
- Como participante, quiero marcar un punto en el mapa (peligro, POI) para alertar al grupo.
- Como participante, quiero ver pings de otros riders en tiempo real.

### Escenarios

#### Escenario 1: Transmisión de posición en vivo
**Given** que soy participante de un raid activo
**When** mi GPS reporta una nueva posición
**Then** cada 5 segundos se envía un broadcast al canal `raid:{id}:positions`
**And** todos los participantes reciben mi posición actualizada
**And** mi avatar en el mapa se mueve suavemente (interpolación) a la nueva posición

#### Escenario 2: Visualización de participantes en el mapa
**Given** que estoy en el mapa en vivo de un raid activo
**When** recibo posiciones de otros participantes
**Then** veo marcadores con: avatar del rider, heading (flecha), velocidad en km/h, nombre
**And** los colores de los marcadores varían según la velocidad (verde < 40, amarillo 40-80, rojo > 80 km/h)

#### Escenario 3: Envío de ping en el mapa
**Given** que soy participante de un raid activo
**When** mantengo presionado un punto en el mapa y selecciono tipo de ping (peligro, check, waypoint)
**Then** se envía un mensaje de tipo `ping` en el chat del raid con lat/lng
**And** aparece un marcador temporal en el mapa de todos los participantes
**And** el ping desaparece después de 30 segundos

#### Escenario 4: Speed threshold — modo conducción afecta mapa
**Given** que voy a más de 15 km/h durante un raid activo
**When** la app detecta mi velocidad
**Then** el mapa sigue mostrándose pero sin botones táctiles pequeños
**And** solo puedo enviar pings por comando de voz

### Acceptance Criteria
- [ ] Broadcast de posición cada 5s con lat, lng, heading, speed_kmh, timestamp
- [ ] Payload comprimido (claves cortas: p, lt, ln, h, s, ts)
- [ ] Throttling: no enviar si posición cambió < 10m
- [ ] Subtítulo: selfBroadcast=false (no recibir propia posición)
- [ ] Interpolación suave de movimiento en el mapa
- [ ] Marcadores con avatar, heading, velocidad, nombre
- [ ] Pings en mapa: tipo peligro/check/waypoint con timeout de 30s
- [ ] Speed threshold para modo conducción afecta interacción

### Data Flow
```
[Broadcast posición] → Timer.periodic(5s):
                        pos = await Geolocator.getCurrentPosition()
                        channel.send(type: 'broadcast', event: 'position', payload: {
                          p: participantId, lt: pos.latitude, ln: pos.longitude,
                          h: pos.heading, s: pos.speed * 3.6, ts: now().toIso8601()
                        })
[Recepción] → channel.on('broadcast', {event: 'position'}, (payload) {
                emit(LiveMapPositionUpdated(payload))
              })
[Ping] → supabase.from('raid_messages').insert({
           raid_id, user_id, message: '⚠️ Peligro en ruta', type: 'ping', lat, lng
         })
         → Realtime broadcast del mensaje
         → Cliente escucha: si type=pint, muestra marcador temporal
```

### Edge Cases
- Participante pierde conexión → su última posición se muestra con badge "📡 Sin señal"
- Participante reconecta → su posición salta a la actual (interpolación suave del lado cliente)
- GPS no disponible → mostrar badge "📍 GPS no disponible" en su marcador
- Velocidad negativa (error de GPS) → ignorar lecturas donde speed < 0
- Heading = null → mostrar marcador sin flecha de dirección
- Múltiples participantes en el mismo punto → cluster de marcadores

### Error States
- Sin permiso de ubicación → "Activá la ubicación para participar en raids en vivo."
- GPS con baja precisión (> 50m) → mostrar badge "Precisión baja" en el marcador
- Error de suscripción Realtime → reintentar con backoff exponencial
- Broadcast falla por límite de rate → buffer local y reintentar

---

## Feature: Checkpoints + Validación QR/GPS/Foto
**ID:** F-07
**Prioridad:** P1
**Dependencias:** F-05 (Raids), F-03 (Places), Edge Function `validate_checkpoint`
**Descripción:** Durante un raid activo, los participantes deben capturar checkpoints en ruta. Validación híbrida: QR + GPS (< radio configurable, default 50m) + foto opcional. La Edge Function `validate_checkpoint` procesa la validación y otorga XP.

### User Stories
- Como host, quiero definir checkpoints en la ruta para que los riders los vayan capturando.
- Como participante, quiero escanear un QR en un checkpoint para validar mi paso.
- Como participante, quiero tomar una foto como evidencia de mi paso por un checkpoint.
- Como participante en un checkpoint sin QR, quiero que se valide solo con GPS.
- Como host de Ruta Gótica, quiero marcar checkpoints como ocultos para que los riders los descubran.

### Escenarios

#### Escenario 1: Validación GPS + QR exitosa
**Given** que estoy en un raid activo y llego a la ubicación de un checkpoint
**When** escaneo el código QR del checkpoint con la cámara
**Then** la app envía a la Edge Function: raid_id, checkpoint_id, qr_code, latitud, longitud
**And** la EF verifica: raid activo, distancia < radius_meters, QR code coincide
**And** se inserta `raid_checkpoint_verifications` con is_valid = true
**And** recibo XP (+30 base)
**And** veo confirmación: "Checkpoint capturado ✓"

#### Escenario 2: Validación solo GPS
**Given** que estoy en un checkpoint sin QR en un raid activo
**When** la app detecta que estoy a < 50m del checkpoint
**Then** aparece un botón "Capturar checkpoint"
**When** toco el botón
**Then** la EF valida distancia y registra la verificación
**And** recibo XP

#### Escenario 3: Validación con foto
**Given** que estoy en un checkpoint en un raid activo
**When** tomo una foto como evidencia
**Then** la foto se sube a `checkpoint-evidence` bucket
**And** la URL se envía a la EF `validate_checkpoint`
**And** la EF incluye la validación EXIF (GPS + timestamp) como capa adicional anti-cheat

#### Escenario 4: Fuera de rango de GPS
**Given** que intento capturar un checkpoint
**When** mi distancia al checkpoint es > radius_meters (ej. 80m cuando el radio es 50m)
**Then** la EF retorna valid: false, message: "Muy lejos del checkpoint"
**And** no se otorga XP
**And** veo la distancia actual en metros

#### Escenario 5: Checkpoint oculto (Ruta Gótica)
**Given** que estoy en un raid modo Ruta Gótica
**When** el checkpoint tiene is_hidden = true
**Then** no aparece en el mapa hasta que estoy a < 200m del mismo
**And** al descubrirlo, recibo XP extra (+30 por checkpoint oculto)

### Acceptance Criteria
- [ ] CRUD de raid_checkpoints por el host
- [ ] Checkpoints con sort_order (orden de ruta)
- [ ] Radio configurable por checkpoint (default 50m)
- [ ] Checkpoints ocultos (is_hidden) para Ruta Gótica
- [ ] QR code opcional por checkpoint
- [ ] Edge Function validate_checkpoint: verifica raid activo, distancia, QR, foto
- [ ] Verificación única por participante por checkpoint (UNIQUE constraint)
- [ ] XP otorgado vía award_xp()
- [ ] Foto subida a checkpoint-evidence bucket
- [ ] Método de validación registrado (gps, qr, gps+qr, photo)
- [ ] Checkpoints ligados opcionalmente a places existentes

### Data Flow
```
[Edge Function: validate_checkpoint]
POST /validate_checkpoint
Body: { raid_id, checkpoint_id, qr_code?, latitude, longitude, photo_url? }

1. Verificar raids.status = 'active' → si no: 400 "Raid no está activo"
2. Verificar raid_participants.exists → si no: 403 "No sos participante"
3. Obtener raid_checkpoints (lat, lng, radius_meters, qr_code)
4. distance = haversine(lat_user, lng_user, cp.lat, cp.lng)
5. if distance > cp.radius_meters → 200 { valid: false, "Muy lejos" }
6. if cp.qr_code AND qr_code != cp.qr_code → 200 { valid: false, "QR incorrecto" }
7. INSERT raid_checkpoint_verifications (is_valid=true)
8. UPDATE raid_participants SET checkpoints_taken += 1
9. award_xp(p_user_id, 30)
10. RETURN { valid: true, xp_awarded: 30, distance_meters: distance }
```

### Edge Cases
- Múltiples checkpoints en la misma ubicación → sort_order determina el orden
- Participante intenta capturar el mismo checkpoint dos veces → UNIQUE constraint lo bloquea
- Checkpoint sin QR, sin foto y GPS disponible → validación solo GPS
- Foto sin EXIF GPS → FLAG anti-cheat (posible foto de galería)
- Checkpoint pertenece a raid cancelado → EF rechaza porque raids.status != 'active'
- QR code de checkpoint escaneado por otro raid → no hay colisión porque el QR se valida contra el checkpoint específico
- Checkpoint validado offline → se guarda localmente, se sincroniza al reconectar

### Error States
- QR incorrecto → "Código QR incorrecto. Verificá que sea el checkpoint correcto."
- Muy lejos del checkpoint → "Estás a [X] metros del checkpoint. Acercate más."
- Checkpoint ya capturado → "Ya capturaste este checkpoint anteriormente."
- Raid no está activo → "El raid no está en curso."
- Foto demasiado grande → "La foto debe pesar menos de 10 MB."
- Error de cámara → "No se pudo acceder a la cámara. Verificá los permisos."

---

## Feature: Chat Realtime (Raid + Clan)
**ID:** F-08
**Prioridad:** P1
**Dependencias:** F-04 (Clanes), F-05 (Raids), Realtime habilitado
**Descripción:** Sistema de chat en tiempo real con persistencia. Dos contextos: raid (solo participantes del raid activo) y clan (solo miembros del clan). Los mensajes se persisten en `raid_messages` y `clan_messages` y se replican via Realtime Broadcast.

### User Stories
- Como participante de un raid, quiero chatear con los demás riders para coordinar la ruta.
- Como miembro de un clan, quiero un chat permanente para hablar con mis compañeros.
- Como participante, quiero recibir mensajes del raid en tiempo real sin refrescar la pantalla.

### Escenarios

#### Escenario 1: Enviar mensaje en chat de raid
**Given** que soy participante de un raid activo
**When** escribo un mensaje y presiono enviar
**Then** el mensaje se inserta en `raid_messages` con mi user_id
**And** se replica via Realtime a todos los participantes del raid
**And** veo el mensaje en el chat inmediatamente

#### Escenario 2: Enviar mensaje en chat de clan
**Given** que soy miembro de un clan
**When** escribo un mensaje en el chat del clan
**Then** el mensaje se inserta en `clan_messages`
**And** se replica via Realtime a todos los miembros online del clan

#### Escenario 3: Modo conducción bloquea chat
**Given** que voy a > 15 km/h durante un raid
**When** intento abrir el chat del raid
**Then** la interfaz de escritura está bloqueada
**And** los mensajes entrantes se leen por TTS automáticamente

#### Escenario 4: Eliminar mensaje propio
**Given** que envié un mensaje en el chat del raid/clan
**When** mantengo presionado mi mensaje y selecciono "Eliminar"
**Then** el mensaje se elimina de la base de datos vía RLS (DELETE propio)
**And** los demás participantes ven el mensaje eliminado (placeholder "mensaje eliminado")

### Acceptance Criteria
- [ ] INSERT en raid_messages con RLS (auth.uid()=user_id Y participante del raid)
- [ ] INSERT en clan_messages con RLS (auth.uid()=user_id Y miembro del clan)
- [ ] SELECT para participantes del raid / miembros del clan
- [ ] DELETE propio
- [ ] Realtime broadcast en canal `raid:{id}:chat` y `clan:{id}:chat`
- [ ] Persistencia en DB (historial cargado al abrir chat)
- [ ] Tipo de mensaje: text, ping, system
- [ ] Bloqueo de escritura a > 15 km/h (modo conducción)
- [ ] TTS de mensajes entrantes en modo conducción

### Data Flow
```
[Enviar raid] → supabase.from('raid_messages').insert({
                  raid_id, user_id, message, type: 'text'
                })
                → RLS permite INSERT si user_id=auth.uid() AND es participante del raid
                → Realtime replica a canal raid:{id}:chat
[Enviar clan] → supabase.from('clan_messages').insert({
                  clan_id, user_id, message
                })
                → RLS permite INSERT si user_id=auth.uid() AND es miembro del clan
                → Realtime replica a canal clan:{id}:chat
[Historial] → supabase.from('raid_messages').select('*')
              .eq('raid_id', id).order('created_at').limit(50)
```

### Edge Cases
- Usuario no participante intenta enviar mensaje en raid → RLS bloquea
- Mensaje vacío → validación cliente-side, no enviar
- Usuario envía mensaje sin conexión → almacenar en buffer local, enviar al reconectar
- Muchos mensajes (> 100) en raid largo → paginación (cargar 50 más al scrollear arriba)
- Miembro expulsado del clan → ya no puede enviar mensajes (RLS bloquea)

### Error States
- Mensaje no enviado por error de red → "Mensaje no enviado. Reintentar." con botón de reintento
- Contenido del mensaje muy largo → "El mensaje no puede superar los 500 caracteres."
- RLS bloquea INSERT → "No tenés permiso para enviar mensajes en este chat."
- Error de Realtime subscription → los mensajes aparecen al recargar (persistencia DB)

---

## Feature: Post-Raid Stats + XP Calculation
**ID:** F-09
**Prioridad:** P1
**Dependencias:** F-05 (Raids), F-06 (Mapa en vivo), F-07 (Checkpoints), Edge Function `finish_raid`
**Descripción:** Al finalizar un raid, la Edge Function `finish_raid` calcula XP total (según modo, checkpoints capturados, bonus, multiplicador de racha), actualiza estadísticas, verifica achievements y genera snapshot de leaderboard. El host obtiene un resumen post-raid con stats de todos los participantes.

### User Stories
- Como host, quiero finalizar el raid para que todos reciban su XP y estadísticas.
- Como participante, quiero ver mis stats post-raid: km, tiempo, velocidad, checkpoints capturados, XP ganado.
- Como participante, quiero saber mi posición final (Rally: clasificación por precisión de ETA).
- Como participante, quiero recibir bonus por completar todos los checkpoints.

### Escenarios

#### Escenario 1: Finalizar raid como host (modo Free Ride)
**Given** que soy host de un raid activo modo Free Ride
**When** todos llegaron al destino (o decido finalizar)
**Then** la EF `finish_raid` se ejecuta
**And** calcula XP base = 10 para cada participante
**And** si un participante capturó todos los checkpoints: +50 bonus
**And** si es el primer raid del día: +20 bonus
**And** aplica multiplicador por racha (2× si streak ≥ 3, 3× si streak ≥ 7)
**And** actualiza `raid_participants` con xp_earned, km_traveled, time_seconds, is_completed
**And** el raid pasa a status `completed`

#### Escenario 2: Finalizar raid Rally — ganador por precisión ETA
**Given** que soy host de un raid Rally activo
**When** finalizo el raid
**Then** la EF calcula la diferencia abs entre tiempo real y tiempo objetivo para cada participante
**And** el ganador es quien tiene la menor diferencia (no el más rápido)
**And** XP base = 25, ganador recibe +50 extra

#### Escenario 3: Ver stats post-raid
**Given** que el raid está en estado `completed`
**When** navego a la pantalla de resultados
**Then** veo: km recorridos, tiempo total, velocidad promedio/máx, checkpoints capturados, XP ganado
**And** veo la posición final (en modo Rally)
**And** veo el XP total de cada participante (tabla de clasificación del raid)

### Acceptance Criteria
- [ ] Edge Function finish_raid ejecutable solo por el host
- [ ] Verifica raids.status = 'active' antes de finalizar
- [ ] Calcula XP por modo según tabla del SDD (sección 9.1)
- [ ] Calcula bonus por checkpoints completos, primer raid del día
- [ ] Aplica multiplicador de racha (2×/3×)
- [ ] Actualiza raid_participants con stats individuales
- [ ] Actualiza user_xp (km_traveled, raids_completed, checkpoints_captured)
- [ ] Asigna finished_position según modo
- [ ] Verifica achievements via trigger en user_xp
- [ ] Genera/actualiza leaderboard snapshots

### Data Flow
```
[finish_raid EF]
POST /finish_raid Auth: Bearer <jwt>
Body: { raid_id }

1. Verificar auth.uid() = raids.host_id → si no: 403
2. Verificar raids.status = 'active' → si no: 400
3. Para cada raid_participants con is_completed=true:
   a. Calcular base_xp según modo (table 9.1)
   b. Bonus checkpoints: si checkpoints_taken = total_checkpoints → +50
   c. Bonus primer_día: si last_raid_date < today → +20
   d. Multiplicador racha: SELECT current_streak FROM user_xp
   e. final_xp = (base_xp + bonus) * multiplier
   f. award_xp(p_user_id, final_xp)
   g. UPDATE raid_participants SET xp_earned=final_xp, is_completed=true
4. Si modo=Rally: ordenar por ABS(real_time - target_eta), asignar finished_position
5. UPDATE raids SET status='completed'
6. RETURN { completed: true, xp_distributed: total, participants_completed: N }
```

### Edge Cases
- Participante no completó el raid (abandonó) → no recibe XP, is_completed = false
- Todos abandonaron menos el host → host recibe XP base, raid se completa igual
- Modo Rally sin ETA definido → XP base sin bonus de ganador
- Raid completado en menos tiempo del mínimo de seguridad → log interno, sin penalización
- Error en award_xp para un participante → loggear error, continuar con los demás

### Error States
- Solo el host puede finalizar → "Solo el organizador puede finalizar el raid."
- Raid no está activo → "El raid ya fue finalizado o cancelado."
- Error al otorgar XP → "Hubo un error al calcular XP. Contactá a soporte."
- Sin participantes completados → "Nadie completó el raid. ¿Estás seguro de finalizar?"

---

## Feature: Safety-First
**ID:** F-10
**Prioridad:** P1
**Dependencias:** F-05 (Raids), F-06 (Mapa en vivo), F-09 (Post-raid stats)
**Descripción:** Rediseño de modos para priorizar seguridad. Rally se basa en precisión de ETA (no velocidad), Drive Score evalúa estilo de conducción (0-100) post-raid, y modo Conducción bloquea interacción visual a > 15 km/h con interacción solo por TTS/voz.

### User Stories
- Como motero responsable, quiero que el Rally premie la precisión, no la velocidad.
- Como motero, quiero saber mi Drive Score para mejorar mi estilo de conducción.
- Como motero, quiero que la app bloquee distracciones cuando voy rápido.
- Como motero, quiero recibir alertas de audio en lugar de notificaciones visuales mientras conduzco.

### Escenarios

#### Escenario 1: Rally por precisión ETA
**Given** que creo un raid modo Rally
**When** completo la creación con origen y destino
**Then** la app consulta OSRM para obtener límites de velocidad de la ruta
**And** calcula un ETA realista basado en distancia y límites de velocidad por tramo
**When** el raid inicia, el tiempo objetivo se anuncia por TTS
**When** el raid finaliza
**Then** el ganador es quien tiene menor |tiempo_real - tiempo_objetivo|
**And** llegar antes penaliza igual que llegar después

#### Escenario 2: Drive Score post-raid
**Given** que completé un raid
**When** veo mis stats post-raid
**Then** veo mi Drive Score (0-100) con desglose: frenadas (30%), aceleración (25%), velocidad constante (25%), respeto límites (20%)
**And** veo recomendaciones: "Evitá frenadas bruscas", "Mantené velocidad constante"

#### Escenario 3: Modo Conducción bloquea interacción
**Given** que voy a > 15 km/h durante un raid
**When** la app detecta la velocidad por > 5 segundos
**Then** la interfaz táctil se bloquea (botones, teclado, chat)
**And** solo queda visible el mapa (sin interacción)
**And** las notificaciones se entregan por TTS
**When** la velocidad baja a < 5 km/h por > 10 segundos
**Then** la interfaz vuelve gradualmente

#### Escenario 4: Alertas TTS en modo conducción
**Given** que estoy en modo conducción (> 15 km/h)
**When** hay un checkpoint próximo a 3 km
**Then** escucho por TTS: "Checkpoint a 3 kilómetros en la ruta actual"
**When** alguien se desvió de la ruta
**Then** escucho: "[Nombre] se ha desviado de la ruta"

### Acceptance Criteria
- [ ] Rally: ETA calculado con OSRM + límites de velocidad
- [ ] Rally: ganador por |real - objetivo|, no por velocidad
- [ ] Rally: condiciones climáticas ajustan ETA (+15% lluvia, +25% fuerte, etc.)
- [ ] Drive Score: 4 componentes con pesos (30/25/25/20)
- [ ] Drive Score almacenado en `drive_scores` por raid_participant
- [ ] Modo Conducción: umbrales 5 km/h (normal), 5-15 (reducido), >15 (bloqueado)
- [ ] Bloqueo táctil automático al superar >15 km/h por 5s
- [ ] Vuelta gradual al detenerse <5 km/h por 10s
- [ ] TTS pipeline para eventos críticos
- [ ] Audio cues cacheados localmente

### Data Flow
```
[Calculo ETA Rally]
1. GET /route/v1/driving/{origin_lng},{origin_lat};{dest_lng},{dest_lat}?overview=false
2. Extraer speed_limits por segmento (donde disponibles en OSM)
3. ETA_segundo = distancia_segmento / speed_limit_segmento
4. ETA_total = SUM(ETA_segmentos)
5. Ajuste climático: UPDATE raids SET adjusted_eta = ETA_total * factor_clima

[Drive Score]
1. Durante raid: buffer acelerómetro + GPS speed cada 1s
2. Post-raid: calcular componentes:
   - braking_score: percentil de desaceleraciones > 3m/s² (menos = mejor)
   - acceleration_score: percentil de aceleraciones > 3m/s²
   - speed_consistency_score: desviación estándar de speed en tramos rectos
   - speed_limit_score: % de tiempo sobre límite
3. overall = braking*0.30 + acceleration*0.25 + consistency*0.25 + limit*0.20
4. INSERT INTO drive_scores (raid_participant_id, overall_score, ...)

[Modo Conducción]
1. GPS listener: cada 3s evaluar speed
2. speed > 15 km/h por > 5s → modo blocked
3. speed < 5 km/h por > 10s → modo normal
4. En modo blocked: overlay opaco sobre UI interactiva, TTS activo
```

### Edge Cases
- Copiloto presente → puede usar interfaz normalmente (detección de acompañante vía Bluetooth/BLE)
- Velocidad fluctúa cerca del umbral (14-16 km/h) → histéresis de 2 km/h para evitar toggle constante
- Rally sin datos de límite de velocidad en zona rural → usar velocidad genérica (60 km/h para carretera secundaria)
- Drive Score con datos insuficientes (< 5 min de raid) → no calcular, mostrar "datos insuficientes"
- TTS en segundo plano (pantalla bloqueada) → mantener canal de audio activo
- Usuario desactiva permisos de audio → fallback a notificaciones visuales mínimas

### Error States
- No se puede calcular ETA por falta de datos OSRM → "No se pudo calcular el tiempo objetivo. El Rally usará tiempo estimado genérico."
- Acelerómetro no disponible → "Drive Score no disponible. Algunos sensores no están activos."
- Permiso de audio denegado → "Sin permisos de audio. Las alertas TTS no funcionarán."
- Error de TTS → fallback a notificación visual breve

---

# P2 — Social + Progresión

---

## Feature: Voice Chat (LiveKit) + TTS
**ID:** F-11
**Prioridad:** P2
**Dependencias:** F-05 (Raids), F-04 (Clanes), LiveKit server
**Descripción:** Canales de voz en tiempo real usando LiveKit integrado con Supabase. Tres tipos de canales: raid activo, clan (24/7), y subgrupo dentro de raid (convoy). Push-to-talk por botón Bluetooth, comando de voz o botón en pantalla (solo detenido). TTS pipeline para anuncios automáticos.

### User Stories
- Como motero en un raid, quiero hablar por voz con los demás riders para coordinar sin sacar las manos del manubrio.
- Como miembro de un clan, quiero un canal de voz permanente para socializar.
- Como motero en modo conducción, quiero escuchar anuncios automáticos por TTS.
- Como motero, quiero usar push-to-talk con un botón en el manubrio.

### Escenarios

#### Escenario 1: Unirse al canal de voz del raid
**Given** que soy participante de un raid activo
**When** el raid pasa a estado `active`
**Then** una EF/trigger crea un room en LiveKit
**And** recibo un token de acceso en `raid_participants.livekit_token`
**And** el SDK Flutter se conecta automáticamente al room
**And** puedo escuchar a los demás participantes

#### Escenario 2: Push-to-talk con botón Bluetooth
**Given** que estoy conectado al canal de voz del raid
**When** presiono el botón Bluetooth en mi manubrio (pareado como dispositivo de audio)
**Then** mi micrófono se activa mientras mantengo presionado
**When** suelto el botón
**Then** mi micrófono se silencia

#### Escenario 3: TTS anuncia evento del raid
**Given** que estoy en un raid activo y un participante se desvía de la ruta
**When** el sistema detecta la desviación
**Then** se genera un payload de TTS
**And** el audio se reproduce: "[Nombre] se ha desviado de la ruta"
**And** si el audio ya está cacheado, se reproduce directamente

#### Escenario 4: Clan voice channel 24/7
**Given** que soy miembro de un clan
**When** navego al chat de voz del clan
**Then** veo quiénes están conectados al canal de voz del clan
**And** puedo unirme al canal de voz del clan (independientemente de si hay raid activo)

### Acceptance Criteria
- [ ] LiveKit room creado automáticamente al iniciar raid
- [ ] Tokens LiveKit generados por participante válido por duración del raid
- [ ] Push-to-talk: Bluetooth, comando de voz, botón en pantalla (solo detenido)
- [ ] Clan voice channel 24/7
- [ ] TTS pipeline: evento → Edge Function TTS → audio cacheado → reproducción
- [ ] Audio en segundo plano (pantalla bloqueada)
- [ ] TTS cacheado localmente para eventos recurrentes

### Data Flow
```
[Creación room LiveKit]
1. Raid → active: Edge Function `on_raid_start` se ejecuta
2. POST https://livekit-server/api/v1/rooms → { name: "raid-{raid_id}", max_participants: 20 }
3. Para cada participante: generar Access Token con room join permission
4. UPDATE raid_participants SET livekit_token=token, livekit_room=room_name

[Conexión Flutter]
1. LiveKitClient.connect('wss://livekit-server', token)
2. room.localParticipant.setMicrophoneEnabled(false) // push-to-talk
3. Al presionar botón: setMicrophoneEnabled(true)
4. Al soltar: setMicrophoneEnabled(false)

[TTS Pipeline]
1. Evento de raid (checkpoint próximo, alerta, desviación)
2. Realtime broadcast → cliente escucha
3. Si speed > 15 km/h:
   a. Buscar en cache local (Key: "{evento_tipo}_{valor}")
   b. Si no en cache: GET /functions/v1/tts?text=...&lang=es
   c. Edge Function → Google Cloud TTS → audio bytes
   d. Reproducir y cachear
```

### Edge Cases
- Participante sin micrófono → puede escuchar pero no hablar
- LiveKit rate limit excedido → mostrar "Canal de voz temporalmente no disponible"
- Usuario en modo conducción > 15 km/h → push-to-talk solo por botón Bluetooth, no por pantalla
- Clan grande (> 20 miembros) en voice → sub-canales o límite de 20 concurrentes
- Token LiveKit expira durante raid largo → Edge Function refresh
- Self-hosted LiveKit en VPS → considerar costos de ancho de banda
- Audio en segundo plano en iOS → requiere UIBackgroundModes = audio en Info.plist

### Error States
- Error de conexión LiveKit → "No se pudo conectar al canal de voz. Reintentando..."
- Token de LiveKit inválido → "Error de autenticación de voz. Reconnectando..."
- TTS falla (Google Cloud quota) → mostrar notificación visual como fallback
- Micrófono bloqueado por permiso → "Activá el micrófono para usar voz."
- LiveKit room no existe → crear room on-demand si no existe

---

## Feature: Reputation System
**ID:** F-12
**Prioridad:** P2
**Dependencias:** F-04 (Clanes), F-05 (Raids), F-09 (Post-raid stats)
**Descripción:** Sistema de reputación oculto (trust_score, 0-100) que refleja la confiabilidad del motero. Incluye mentor/rookie relationships, conduct reports con revisión de admin, y penalizaciones por abuso del sistema. El trust_score NO es visible públicamente — solo se muestra como badge color.

### User Stories
- Como administrador, quiero ver conduct reports para moderar la comunidad.
- Como motero con trust_score alto, quiero ser mentor de rookies para ganar bonus XP.
- Como motero novato, quiero ser emparejado con un mentor en mi primer raid.
- Como motero, quiero reportar conducta inapropiada de otro participante.

### Escenarios

#### Escenario 1: Trust score aumenta por buen comportamiento
**Given** que completo un raid sin incidentes
**When** el raid finaliza exitosamente
**Then** mi trust_score aumenta +1 a +3 según duración y dificultad
**And** si mi Drive Score > 80, recibo +0.5 adicional

#### Escenario 2: Mentoría exitosa
**Given** que soy nivel ≥ 5 y trust_score ≥ 70
**When** me convierto en mentor de un rookie (nivel ≤ 2) en un raid
**And** ambos completan el raid sin incidentes
**Then** ambos reciben bonus XP
**And** mi trust_score aumenta +2

#### Escenario 3: Conduct report y consecuencias
**Given** que soy participante de un raid
**When** otro participante tiene comportamiento inapropiado
**Then** puedo enviar un conduct report (razón, severidad 1-5)
**When** un admin verifica el reporte
**Then** el trust_score del reportado se reduce -10 a -30 según severidad
**And** si el reporte era falso, mi trust_score se reduce -5

#### Escenario 4: Trust badge visible (sin valor numérico)
**Given** que veo el perfil de otro motero
**When** el motero tiene trust_score ≥ 80
**Then** veo badge 🟢 Confiable
**When** trust_score 50-79
**Then** veo badge 🟡 Precaución
**When** trust_score < 50
**Then** veo badge 🔴 Evitar

### Acceptance Criteria
- [ ] trust_score en user_xp (smallint 0-100, default 50)
- [ ] Factores que afectan trust_score según tabla 15.1 del SDD
- [ ] mentor_relationships: mentor_id, rookie_id, raid_id, bonus_xp, completed_safely
- [ ] Requisitos mentor: level ≥ 5, trust_score ≥ 70
- [ ] Requisitos rookie: level ≤ 2
- [ ] conduct_reports: reporter, reported, raid, reason, severity (1-5), is_verified
- [ ] Solo admins ven trust_score numérico y conduct_reports
- [ ] Badge público con 3 niveles de color
- [ ] Penalización por falso reporte (-5 trust_score)

### Data Flow
```
[Trust score post-raid]
INSERT INTO drive_scores (raid_participant_id, overall_score, ...)
→ Frontend calcula trust_delta:
   if completed_safely: trust += 1-3 según duración
   if drive_score > 80: trust += 0.5
UPDATE user_xp SET trust_score = LEAST(100, trust_score + delta)

[Mentoría]
1. Mentor (level≥5, trust≥70) invita a rookie (level≤2) al raid
2. Al completar: INSERT mentor_relationships (mentor_id, rookie_id, raid_id, completed_safely=true)
3. Bonus XP: mentor +20, rookie +40
4. trust_score: mentor +2

[Conduct report]
1. INSERT conduct_reports (reporter_id, reported_id, raid_id, reason, severity, is_verified=false)
2. Admin revisa y marca is_verified=true/false
3. Si verified=true: trust_score reported -= severity*2 (con límite -30 por raid)
4. Si verified=false (falso reporte): trust_score reporter -= 5
```

### Edge Cases
- Un mismo usuario reportado múltiples veces → acumula reducciones
- Rookie completa raid pero mentor abandona → rookie recibe XP, mentor no recibe bonus
- Trust_score mínimo es 0 (no puede ser negativo) → CHECK constraint
- Admin reporta a un usuario → el reporte va a otro admin para evitar sesgo
- Usuario con trust_score bajo intenta crear raid → permitido pero visible para hosts
- Mentor y rookie no completan juntos → mentor_relationships.completed_safely = false

### Error States
- Reporte duplicado → "Ya reportaste a este usuario en este raid."
- Severidad inválida → "La severidad debe ser entre 1 y 5."
- No eres admin para ver reports → "No tenés permisos para ver reportes de conducta."
- Mentor no cumple requisitos → "Necesitás nivel 5+ y trust_score 70+ para ser mentor."

---

## Feature: XP + Levels + Streaks + Achievements + Leaderboards
**ID:** F-13
**Prioridad:** P2
**Dependencias:** F-09 (Post-raid stats), F-05 (Raids)
**Descripción:** Sistema completo de progresión RPG. XP se acumula por raids, checkpoints, pings y fotos. Nivel = floor(sqrt(total_xp/100)) + 1. Rachas de raids consecutivos multiplican XP (2× a 3+ días, 3× a 7+ días). Achievements se verifican automáticamente. Leaderboards: general, semanal, mensual, por clan.

### User Stories
- Como motero, quiero ganar XP y subir de nivel para sentir progresión.
- Como motero, quiero mantener una racha de raids diarios para ganar XP multiplicado.
- Como motero, quiero desbloquear logros (achievements) por hitos específicos.
- Como motero, quiero ver el leaderboard general para saber mi ranking.
- Como motero, quiero ver el leaderboard de mi clan para competir internamente.

### Escenarios

#### Escenario 1: Ganar XP y subir de nivel
**Given** que completo un raid
**When** la función `finish_raid` otorga XP
**Then** mi total_xp aumenta
**And** si total_xp cruza el umbral del siguiente nivel, mi level se recalcula
**And** veo una animación de "subida de nivel" si corresponde

#### Escenario 2: Racha de 3 días activa multiplicador 2×
**Given** que completé raids los últimos 3 días consecutivos
**When** completo un nuevo raid hoy
**Then** mi current_streak = 3
**And** el XP base de este raid se multiplica ×2

#### Escenario 3: Achievement desbloqueado automáticamente
**Given** que completé mi primer raid
**When** el trigger `check_achievements` se ejecuta post-raid
**Then** se evalúa mi user_xp.raids_completed
**And** si raids_completed ≥ 1, se desbloquea "Primer Raid" (+100 XP reward)
**And** recibo notificación: "🏁 Logro desbloqueado: Primer Raid"

#### Escenario 4: Leaderboard general
**Given** que navego a la pantalla de leaderboards
**When** selecciono "General"
**Then** veo top 100 usuarios ordenados por total_xp descendente
**And** mi posición actual está destacada
**And** puedo ver mi posición aunque esté fuera del top 100 ("Estás en el puesto #X")

### Acceptance Criteria
- [ ] XP acumulado en user_xp.total_xp
- [ ] Nivel = floor(sqrt(total_xp/100)) + 1 (SQL function xp_to_level)
- [ ] Función award_xp(xp) con UPDATE o INSERT ON CONFLICT
- [ ] Streak tracking: trigger en raid_participants (is_completed → true)
- [ ] Multiplicador de racha: 2× (≥3 días), 3× (≥7 días)
- [ ] 17 achievements seed en DB con criteria JSONB
- [ ] check_achievements trigger en UPDATE de user_xp
- [ ] Leaderboard snapshots: general, weekly, monthly, clan_weekly, clan_monthly
- [ ] SELECT público de leaderboard_snapshots
- [ ] SELECT público de user_xp (para ver nivel de otros)

### Data Flow
```
[award_xp]
SELECT award_xp(p_user_id INT, p_xp INT)
→ INSERT INTO user_xp (user_id, total_xp, level) VALUES (p_user_id, p_xp, xp_to_level(p_xp))
  ON CONFLICT (user_id) DO UPDATE SET
    total_xp = user_xp.total_xp + p_xp,
    level = xp_to_level(user_xp.total_xp + p_xp)

[Streak trigger]
UPDATE raid_participants SET is_completed=true
→ Trigger trg_update_streak:
   IF last_raid_date IS NULL → current_streak=1
   ELSIF last_raid_date = yesterday → current_streak++
   ELSIF last_raid_date < yesterday → current_streak=1

[Achievement check]
UPDATE user_xp SET raids_completed++
→ Trigger trg_check_achievements:
   FOR EACH achievement WHERE NOT yet earned:
     IF criteria.type='raids_completed' AND raids_completed >= criteria.count:
       INSERT user_achievements + award bonus XP

[Leaderboard snapshots]
Scheduled cron (diario/semanal/mensual):
  INSERT INTO leaderboard_snapshots (category, rank, user_id, metric_value, snapshot_date)
  SELECT 'general', ROW_NUMBER() OVER (ORDER BY total_xp DESC), user_id, total_xp, CURRENT_DATE
  FROM user_xp
  WHERE total_xp > 0
```

### Edge Cases
- XP negativo → award_xp ignora o rechaza (validar p_xp > 0)
- Usuario con 0 XP → level = 1 (GREATEST(1, ...))
- Racha se rompe después de 30 días sin raid → reset a 0
- Achievement ya desbloqueado → UNIQUE constraint evita duplicado
- Leaderboard snapshot del mismo día ya existe → UPSERT
- Dos usuarios con mismo total_xp → mismo rank en snapshot
- Achievement criteria type no coincide con ningún campo → ignorar

### Error States
- Error al otorgar XP → "Hubo un error al calcular tu XP. Contactá a soporte."
- Leaderboard sin datos → "Todavía no hay suficientes datos para el leaderboard."
- Achievement no encontrado → "Logro no encontrado en la base de datos."
- Streak no se actualizó → próximo raid corregirá el streak

---

## Feature: SOS Crash Detection + Emergency Alerts
**ID:** F-14
**Prioridad:** P2
**Dependencias:** F-05 (Raids), Acelerómetro + GPS en dispositivo
**Descripción:** Sistema de detección automática de caídas usando acelerómetro + GPS. Si detecta impacto brusco (> 5G) seguido de inmovilidad (> 30s sin movimiento), espera 10s para cancelación, luego alerta al clan y al contacto de emergencia con ubicación exacta.

### User Stories
- Como motero, quiero que la app detecte automáticamente si me caigo y alerte a mi clan.
- Como motero, quiero configurar un contacto de emergencia para que reciba mi ubicación en caso de accidente.
- Como motero, quiero poder cancelar una alerta falsa antes de que se envíe.
- Como miembro de un clan, quiero recibir alertas SOS de mis compañeros en raids.

### Escenarios

#### Escenario 1: Detección automática de caída
**Given** que estoy en un raid activo con mi dispositivo en el manubrio
**When** sufro una caída (acelerómetro detecta > 5G en < 100ms)
**And** luego el GPS muestra inmovilidad por > 30 segundos
**And** el ángulo del dispositivo no es vertical
**Then** la app inicia una cuenta regresiva de 10 segundos con alarma audible
**When** no cancelo la alerta en 10 segundos
**Then** se registra un sos_events con trigger_type = 'crash_detection'
**And** se envía alerta al clan via Realtime + push notification
**And** se llama al contacto de emergencia (si configurado) con ubicación exacta

#### Escenario 2: Cancelación de falso positivo
**Given** que la app detectó una posible caída (cuenta regresiva de 10s activa)
**When** toco "Estoy bien" en la pantalla
**Then** la alerta se cancela
**And** NO se envía notificación al clan ni al contacto de emergencia
**And** se registra internamente para mejorar el algoritmo

#### Escenario 3: Alerta SOS manual
**Given** que estoy en una emergencia durante un raid
**When** presiono el botón SOS en la app (disponible siempre)
**Then** se registra sos_events con trigger_type = 'manual'
**And** se envía alerta inmediata al clan + contacto de emergencia

#### Escenario 4: Configuración de contacto de emergencia
**Given** que soy un usuario autenticado
**When** navego a Configuración → Emergencia
**Then** puedo ingresar nombre y teléfono de un contacto de emergencia
**And** los datos se guardan en users.emergency_contact_name/phone

### Acceptance Criteria
- [ ] Detección de caída: acelerómetro > 5G en < 100ms + inmovilidad 30s + ángulo anómalo
- [ ] Cuenta regresiva de 10s con alarma audible
- [ ] Cancelación de alerta por usuario
- [ ] Registro en sos_events con trigger_type, lat, lng
- [ ] Notificación Realtime al clan
- [ ] Push notification al contacto de emergencia (via Edge Function + Twilio/Vonage)
- [ ] Botón SOS manual siempre visible
- [ ] Configuración de contacto de emergencia en perfil
- [ ] Falso SOS manual reportado → penalización de trust_score (-5)

### Data Flow
```
[Detección de caída]
1. AccelerometerEvent > 5G (eje Z compuesto) → flag potencial_crash
2. Timer 30s: check GPS movement < 1m → confirm inmovilidad
3. Device angle check: gyroscope angle > 45° de vertical
4. INICIAR countdown de 10s con sonido + pantalla "¿Estás bien?"
5. Si no cancelado en 10s:
   INSERT sos_events (user_id, raid_id, lat, lng, trigger_type='crash_detection')
   → Realtime broadcast a clan: { event: 'sos_alert', payload: { user_id, lat, lng } }
   → Edge Function: call twilio API → SMS/llamada a emergency_contact_phone
6. Si cancelado: no hacer nada, log interno

[SOS Manual]
1. Botón SOS → INSERT sos_events (trigger_type='manual')
2. Mismo flujo de notificaciones que arriba
3. Si no hay emergencia real post-evento → admin puede marcar como falso
   (trust_score -= 5)
```

### Edge Cases
- Dispositivo en modo ahorro de batería → acelerómetro puede no estar disponible
- Usuario no configuró contacto de emergencia → solo alerta al clan
- Sin conexión a Internet → almacenar sos_events localmente, enviar al reconectar
- Múltiples falsos positivos (ej. moto en caminos muy irregulares) → ajustar threshold dinámicamente
- Raid nocturno + caída → prioridad máxima, alertas más frecuentes
- Contacto de emergencia no contesta → reintentar cada 5 min hasta 3 intentos

### Error States
- Acelerómetro no disponible → "La detección de caídas no está disponible en este dispositivo."
- Permiso de notificaciones denegado → "Activá las notificaciones para recibir alertas SOS."
- Contacto de emergencia inválido → "Ingresá un número de teléfono válido."
- Error al enviar SMS/llamada → "No se pudo contactar a tu emergencia. Se envió alerta al clan."

---

## Feature: Modo Espectador
**ID:** F-15
**Prioridad:** P2
**Dependencias:** F-05 (Raids), F-06 (Mapa en vivo)
**Descripción:** Permite a usuarios seguir raids en vivo sin participar. Los espectadores ven posiciones en el mapa, pings y checkpoints, pero NO pueden enviar mensajes, pings, capturar checkpoints ni usar voz. El host debe habilitar explícitamente los espectadores.

### User Stories
- Como familiar de un motero, quiero seguir su raid en vivo para saber que está bien.
- Como miembro de la comunidad, quiero ver raids públicos como espectador para aprender rutas.
- Como host, quiero controlar si mi raid permite espectadores o no.

### Escenarios

#### Escenario 1: Unirse como espectador a un raid
**Given** que existe un raid activo con allow_spectators = true
**When** toco "Ver como espectador" en la página del raid
**Then** se inserta mi registro en `raid_spectators`
**And** veo el mapa en vivo con posiciones de los participantes
**And** veo pings de peligro y checkpoints
**And** NO veo el chat del raid ni puedo interactuar

#### Escenario 2: Host habilita/deshabilita espectadores
**Given** que soy host de un raid
**When** edito la configuración del raid en lobby
**Then** puedo marcar/desmarcar "Permitir espectadores"
**And** los espectadores existentes no se ven afectados si deshabilito (no se expulsan)

#### Escenario 3: Espectador abandona
**Given** que soy espectador de un raid
**When** selecciono "Dejar de ver"
**Then** mi registro en raid_spectators se actualiza con left_at
**And** dejo de recibir posiciones en vivo

### Acceptance Criteria
- [ ] Tabla raid_spectators con unique(raid_id, user_id)
- [ ] Columna raids.allow_spectators (default false)
- [ ] SELECT público de posiciones para espectadores
- [ ] NO INSERT en raid_messages para espectadores
- [ ] NO INSERT en raid_checkpoint_verifications para espectadores
- [ ] Solo participantes activos (no espectadores) aparecen en el mapa
- [ ] Interfaz de espectador: sin botones de interacción, solo visualización

### Data Flow
```
[Unirse como espectador]
1. SELECT raids WHERE id=X AND status='active' AND allow_spectators=true
2. INSERT raid_spectators (raid_id, user_id)
3. Suscribirse a canal raid:{id}:positions (solo lectura)
4. Suscribirse a canal raid:{id}:chat (solo lectura, sin enviar)

[Salir]
1. UPDATE raid_spectators SET left_at=NOW() WHERE raid_id=X AND user_id=auth.uid()
2. Cancelar suscripciones Realtime
```

### Edge Cases
- Espectador también es participante del raid → no aparece dos veces, prevalece participante
- 100+ espectadores en un raid popular → considerar rate limiting en broadcast
- Espectador intenta enviar ping → RLS lo bloquea silenciosamente (no mostrar error)
- Host deshabilita espectadores durante el raid → no expulsar existentes, bloquear nuevos
- Espectador offline → no hay efecto, solo deja de recibir posiciones

### Error States
- Raid no permite espectadores → "El organizador no permite espectadores en este raid."
- Raid no está activo → "El raid aún no comenzó o ya finalizó."
- Ya eres participante del raid → "Ya estás participando de este raid."
- Error al cargar posiciones → "No se pudieron cargar las posiciones en vivo."

---

# P3 — Monetización + Extra

---

## Feature: In-Game Economy (Coins, Shop, Cosmetics)
**ID:** F-16
**Prioridad:** P3
**Dependencias:** F-05 (Raids), F-13 (XP + levels)
**Descripción:** Moneda virtual (coins) acumulable por raids, logros, rachas y mentoría. Tienda in-game con items cosméticos (skins de avatar, skins de moto, banners de clan, colores de marcador, títulos). NO se venden ventajas competitivas. Compras in-app opcionales.

### User Stories
- Como motero, quiero ganar coins completando raids para comprar cosméticos.
- Como motero, quiero comprar una skin para mi avatar en la tienda.
- Como motero, quiero equipar un título cosmético que se muestra junto a mi nombre.
- Como motero, quiero comprar un XP boost pequeño (consumible) para raids.

### Escenarios

#### Escenario 1: Ganar coins post-raid
**Given** que completo un raid
**When** post-raid, la EF finish_raid otorga coins
**Then** recibo 10-50 coins según modo y duración
**And** veo el saldo actualizado en la pantalla de resultados

#### Escenario 2: Comprar item cosmético
**Given** que tengo 500 coins
**When** selecciono una skin de avatar que cuesta 200 coins
**Then** se inserta en user_purchases (user_id, item_id)
**And** mi saldo se reduce a 300 coins
**And** la skin se aplica inmediatamente a mi avatar

#### Escenario 3: Equipar título cosmético
**Given** que compré un título en la tienda
**When** voy a mi perfil → Títulos
**Then** veo la lista de títulos que poseo
**When** selecciono "Leyenda del Asfalto"
**Then** mi título activo se muestra junto a mi nombre en raids y chat

### Acceptance Criteria
- [ ] coins column en user_xp (int >= 0)
- [ ] Fuentes de coins según tabla 16.1 del SDD
- [ ] Tabla shop_items con type (cosmetic, consumable)
- [ ] Subtipos: avatar_skin, bike_skin, clan_banner, marker_color, checkpoint_effect, xp_boost_small, title
- [ ] Tabla user_purchases
- [ ] Restricción: NO vender ventajas competitivas
- [ ] Consumibles: xp_boost_small (×2 XP por 1 raid)
- [ ] Cosméticos: una vez comprados, permanentes

### Data Flow
```
[Otorgar coins post-raid]
finish_raid EF:
  coins_gained = random(10, 50) según modo
  UPDATE user_xp SET coins = coins + coins_gained WHERE user_id = X

[Comprar item]
1. SELECT coins FROM user_xp WHERE user_id = auth.uid()
2. Verify coins >= item.coins_cost
3. UPDATE user_xp SET coins = coins - item.coins_cost
4. INSERT user_purchases (user_id, item_id)

[Equipar título]
1. SELECT * FROM user_purchases WHERE user_id = X AND item.type = 'title'
2. User selecciona título activo
3. UPDATE users SET active_title = 'Leyenda del Asfalto'
```

### Edge Cases
- Usuario intenta comprar item que ya posee → mostrar "Ya tenés este item"
- Coins insuficientes → "No tenés suficientes coins. Completá más raids para ganar coins."
- Item battle_pass_only sin BP activo → "Este item solo está disponible en el Battle Pass."
- Usuario intenta comprar con coins negativos → CHECK constraint en DB
- Compra falla a mitad de transacción → rollback
- Item desactivado (is_active = false) → oculto de la tienda

### Error States
- Coins insuficientes → "No tenés suficientes coins. Necesitás [X] coins."
- Item no disponible → "Este artículo ya no está disponible en la tienda."
- Error de compra → "Hubo un error al procesar la compra. Tu saldo no fue afectado."
- Transacción fallida → rollback y reintentar

---

## Feature: Battle Pass Estacional
**ID:** F-17
**Prioridad:** P3
**Dependencias:** F-13 (XP + levels), F-16 (Economy)
**Descripción:** Temporadas de 3 meses con 50 tiers. Progresión por XP acumulado en raids. Cada tier desbloquea recompensas cosméticas. Versión premium (paga) duplica recompensas. Misiones diarias y semanales para XP adicional.

### User Stories
- Como motero, quiero progresar en el Battle Pass para desbloquear recompensas exclusivas.
- Como motero, quiero ver mi progreso actual (tier actual, XP restante para el próximo).
- Como motero premium, quiero recibir recompensas extra por mi suscripción.
- Como motero, quiero completar misiones diarias/semanales para subir más rápido.

### Escenarios

#### Escenario 1: Progresión de Battle Pass
**Given** que hay un Battle Pass activo
**When** gano XP en raids
**Then** battle_pass_progress.xp_in_season aumenta
**When** xp_in_season cruza el umbral del próximo tier (500 XP por tier)
**Then** current_tier aumenta
**And** puedo reclamar la recompensa del tier

#### Escenario 2: Reclamar recompensa de tier
**Given** que mi current_tier es 5 y no reclamé la recompensa del tier 5
**When** toco "Reclamar" en la pantalla del Battle Pass
**Then** el item se añade a mi inventario (user_purchases)
**And** el tier se marca como reclamado en claimed_rewards

#### Escenario 3: Misión diaria completada
**Given** que tengo una misión diaria activa ("Completá 3 checkpoints hoy")
**When** capturo mi tercer checkpoint del día
**Then** user_missions_progress.progress se actualiza a 3/3
**And** recibo XP de recompensa de la misión
**And** la misión se marca como completada

### Acceptance Criteria
- [ ] Tablas: battle_passes, battle_pass_progress, battle_pass_missions, user_missions_progress
- [ ] Temporadas de 3 meses con start_date y end_date
- [ ] 50 tiers por temporada
- [ ] Progresión por XP: ~500 XP por tier
- [ ] Premium: recompensas duplicadas, tiers extra
- [ ] Misiones diarias y semanales
- [ ] Recompensas reclamables manualmente
- [ ] claimed_rewards JSONB array en battle_pass_progress

### Data Flow
```
[Crear temporada]
Admin: INSERT battle_passes (season_name, season_number, start_date, end_date, rewards_json)

[Inicializar progreso]
Primer login en temporada activa:
  SELECT * FROM battle_passes WHERE is_active=true
  INSERT battle_pass_progress (user_id, battle_pass_id) ON CONFLICT DO NOTHING

[Acumular XP]
Por cada award_xp():
  UPDATE battle_pass_progress SET
    xp_in_season = xp_in_season + p_xp,
    current_tier = FLOOR(xp_in_season / 500) + 1
  WHERE user_id = X AND battle_pass_id = (SELECT id FROM battle_passes WHERE is_active=true)

[Reclamar recompensa]
UPDATE battle_pass_progress SET
  claimed_rewards = claimed_rewards || tier_num
WHERE user_id = X AND battle_pass_id = Y
AND NOT (claimed_rewards ? tier_num)
```

### Edge Cases
- Usuario se une a mitad de temporada → progresión desde tier 1
- Usuario no reclama recompensas de temporada anterior → perder al finalizar
- Múltiples temporadas activas (transición) → solo una activa a la vez
- Premium expira a mitad de temporada → recompensas premium no reclamadas se pierden
- XP suficiente para múltiples tiers en un raid → saltar tiers directamente
- Misión diaria no completada → se pierde al día siguiente

### Error States
- Battle Pass no activo → "No hay una temporada activa en este momento."
- Recompensa ya reclamada → "Ya reclamaste esta recompensa."
- Tier no alcanzado → "Llegá al tier [X] para desbloquear esta recompensa."
- Premium requerido → "Esta recompensa es exclusiva de Battle Pass Premium."

---

## Feature: Dynamic Context (Weather, Day/Night)
**ID:** F-18
**Prioridad:** P3
**Dependencias:** F-05 (Raids), OpenWeather API, OSRM
**Descripción:** Clima dinámico integrado a la ruta del raid. Consulta OpenWeather API para obtener condiciones climáticas a lo largo de la ruta, ajusta ETA en modo Rally según clima (lluvia: +15%, viento: +5%, etc.). Detecta raids nocturnos (20:00-06:00) para aplicar bonus XP y reglas especiales.

### User Stories
- Como motero, quiero saber el clima en la ruta antes de unirme a un raid.
- Como motero, quiero que el ETA del Rally se ajuste automáticamente por condiciones climáticas.
- Como motero, quiero bonus XP por hacer raids nocturnos.
- Como motero, quiero recibir alertas de cambio climático durante el raid.

### Escenarios

#### Escenario 1: Clima consultado al crear raid
**Given** que creo un raid con origen y destino
**When** selecciono la fecha del raid
**Then** la app consulta la ruta OSRM para obtener waypoints cada ~10 km
**And** para cada waypoint, consulta OpenWeather para el momento estimado de llegada
**And** veo un resumen climático: "Soleado en toda la ruta" o "Lluvia prevista en el tramo 3"
**And** el ETA mostrado ya incluye ajuste climático

#### Escenario 2: Cambio climático durante el raid
**Given** que estoy en un raid activo
**When** OpenWeather reporta un cambio significativo (lluvia no prevista)
**Then** la Edge Function re-consulta cada 15 minutos
**And** si hay cambio, se broadcasta por Realtime
**And** escucho TTS: "Atención: lluvia prevista en el tramo 3 en aproximadamente 15 minutos"

#### Escenario 3: Raid nocturno
**Given** que creo un raid con scheduled_at entre 20:00 y 06:00
**When** el raid se crea
**Then** raids.is_night_raid = true
**And** se muestra badge 🌙 en la pantalla del raid
**When** el raid finaliza
**Then** los participantes reciben +15% XP bonus (adicional)
**And** la duración mínima del raid es 45 min

### Acceptance Criteria
- [ ] Edge Function get_route_weather: origen, destino, departure_time
- [ ] OpenWeather One Call 3.0 API
- [ ] Segmentos climáticos cada ~10 km
- [ ] Ajuste de ETA: lluvia mod +15%, fuerte +25%, viento +5%, nieve +35%, niebla +20%
- [ ] Re-consulta cada 15 min durante raid activo
- [ ] Broadcast de cambio climático significativo
- [ ] is_night_raid = true entre 20:00-06:00 hora local
- [ ] Bonus XP nocturno: +15%
- [ ] Duración mínima nocturna: 45 min

### Data Flow
```
[get_route_weather EF]
Input: { origin_lat, origin_lng, dest_lat, dest_lng, departure_time }

1. Obtener ruta OSRM → lista de waypoints
2. Para cada waypoint (cada ~10km):
   GET https://api.openweathermap.org/data/3.0/onecall?lat=...&lon=...&appid=...
3. Agrupar condiciones por tramo
4. Calcular impacto: adjusted_eta = base_eta * (1 + sum(factors))
5. RETURN { segments[], adjusted_eta, weather_alerts[] }
6. UPDATE raids SET weather_conditions=segments, adjusted_eta, weather_checked_at=NOW()

[Re-consulta durante raid]
Cada 15 min:
  GET /functions/v1/get_route_weather?raid_id=X
  Si cambia significativamente:
    → Realtime broadcast: { event: 'weather_change', payload: { segment, condition, eta_adjustment } }
    → TTS anuncia cambio
```

### Edge Cases
- OpenWeather API key sin saldo → raid funciona sin ajuste climático
- Ruta en zona sin cobertura OpenWeather → condiciones default (despejado)
- Fecha del raid es muy lejana (> 7 días) → pronóstico no disponible, mostrar "pronóstico no disponible"
- Cambio climático durante raid nocturno → ajustar XP bonus y ETA
- Zona horaria del host vs participantes → raid nocturno se calcula con hora local del host
- Lluvia torrencial → sugerir cancelación del raid por seguridad (alerta roja)

### Error States
- Error de OpenWeather API → "No se pudo consultar el clima. El raid usará condiciones default."
- Sin datos climáticos para la ruta → "Clima no disponible para esta zona."
- API rate limit excedido → "Demasiadas consultas climáticas. Reintentando..."
- Cambio climático crítico (tormenta eléctrica) → alerta de seguridad con recomendación de cancelar

---

## Feature: Anti-Cheat System
**ID:** F-19
**Prioridad:** P3
**Dependencias:** F-05 (Raids), F-07 (Checkpoints), Edge Function validate_checkpoint
**Descripción:** Sistema anti-cheat de 3 capas: detección de mock GPS, validación de velocidad (speed > 300 km/h = FLAG), y cross-check QR + GPS + EXIF de foto. Las violaciones se registran en anti_cheat_log. 2+ flags en un raid retienen XP hasta revisión de admin.

### User Stories
- Como motero honesto, quiero que el sistema detecte tramposos para que los leaderboards sean justos.
- Como administrador, quiero revisar raids marcados como flagged para tomar acción.

### Escenarios

#### Escenario 1: Mock GPS detection (Android/iOS)
**Given** que un participante tiene activado un mock GPS en su dispositivo
**When** su posición es reportada durante el raid
**Then** el cliente detecta isFromMockProvider() = true
**And** se registra un anti_cheat_log con check_type = 'gps_mock', passed = false
**And** el participante recibe un warning: "GPS simulado detectado. Desactivá apps de mock GPS."

#### Escenario 2: Speed validation — velocidad imposible
**Given** que un participante captura un checkpoint
**When** la distancia entre checkpoints dividida por tiempo da > 300 km/h
**Then** la Edge Function rejecta con valid: false, y registra anti_cheat_log
**And** raid_participants.anti_cheat_flags += 1
**And** si flags ≥ 2, raid_participants.is_flagged = true

#### Escenario 3: Cross-check EXIF de foto
**Given** que un participante sube una foto como evidencia de checkpoint
**When** la EF validate_checkpoint extrae EXIF de la foto
**And** compara GPS de EXIF con GPS reportado
**And** compara timestamp de EXIF con timestamp de verificación
**Then** si diferencia > 10m GPS o > 30s timestamp → FLAG en anti_cheat_log

#### Escenario 4: Raid flagged — XP retenido
**Given** que un raid tiene raid_participants.is_flagged = true
**When** finish_raid se ejecuta
**Then** el XP del participante flagged se retiene (no se otorga)
**And** el raid se marca para revisión de admin
**When** admin revisa y decide que era legítimo
**Then** el XP retenido se otorga manualmente y is_flagged = false

### Acceptance Criteria
- [ ] Mock GPS detection (isFromMockProvider)
- [ ] Speed validation en EF validate_checkpoint
- [ ] EXIF cross-check (GPS + timestamp)
- [ ] anti_cheat_log con check_type, passed, details
- [ ] raid_participants.anti_cheat_flags (int)
- [ ] raid_participants.is_flagged (boolean)
- [ ] XP retenido si is_flagged = true
- [ ] 1 flag = WARN, 2+ = XP retenido
- [ ] Patrón recurrente (> 3 raids flagged) = trust_score reducido + posible ban

### Data Flow
```
[Mock GPS detection — cliente-side]
Geolocator.getCurrentPosition().then((pos) {
  if (pos.isMocked) {
    supabase.from('anti_cheat_log').insert({
      raid_participant_id,
      checkpoint_id: null,
      check_type: 'gps_mock',
      passed: false,
      details: { provider: pos.provider }
    })
    // mostrar warning al usuario
  }
})

[Speed validation — EF validate_checkpoint]
1. Obtener timestamp y posición del checkpoint anterior
2. distance_km = haversine(prev_lat, prev_lng, current_lat, current_lng)
3. time_hours = (current_timestamp - prev_timestamp) / 3600
4. speed_kmh = distance_km / time_hours
5. if speed_kmh > 300:
     INSERT anti_cheat_log (... check_type='speed', passed=false)
     UPDATE raid_participants SET anti_cheat_flags = anti_cheat_flags + 1
     if anti_cheat_flags >= 2:
       UPDATE raid_participants SET is_flagged = true
     RETURN { valid: false, message: 'Velocidad imposible detectada' }

[EXIF cross-check]
1. Subir foto → extraer EXIF (lat, lng, timestamp) server-side
2. if ABS(exif_lat - reported_lat) > 0.0001 (~10m) OR ABS(exif_lng - reported_lng) > 0.0001:
     INSERT anti_cheat_log (... check_type='photo_exif', passed=false)
3. if ABS(exif_timestamp - verification_timestamp) > 30s:
     INSERT anti_cheat_log (... check_type='timestamp', passed=false)
```

### Edge Cases
- GPS real reportado como mock por bug de Android → revisión manual de admin
- Foto sin datos EXIF (WhatsApp comprime EXIF) → FLAG pero revisable por admin
- Velocidad alta pero legítima (ej. moto deportiva en autopista) → 250 km/h es WARN, no FLAG
- Participante con flags en raids anteriores → acumular para decisión de ban
- EXIF editing tools → la validación EXIF es una capa más, no la única
- Primer checkpoint del raid (no hay posición previa) → no se puede calcular speed, skip validación

### Error States
- GPS simulado detectado → "GPS simulado detectado. Desactivá apps de mock GPS para participar."
- Velocidad imposible → "Velocidad imposible entre checkpoints. Tu raid será revisado."
- Foto sin EXIF GPS → "La foto no contiene datos de ubicación. Posible foto de galería."
- Cuenta suspendida por anti-cheat → "Tu cuenta ha sido suspendida por violaciones al anti-cheat. Contactá a soporte."

---

## Feature: Replay Time-Lapse
**ID:** F-20
**Prioridad:** P3
**Dependencias:** F-06 (Mapa en vivo), F-07 (Checkpoints)
**Descripción:** Las posiciones broadcast durante el raid se persisten en `raid_position_log`. Post-raid, el host puede generar un replay time-lapse que se reproduce en el mapa mostrando la ruta de cada participante coloreada por velocidad, checkpoints capturados, y estadísticas. Retención: 30 días (versión completa) o permanente (versión resumida compartida).

### User Stories
- Como motero, quiero ver el replay de un raid que hice para analizar mi ruta.
- Como motero, quiero compartir el replay de un raid épico en redes sociales.
- Como host, quiero ver la ruta de todos los participantes superpuesta para analizar el rendimiento.

### Escenarios

#### Escenario 1: Generar replay post-raid
**Given** que un raid ha finalizado (status = completed)
**When** como host, selecciono "Generar replay"
**Then** se consulta raid_position_log para todos los participantes
**And** se renderiza un time-lapse de 30-90 segundos (según duración del raid)
**And** el replay muestra: línea de ruta por participante (coloreada por velocidad), checkpoints capturados, tiempo transcurrido
**And** el replay se guarda y está disponible para compartir

#### Escenario 2: Ver replay en el mapa
**Given** que existe un replay generado
**When** lo reproduzco
**Then** veo en el mapa las rutas de todos los participantes animadas
**And** la línea cambia de color según velocidad (verde < 40, amarillo 40-80, rojo > 80)
**And** los checkpoints se marcan con iconos
**And** veo velocidades media/máx de cada participante

#### Escenario 3: Compartir replay
**Given** que generé un replay
**When** selecciono "Compartir"
**Then** se genera una URL compartible: asfalto.club/replay/{raid_id}
**And** la URL se puede compartir en redes sociales, WhatsApp, etc.

### Acceptance Criteria
- [ ] raid_position_log: persistencia de posiciones cada 5s durante raid activo
- [ ] Retención: 30 días versión completa, permanente versión resumida (1 punto/30s)
- [ ] Generación de replay post-raid por el host
- [ ] Línea de ruta coloreada por velocidad por participante
- [ ] Marcadores de checkpoints capturados
- [ ] Indicador de tiempo transcurrido
- [ ] Velocidad media/máx de cada participante
- [ ] URL compartible
- [ ] Exportable como video (opcional, via FFmpeg/Remotion)

### Data Flow
```
[Persistencia durante raid]
Cada 5s (mismo timer que broadcast):
  INSERT raid_position_log (raid_participant_id, lat, lng, heading, speed, timestamp)

[Generar replay — EF generate_replay]
1. SELECT * FROM raid_position_log rpl
   JOIN raid_participants rp ON rpl.raid_participant_id = rp.id
   WHERE rp.raid_id = X
   ORDER BY rpl.timestamp
2. Agrupar por raid_participant_id
3. Para cada grupo, samplear puntos (1 cada 5s para full, 1 cada 30s para resumen)
4. Calcular velocidades medias/máximas
5. Almacenar en Supabase Storage como JSON o video
6. RETURN { replay_url: '...' }

[Ver replay]
1. Fetch replay data from Storage
2. Renderizar en flutter_map:
   - Línea Polyline animada (animación de drawing)
   - Color por velocidad usando gradient
   - Marcadores en checkpoints
   - Timer overlay
```

### Edge Cases
- Raid muy largo (4+ horas) → replay puede ser pesado; comprimir a 1 punto/30s si > 5000 puntos
- Participante sin datos de posición (offline todo el raid) → línea discontinua con "sin datos"
- Replay de raid con 20 participantes → demasiadas líneas; permitir filtrar por participante
- Almacenamiento de position_log → purgar cada 30 días via cron
- Replay compartido antes de generarse → mostrar "generando replay..."

### Error States
- Sin datos de posición → "No hay suficientes datos para generar el replay."
- Error al generar replay → "Hubo un error al generar el replay. Reintentá más tarde."
- Replay demasiado grande → "El replay es muy extenso. Se generará una versión resumida."
- Raid no completado → "El replay solo está disponible para raids completados."

---

## Feature: Clan Territories
**ID:** F-21
**Prioridad:** P3
**Dependencias:** F-04 (Clanes), F-05 (Raids — modo Guerra de Clanes)
**Descripción:** En el modo Guerra de Clanes, los clanes compiten por zonas geográficas predefinidas. Capturar un territorio requiere completar raids específicos dentro de la zona. El clan con más checkpoints capturados gana el territorio por 7 días. Los territorios se visualizan en el mapa general con el color del clan.

### User Stories
- Como miembro de un clan, quiero capturar territorios para expandir el dominio de mi clan.
- Como miembro de un clan, quiero defender nuestro territorio contra ataques de otros clanes.
- Como motero, quiero ver los territorios de los clanes en el mapa general.
- Como líder de clan, quiero ver qué territorios controlamos y cuándo expiran.

### Escenarios

#### Escenario 1: Capturar un territorio
**Given** que soy miembro de un clan y hay una Guerra de Clanes activa
**When** mi clan completa raids específicos dentro de una zona geográfica
**Then** por cada checkpoint capturado en la zona, el clan acumula puntos
**When** el clan acumula más puntos que el clan defensor
**Then** el territorio pasa a ser controlado por mi clan
**And** se actualiza clan_territories.current_owner_id

#### Escenario 2: Visualización de territorios en el mapa
**Given** que estoy en el mapa general de AsfaltoClub
**When** veo zonas marcadas con círculos de colores
**Then** al hacer tap en una zona: "Territorio de [Clan] — Capturado el [fecha]"
**And** el color del círculo corresponde al color del clan

#### Escenario 3: Defensa exitosa
**Given** que mi clan controla un territorio
**When** otro clan ataca (completa raids en la zona) pero no supera nuestros puntos
**Then** el territorio sigue siendo nuestro
**And** todos los miembros reciben bonus XP por defensa exitosa

### Acceptance Criteria
- [ ] Tabla clan_territories con center, radius, current_owner
- [ ] Captura requiere raids específicos dentro de la zona
- [ ] Puntos = checkpoints capturados en la zona
- [ ] Territorio se mantiene 7 días (a menos que sea desafiado)
- [ ] Defensa exitosa → bonus XP a todos los miembros
- [ ] Visualización en mapa general con color del clan
- [ ] tooltip con información del territorio

### Data Flow
```
[Guerra de Clanes — scoring]
1. Por cada checkpoint capturado en raid dentro de zona:
   SELECT haversine_distance(cp.lat, cp.lng, territory.center_lat, territory.center_lng)
   WHERE distance <= territory.radius_meters
2. INSERT/UPDATE clan_war_scores (clan_id, territory_id, points, updated_at)

[Captura de territorio]
Cuando clan_war_scores.points > current_owner_points:
  UPDATE clan_territories SET
    current_owner_id = attacking_clan_id,
    captured_at = NOW(),
    last_attacked_at = NOW()

[Expiración]
Cron cada hora:
  UPDATE clan_territories SET current_owner_id = NULL
  WHERE captured_at < NOW() - INTERVAL '7 days'
  AND NOT EXISTS (SELECT 1 FROM clan_war_scores WHERE ... last_attacked_at > NOW() - INTERVAL '7 days')
```

### Edge Cases
- Territorio sin dueño (nunca capturado o expiró) → disponible para captura
- Dos clanes atacan el mismo territorio simultáneamente → gana el que más puntos acumule
- Clan pierde territorio mientras raid en curso → XP se otorga igual, el raid no se interrumpe
- Territorio con radio muy grande (10+ km) → dividir en sub-zonas
- Clan disuelto → territorios liberados automáticamente

### Error States
- Guerra de Clanes no activa → "No hay una Guerra de Clanes en curso."
- Territorio ya capturado por otro clan → "Este territorio pertenece a [Clan] hasta [fecha]."
- Sin raids disponibles en la zona → "No hay raids activos en esta zona. Organizá uno."
- Clan no participa en la guerra → "Tu clan no está participando en la Guerra de Clanes."

---

## Feature: Admin Panel
**ID:** F-22
**Prioridad:** P3
**Dependencias:** F-12 (Reputation), F-19 (Anti-cheat), F-04 (Clanes)
**Descripción:** Panel de administración para moderación de la comunidad. Funcionalidades: revisar conduct reports, revisar raids flagged por anti-cheat, gestionar usuarios (ban temporal/permantente), gestionar aliados (allies), y ver estadísticas del sistema.

### User Stories
- Como administrador, quiero ver una lista de conduct reports pendientes para moderar.
- Como administrador, quiero revisar raids flagged por anti-cheat y decidir si el XP se otorga.
- Como administrador, quiero banear temporal o permanentemente a usuarios que violan las reglas.
- Como administrador, quiero gestionar la lista de aliados (refugios) de la app.

### Escenarios

#### Escenario 1: Revisar conduct reports
**Given** que soy admin
**When** navego al panel de reports
**Then** veo una lista de conduct_reports con is_verified = false, ordenados por severidad descendente
**And** puedo ver los detalles de cada reporte (reportante, reportado, raid, razón)
**When** reviso un reporte
**Then** puedo marcarlo como verified (aplica penalización) o rejected (penaliza al reportante)

#### Escenario 2: Revisar raids flagged
**Given** que soy admin
**When** navego al panel de anti-cheat
**Then** veo raids con participantes is_flagged = true
**And** veo los anti_cheat_logs asociados
**When** decido que era legítimo
**Then** marco is_flagged = false y el XP retenido se otorga
**When** decido que era trampa
**Then** el XP no se otorga y trust_score se reduce

#### Escenario 3: Banear usuario
**Given** que soy admin
**When** selecciono "Banear usuario" en el perfil de un infractor recurrente
**Then** puedo elegir ban temporal (días) o permanente
**And** el usuario pierde acceso a su cuenta
**And** se registra en auth.users (raw_user_meta_data.role = 'banned')
**And** sus raids activos se cancelan

#### Escenario 4: Gestionar aliados (allies)
**Given** que soy admin
**When** navego al panel de aliados
**Then** puedo crear, editar y eliminar aliados (refugios)
**And** los cambios se reflejan inmediatamente en el mapa de refugios

### Acceptance Criteria
- [ ] Panel de admin solo accesible para usuarios con role='admin'
- [ ] Lista de conduct reports pendientes con filtros
- [ ] Acción: verified → penaliza trust_score del reportado
- [ ] Acción: rejected → penaliza trust_score del reportante
- [ ] Lista de raids/participantes flagged con anti_cheat_logs
- [ ] Acción: clear flag → otorga XP retenido
- [ ] Acción: confirm flag → XP perdido, trust_score reducido
- [ ] Ban temporal (días) y permanente
- [ ] CRUD completo de aliados (allies)
- [ ] Estadísticas del sistema: raids activos, usuarios totales, etc.

### Data Flow
```
[Revisar reports]
SELECT * FROM conduct_reports WHERE is_verified = false ORDER BY severity DESC

[Resolver reporte]
Si verified=true:
  UPDATE conduct_reports SET is_verified=true, verified_by=admin_id, resolved_at=NOW()
  UPDATE user_xp SET trust_score = GREATEST(0, trust_score - severity * 2) WHERE user_id = reported_id
Si rejected:
  UPDATE conduct_reports SET is_verified=false, verified_by=admin_id, resolved_at=NOW()
  UPDATE user_xp SET trust_score = GREATEST(0, trust_score - 5) WHERE user_id = reporter_id

[Revisar flag]
Si legítimo:
  UPDATE raid_participants SET is_flagged=false, anti_cheat_flags=0
  award_xp(p_user_id, xp_earned)
Si trampa:
  UPDATE raid_participants SET is_flagged=false, xp_earned=0
  UPDATE user_xp SET trust_score = trust_score - 15 WHERE user_id = X

[Ban]
UPDATE auth.users SET raw_user_meta_data = raw_user_meta_data || '{"role": "banned"}'
WHERE id = user_id
```

### Edge Cases
- Admin se reporta a sí mismo → no debería ser posible (RLS bloquea)
- Admin baneado → no puede acceder al panel
- Usuario baneado temporalmente → al expirar, restaurar acceso automáticamente
- Revisión de flag requiere acceso a datos de posición → proteger datos personales
- Reporte masivo contra un mismo usuario → investigar antes de penalizar

### Error States
- No eres admin → "No tenés permisos para acceder al panel de administración."
- Usuario ya baneado → "Este usuario ya está suspendido."
- Error al aplicar penalización → rollback; reintentar
- Datos de flag no disponibles → "Los logs de anti-cheat para este raid no están disponibles."

---

# P3+ — Integración Existente

---

## Feature: Refugios (Allies)
**ID:** F-23
**Prioridad:** P3+
**Dependencias:** F-01 (Auth), F-03 (Places)
**Descripción:** Conexión de la tabla `allies` (aliados comerciales: talleres, restaurantes, hoteles, etc.) con datos reales en lugar del mock actual. Los refugios se muestran en el mapa con beneficios para moteros. Solo admins pueden gestionar la tabla.

### User Stories
- Como motero, quiero ver refugios aliados en el mapa para saber dónde tengo descuentos.
- Como motero, quiero ver el beneficio de cada refugio (ej: "10% de descuento en mantenimiento").
- Como administrador, quiero gestionar la lista de aliados (alta, baja, modificación).

### Escenarios

#### Escenario 1: Ver refugios cercanos en el mapa
**Given** que estoy en el mapa de refugios de la app
**When** la app carga mi ubicación
**Then** se muestran todos los aliados (allies) dentro del radio visible
**And** cada aliado muestra: nombre, categoría, beneficio, distancia
**And** al hacer tap, veo información completa: teléfono, website, dirección

#### Escenario 2: Admin crea nuevo aliado
**Given** que soy admin
**When** completo el formulario de nuevo aliado (nombre, categoría, descripción, beneficio, ubicación, teléfono, website)
**Then** se inserta en `allies` con todos los datos
**And** aparece inmediatamente en el mapa de refugios

### Acceptance Criteria
- [ ] Tabla allies con business_name, category, benefit, lat/lng, phone, website, image_url
- [ ] SELECT público de todos los aliados
- [ ] INSERT/UPDATE/DELETE solo para admin
- [ ] Integración con RefugiosBloc existente (reemplazar mock data)
- [ ] Filtro por categoría
- [ ] Información de contacto y beneficio visible

### Data Flow
```
[Listar refugios]
supabase.from('allies').select('*')
  .filter usando bounding box para rendimiento

[Admin: crear]
supabase.from('allies').insert({
  business_name, category, description, benefit,
  address, phone, website, latitude, longitude, image_url
})
```

### Edge Cases
- Refugio sin coordenadas → no mostrar en mapa, mostrar en lista
- Categoría no existe → CHECK constraint en DB (categorías predefinidas)
- Refugio con solo teléfono (sin website) → mostrar solo teléfono
- Imagen de refugio no disponible → mostrar placeholder

### Error States
- Sin datos de refugios → "No hay refugios aliados en esta zona."
- Error de carga → "No se pudieron cargar los refugios. Verificá tu conexión."
- Solo admin puede crear → "No tenés permisos para gestionar aliados."

---

## Feature: Road Alerts
**ID:** F-24
**Prioridad:** P3+
**Dependencias:** F-01 (Auth), F-06 (Mapa en vivo)
**Descripción:** Sistema de alertas comunitarias en la vía. Los usuarios pueden reportar peligros (baches, derrumbes, animales, controles policiales, etc.) con tipo, severidad (info/warning/danger), ubicación y descripción. Las alertas activas se muestran en el mapa de raids y en el mapa general. Tienen expiración y sistema de upvotes.

### User Stories
- Como motero, quiero reportar un peligro en la ruta para alertar a otros riders.
- Como motero, quiero ver alertas activas en el mapa para evitar peligros.
- Como motero, quiero votar una alerta como útil para que gane visibilidad.

### Escenarios

#### Escenario 1: Reportar peligro en ruta
**Given** que estoy en un raid activo o en el mapa general
**When** mantengo presionado un punto en el mapa y selecciono "Reportar peligro"
**Then** elijo tipo (bache, derrumbe, animal, control policial, otro) y severidad (info/warning/danger)
**And** se inserta en `road_alerts` con mi user_id, tipo, descripción, ubicación
**And** aparece en el mapa para todos los usuarios

#### Escenario 2: Ver alertas activas en el mapa de raid
**Given** que estoy en un raid activo
**When** el mapa del raid carga
**Then** se superponen las alertas activas (active = true) dentro del área del raid
**And** se muestran con icono por tipo y color por severidad (info=azul, warning=amarillo, danger=rojo)

#### Escenario 3: Alerta expira automáticamente
**Given** que existe una alerta con expires_at configurado
**When** la fecha actual supera expires_at
**Then** la alerta se marca como active = false automáticamente
**And** desaparece del mapa

### Acceptance Criteria
- [ ] INSERT road_alerts por usuario autenticado
- [ ] UPDATE/DELETE por el creador
- [ ] SELECT de alertas activas para todos (público)
- [ ] Tipos: definidos en app (bache, derrumbe, animal, control, otro)
- [ ] Severidad: info, warning, danger
- [ ] expires_at opcional
- [ ] upvotes (votación)
- [ ] Mostrar en mapa de raids y mapa general
- [ ] TTS: "Peligro reportado a 2 kilómetros" en modo conducción

### Data Flow
```
[Crear alerta]
supabase.from('road_alerts').insert({
  user_id: auth.uid(),
  type: 'bache',
  title: 'Bache grande',
  description: 'Bache de ~30cm en el carril derecho',
  latitude: X, longitude: Y,
  severity: 'danger',
  active: true,
  expires_at: NOW() + INTERVAL '7 days',
  upvotes: 1
})

[Upvote]
supabase.rpc('increment_alert_upvote', { alert_id: X })
// O simplemente: UPDATE road_alerts SET upvotes = upvotes + 1 WHERE id = X

[Expiración]
Cron cada hora:
  UPDATE road_alerts SET active = false WHERE expires_at < NOW()
```

### Edge Cases
- Alerta duplicada (mismo tipo y ubicación cercana) → merge o upvote a la existente
- Usuario reporta alerta falsa → admin puede desactivar manualmente
- Múltiples alertas en el mismo punto → cluster de alertas en el mapa
- Alerta sin expires_at → se mantiene activa hasta desactivación manual o por admin
- Upvote del mismo usuario múltiples veces → validar UNIQUE(user_id, alert_id) si se implementa tabla de votos
- Alerta de peligro en raid nocturno → severidad incrementada automáticamente

### Error States
- Sin conexión al reportar → buffer local, enviar al reconectar
- Ubicación inválida → "Seleccioná una ubicación válida en el mapa."
- Tipo de alerta no soportado → "Seleccioná un tipo de alerta válido."
- Ya reportaste esta alerta → "Ya reportaste este peligro."

---

## Feature: Membresía (Basic/Premium)
**ID:** F-25
**Prioridad:** P3+
**Dependencias:** F-01 (Auth), F-02 (Users)
**Descripción:** Sistema de membresías existente (basic/premium). El plan premium desbloquea modos de raid exclusivos (Rally, Ruta Gótica, Sobrevivencia, Guerra de Clanes), edición de lugares de otros usuarios, y badges especiales en el perfil.

### User Stories
- Como motero premium, quiero acceder a modos de raid exclusivos que no están disponibles en basic.
- Como motero basic, quiero saber qué beneficios obtendría al actualizar a premium.
- Como motero premium, quiero que mi suscripción se renueve automáticamente.

### Escenarios

#### Escenario 1: Usuario basic intenta crear raid en modo premium
**Given** que soy usuario basic
**When** intento crear un raid en modo Rally
**Then** veo un mensaje: "El modo Rally es exclusivo para miembros Premium. Actualizá tu plan."
**And** se me redirige a la pantalla de suscripción

#### Escenario 2: Usuario premium crea raid en modo exclusivo
**Given** que soy usuario premium (membership.active = true)
**When** creo un raid en modo Ruta Gótica
**Then** el raid se crea normalmente
**And** veo badges premium en mi perfil y en el lobby del raid

#### Escenario 3: Membresía expira
**Given** que soy usuario premium
**When** mi membresía expira (end_date < NOW())
**Then** membership.is_active = false
**And** mi plan vuelve a basic
**And** no puedo crear raids en modos premium hasta renovar
**And** los raids premium en los que ya estoy participando NO se ven afectados

### Acceptance Criteria
- [ ] Tabla memberships existente con plan (basic/premium), start_date, end_date, is_active
- [ ] Modos premium bloqueados para basic en creación de raid
- [ ] Restricción de edición de lugares (premium puede editar cualquier lugar)
- [ ] Badge premium visible en perfil
- [ ] Al expirar, downgrade automático a basic
- [ ] Participación en raids premium existentes continúa incluso si expiró

### Data Flow
```
[Verificar premium]
supabase.from('memberships').select('is_active')
  .eq('user_id', auth.uid())
  .eq('plan', 'premium')
  .gte('end_date', NOW())
  .single()

[Crear raid — validación modo]
if (mode IN ('rally', 'ruta_gotica', 'sobrevivencia', 'guerra_clanes')) {
  // Verificar premium
  if (!isPremium) return error "Modo exclusivo Premium"
}

[Expiración]
Cron diario:
  UPDATE memberships SET is_active = false WHERE end_date < NOW() AND is_active = true
  // Notificar al usuario: "Tu membresía Premium ha expirado"
```

### Edge Cases
- Pago fallido → membresía no se activa, el usuario permanece basic
- Premium se paga in-app (Google Play/App Store) → receipt validation
- Usuario premium con membresía activa pero sin payment_ref → posible, revisar
- Cambio de plan a mitad de período → prorrateo
- Premium comprado durante raid activo → aplica inmediatamente para próximos raids

### Error States
- Pago no procesado → "Hubo un error al procesar el pago. Intentá de nuevo."
- Membresía expirada → "Tu membresía Premium expiró el [fecha]. Renová para seguir disfrutando."
- Modo no disponible → "Este modo de juego es exclusivo para miembros Premium."
- Método de pago no soportado → "Solo se aceptan pagos a través de Google Play/App Store."

---

## Feature: Follows (Amigos)
**ID:** F-26
**Prioridad:** P3+
**Dependencias:** F-01 (Auth), F-02 (Users)
**Descripción:** Sistema de amigos/seguidores existente (user_follows). Los follows permiten: invitar a raids privados directamente, ver raids de amigos en el feed, y notificaciones cuando un amigo crea o se une a un raid.

### User Stories
- Como motero, quiero seguir a otros moteros para ver sus raids.
- Como host, quiero invitar a mis amigos a raids privados directamente.
- Como motero, quiero recibir notificaciones cuando un amigo crea un raid.

### Escenarios

#### Escenario 1: Seguir a otro motero
**Given** que estoy viendo el perfil de otro motero
**When** toco "Seguir"
**Then** se inserta en user_follows (follower_id = auth.uid(), followed_id = otro_user)
**And** ahora veo sus raids públicos en mi feed

#### Escenario 2: Invitar a amigo a raid privado
**Given** que soy host de un raid privado (is_public = false)
**When** voy a la sección de invitaciones del lobby
**Then** veo una lista de mis follows
**When** selecciono un amigo para invitar
**Then** recibe una notificación Realtime en canal `user:{id}:notifications`
**And** puede unirse al raid privado directamente

#### Escenario 3: Dejar de seguir
**Given** que sigo a otro motero
**When** toco "Dejar de seguir" en su perfil
**Then** se elimina el registro de user_follows
**And** ya no veo sus raids en mi feed

### Acceptance Criteria
- [ ] user_follows con follower_id, followed_id, UNIQUE, CHECK(follower_id != followed_id)
- [ ] SELECT: ver propios follows y followers
- [ ] INSERT/DELETE: solo por el follower
- [ ] Invitación a raid privado via Realtime notification channel
- [ ] Feed de raids de amigos (consulta raids donde host_id IN follows)

### Data Flow
```
[Seguir]
supabase.from('user_follows').insert({
  follower_id: auth.uid(),
  followed_id: otherUserId
})

[Invitar a raid privado]
1. Verificar que soy host del raid
2. channel('user:{friend_id}:notifications').send({
     event: 'raid_invitation',
     payload: { raid_id, host_name, mode, scheduled_at }
   })
3. El amigo recibe notificación y puede aceptar
4. Al aceptar: INSERT raid_participants (verificar raid privado y que fue invitado)

[Feed de amigos]
supabase.from('raids').select('*')
  .in('host_id', follows_list)
  .in('status', ['planned', 'lobby'])
  .order('scheduled_at')
```

### Edge Cases
- Auto-seguimiento → CHECK (follower_id != followed_id) lo bloquea
- Seguir a usuario que ya sigues → UNIQUE constraint lo bloquea
- Invitar a amigo que ya está en el raid → mostrar "Ya es parte del raid"
- Usuario bloquea a otro → no se puede seguir ni invitar (tabla de blocks, futuro)
- Seguir a usuario baneado → permitido, pero no recibe notificaciones

### Error States
- Ya sigues a este usuario → "Ya seguís a este motero."
- No puedes seguirte a ti mismo → "No podés seguirte a vos mismo."
- Usuario no encontrado → "El usuario no existe."
- Error al invitar → "No se pudo enviar la invitación. Reintentá."
- Solo el host puede invitar → "Solo el organizador del raid puede invitar."

---

## Feature: Saved Routes
**ID:** F-27
**Prioridad:** P3+
**Dependencias:** F-01 (Auth)
**Descripción:** Unificación de los endpoints /routes y /tracks en la tabla `saved_routes`. Los usuarios pueden guardar rutas (polyline con puntos GPS) y reutilizarlas como ruta predefinida al crear un raid. Incluye datos de distancia, duración, velocidades y polyline en JSON.

### User Stories
- Como motero, quiero guardar una ruta que hice para reutilizarla después.
- Como host, quiero usar una ruta guardada como recorrido de un raid.
- Como motero, quiero ver mis rutas guardadas con estadísticas (distancia, velocidad, duración).

### Escenarios

#### Escenario 1: Guardar ruta post-raid
**Given** que acabo de completar un raid
**When** veo la pantalla de resultados
**Then** veo un botón "Guardar ruta"
**When** toco guardar
**Then** se inserta en `saved_routes` con la polyline del recorrido, distancia, duración, velocidades
**And** puedo asignarle un nombre personalizado

#### Escenario 2: Usar ruta guardada para crear raid
**Given** que tengo rutas guardadas
**When** creo un nuevo raid
**Then** veo la opción "Usar ruta guardada"
**When** selecciono una ruta guardada
**Then** el formulario se autocompleta con origen, destino y polyline de la ruta guardada

#### Escenario 3: Ver historial de rutas guardadas
**Given** que soy un usuario autenticado
**When** navego a "Mis rutas"
**Then** veo una lista de mis saved_routes con nombre, distancia, duración, fecha
**And** puedo ver el detalle de cada ruta en el mapa

### Acceptance Criteria
- [ ] saved_routes con user_id, name, polyline_json, total_distance_m, duration_seconds, avg_speed_kmh, max_speed_kmh, start/end points
- [ ] SELECT solo del propietario (RLS)
- [ ] INSERT solo por el propietario
- [ ] DELETE solo por el propietario
- [ ] Autocompletar formulario de raid con saved route
- [ ] Polyline en JSON array de [lat, lng]
- [ ] Arregla bug de endpoints /routes vs /tracks (unificado)

### Data Flow
```
[Guardar ruta post-raid]
supabase.from('saved_routes').insert({
  user_id: auth.uid(),
  name: 'Ruta a la costa',
  total_distance_m: 45000,    // 45 km
  duration_seconds: 2700,     // 45 min
  avg_speed_kmh: 60,
  max_speed_kmh: 90,
  points_count: 540,
  polyline_json: [[lat1,lng1], [lat2,lng2], ...],
  start_lat: X, start_lng: Y,
  end_lat: Z, end_lng: W,
  started_at: '2026-07-11T14:00:00Z',
  ended_at: '2026-07-11T14:45:00Z'
})

[Usar ruta para crear raid]
1. SELECT * FROM saved_routes WHERE id = routeId
2. Autocompletar:
   - origin = (start_lat, start_lng)
   - destination = (end_lat, end_lng)
   - route_data = polyline_json (opcional)
```

### Edge Cases
- Ruta guardada sin polyline (tracking desactivado) → solo origen/destino
- Ruta muy larga (500+ km) → polyline grande; considerar compresión
- Eliminar ruta que está siendo usada en un raid activo → no afecta el raid (raid tiene sus propios datos)
- Múltiples rutas con el mismo nombre → se muestran todas con fecha de creación
- Ruta guardada sin nombre → asignar "Ruta del [fecha]"

### Error States
- Polyline muy grande → "La ruta es demasiado larga para guardarse completa. Se guardará una versión resumida."
- Sin datos de ruta → "No hay datos de ruta para guardar."
- Nombre de ruta vacío → "Asignale un nombre a tu ruta guardada."
- Error al cargar ruta guardada → "No se pudo cargar la ruta guardada."

---

## Feature: Import OSM (Overpass)
**ID:** F-28
**Prioridad:** P3+
**Dependencias:** F-03 (Places)
**Descripción:** Mantenimiento de la funcionalidad de importación de datos desde OpenStreetMap via Overpass API. Permite importar lugares (talleres, gasolineras, etc.) desde OSM a la tabla `places` para enriquecer el mapa. Operación controlada por admin.

### User Stories
- Como administrador, quiero importar lugares desde OSM para poblar la base de datos.
- Como motero, quiero que el mapa tenga buena cobertura de lugares útiles para moteros.

### Escenarios

#### Escenario 1: Importar lugares desde OSM (admin)
**Given** que soy admin
**When** selecciono una región en el mapa y elijo categorías a importar (talleres, gasolineras)
**Then** se ejecuta una consulta Overpass API para la región seleccionada
**And** los resultados se insertan en `places` (evitando duplicados por coordenadas cercanas)
**And** se genera un reporte: "Se importaron 45 lugares nuevos, 12 ya existentes"

#### Escenario 2: Verificación de datos importados
**Given** que se importaron lugares de OSM
**When** un motero visita uno de esos lugares
**And** los datos son incorrectos (dirección, nombre)
**Then** el motero puede reportar la inexactitud
**And** admin puede corregir o eliminar el lugar

### Acceptance Criteria
- [ ] Consulta Overpass API por región + categorías
- [ ] Evitar duplicados (lugares a < 50m del mismo tipo)
- [ ] INSERT masivo en places con qr_token generado automáticamente
- [ ] Reporte de importación (nuevos, existentes, errores)
- [ ] Solo admin puede ejecutar importación
- [ ] Rate limiting: max 1 importación por hora

### Data Flow
```
[Overpass Query — admin]
1. Obtener bounding box de la región seleccionada
2. Construir query Overpass QL:
   [out:json][timeout:25];
   (
     node["shop"="car_repair"](bbox);
     node["amenity"="fuel"](bbox);
     node["tourism"="hotel"](bbox);
   );
   out body;
3. Parsear resultados → filtrar duplicados (lugares a < 50m existentes)
4. INSERT INTO places (name, category, latitude, longitude, qr_token, created_by=admin_id)
   VALUES ... ON CONFLICT DO NOTHING
5. RETURN { imported: N, skipped: M }
```

### Edge Cases
- Overpass API timeout (área muy grande) → dividir en cuadrantes más pequeños
- Datos de OSM incompletos (sin nombre, sin categoría) → saltar o marcar para revisión
- Categorías de OSM que no mapean exactamente a categorías de AsfaltoClub → mapeo manual
- Límite de rate de Overpass API (1 request/segundo) → throttle
- Importación duplicada en misma sesión → detectar y evitar

### Error States
- Overpass API no disponible → "No se pudo conectar con OpenStreetMap. Reintentá más tarde."
- Región demasiado grande → "La región seleccionada es muy grande. Seleccioná un área más pequeña."
- Sin resultados → "No se encontraron lugares de las categorías seleccionadas en esta región."
- Solo admin puede importar → "No tenés permisos para ejecutar importaciones."
- Rate limit excedido → "Solo se permite una importación por hora. Reintentá más tarde."

---

# Apéndice: Mapa de Features vs Tablas

| Feature | Tablas principales |
|---------|-------------------|
| F-01 Auth | `auth.users` (Supabase managed) |
| F-02 Users | `users` |
| F-03 Places | `places` |
| F-04 Clubs | `clans`, `clan_members`, `clan_messages` |
| F-05 Raids | `raids`, `raid_participants` |
| F-06 Live Map | `raid_participants` (last_lat, last_lng, etc.), Realtime channels |
| F-07 Checkpoints | `raid_checkpoints`, `raid_checkpoint_verifications` |
| F-08 Chat | `raid_messages`, `clan_messages` |
| F-09 Post-raid | `raid_participants` (xp_earned, etc.), `user_xp` |
| F-10 Safety | `drive_scores`, `raids` (adjusted_eta) |
| F-11 Voice | `voice_channels`, `raid_participants` (livekit_token) |
| F-12 Reputation | `user_xp` (trust_score), `mentor_relationships`, `conduct_reports` |
| F-13 Progression | `user_xp`, `achievements`, `user_achievements`, `leaderboard_snapshots` |
| F-14 SOS | `sos_events`, `users` (emergency_contact) |
| F-15 Spectator | `raid_spectators`, `raids` (allow_spectators) |
| F-16 Economy | `user_xp` (coins), `shop_items`, `user_purchases` |
| F-17 Battle Pass | `battle_passes`, `battle_pass_progress`, `battle_pass_missions`, `user_missions_progress` |
| F-18 Weather | `raids` (weather_conditions, adjusted_eta, is_night_raid) |
| F-19 Anti-cheat | `anti_cheat_log`, `raid_participants` (anti_cheat_flags, is_flagged) |
| F-20 Replay | `raid_position_log` |
| F-21 Territories | `clan_territories` |
| F-22 Admin | `conduct_reports`, `anti_cheat_log`, `allies`, `auth.users` (role) |
| F-23 Allies | `allies` |
| F-24 Road Alerts | `road_alerts` |
| F-25 Membership | `memberships` |
| F-26 Follows | `user_follows` |
| F-27 Routes | `saved_routes` |
| F-28 OSM Import | `places` |

---

*Fin del documento — 28 features especificadas con user stories, escenarios Gherkin-like, acceptance criteria, data flows, edge cases y error states.*
