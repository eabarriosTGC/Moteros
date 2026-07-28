# SDD Delta — Navegación Hand-off + Geofence de Motoposadas

**Change:** `rediseno-minimalista-core-viajero` (delta extension)
**Date:** 2026-07-28
**Status:** Propuesto para aprobación

---

## Rationale

En vez de construir trazado de rutas, ETA, instrucciones paso a paso y recálculo
dentro de la app (costoso, frágil, nunca será tan bueno como Waze/Maps), se
delega la navegación activa a esas apps mediante deep links. El tracker propio
de AsfaltoClub corre en background capturando el trayecto real como fuente de
verdad de km y validación de visitas.

Esto elimina la necesidad de GraphHopper para routing, geocoding reverso de vías,
y cualquier UI de navegación paso a paso — sin perder la capacidad de medir,
gamificar y validar viajes.

---

## ADDED: F-N10 — Hand-off Navigation Pattern

### F-N10-R1: Deep link a navegación externa
El sistema MUST proporcionar un botón "Cómo llegar" desde la tarjeta de detalle
de cada motoposada/POI que abra la app de navegación externa (Waze o Google Maps)
con las coordenadas del destino.

| ID | Req | Prio |
|----|-----|:----:|
| F-N10-R1 | La tarjeta de detalle de motoposada SHALL mostrar botón(es) "Cómo llegar" que abran navegación externa. | MUST |
| F-N10-R2 | El sistema SHALL ofrecer al usuario elegir entre Waze y Google Maps cuando ambos estén instalados. | MUST |
| F-N10-R3 | El deep link SHALL usar las coordenadas exactas (lat, lng) del POI como destino. | MUST |
| F-N10-R4 | Si ninguna app de navegación está instalada, el sistema SHALL mostrar un mensaje claro y NO hacer nada (no fallback silencioso a web). | SHOULD |

```
Scenario: Usuario quiere llegar a una motoposada
  Given: El usuario está viendo el detalle de una motoposada en el mapa o en Explorar
  When: Toca "Cómo llegar"
  Then: Se muestra un selector con Waze y Google Maps
  And: Al seleccionar uno, se abre la app externa con el destino del POI

Scenario: Solo Waze está instalado
  Given: El usuario no tiene Google Maps instalado
  When: Toca "Cómo llegar"
  Then: Se abre Waze directamente (sin selector)
```

### F-N10-R5: URLs de deep link

```
Google Maps: https://www.google.com/maps/dir/?api=1&destination={lat},{lng}
Waze: https://waze.com/ul?ll={lat},{lng}&navigate=yes
```

Ambas URLs abren la app nativa si está instalada, o el navegador como fallback.
El sistema DEBE detectar presencia de las apps antes de mostrar el selector.

---

## ADDED: F-N11 — Geofence + Dwell Time Validation

### F-N11-R1: Definición de geofence
Cada motoposada SHALL tener un geofence implícito de radio configurable
(default: 100m) alrededor de sus coordenadas.

| ID | Req | Prio |
|----|-----|:----:|
| F-N11-R1 | El sistema SHALL definir un geofence de 100m de radio por defecto alrededor de cada motoposada. | MUST |
| F-N11-R2 | El radio del geofence SHOULD ser configurable por motoposada (columna `validation_radius` en la tabla). | SHOULD |
| F-N11-R3 | El sistema SHALL detectar entrada/salida del geofence usando datos del tracker GPS en background (no polling constante). | MUST |
| F-N11-R4 | La visita SOLO se marca como válida si el usuario permanece dentro del geofence por un tiempo mínimo (default: 2 minutos). | MUST |
| F-N11-R5 | El dwell time mínimo SHOULD ser configurable por motoposada. | SHOULD |

```
Scenario: Usuario visita una motoposada
  Given: El usuario tiene el tracker activo en background
  When: Las coordenadas del tracker entran al geofence (radio 100m) de una motoposada
  Then: El sistema inicia un timer de dwell time
  And: NO marca la visita como completada todavía

Scenario: Usuario permanece el tiempo suficiente
  Given: El timer de dwell está corriendo para una motoposada
  When: Pasan 2 minutos y el usuario sigue dentro del geofence
  Then: El sistema marca la visita como válida
  And: Dispara XP, insignia correspondiente y prompt de foto-recuerdo

Scenario: Usuario se va antes del dwell time
  Given: El timer de dwell está corriendo
  When: El usuario sale del geofence antes de los 2 minutos
  Then: El sistema cancela el timer
  And: NO marca la visita

Scenario: Usuario pasa en moto sin detenerse
  Given: El tracker muestra velocidad > 10 km/h dentro del geofence
  When: El usuario cruza el área en < 30 segundos
  Then: El sistema NO inicia el timer de dwell (velocidad incompatible con visita)
```

### F-N11-R6: Reutilización del patrón anti-cheat
La lógica de geofence + dwell time DEBE reutilizar el mismo patrón de
`anti_cheat_flags` que ya existe en `raid_participants`, en vez de crear
una estructura de validación separada.

| ID | Req | Prio |
|----|-----|:----:|
| F-N11-R6 | La validación de visitas a motoposadas SHALL usar el mismo esquema de `anti_cheat_flags` que raids. | SHOULD |

### F-N11-R7: Datos a registrar en visita válida

| Campo | Fuente |
|-------|--------|
| `motoposada_id` | Del POI visitado |
| `user_id` | Usuario autenticado |
| `visited_at` | Timestamp del momento en que se cumplió dwell time |
| `dwell_seconds` | Tiempo real dentro del geofence (segundos) |
| `tracked_route_id` | FK al viaje activo (route_history) |
| `anti_cheat_flags` | JSON con metadatos: speed_avg, speed_max, geofence_radius, validación |
| `evidence_photo_url` | Opcional, subida por el usuario después del prompt |

---

## ADDED: F-N12 — Tracker Background Persistence

### F-N12-R1: Tracker debe sobrevivir a foreground de Waze/Maps
El tracker GPS en background SHALL continuar activo cuando el usuario abre Waze
o Google Maps mediante deep link (la app pasa a segundo plano).

| ID | Req | Prio |
|----|-----|:----:|
| F-N12-R1 | El tracker SHALL mantener el servicio de ubicación activo cuando la app pasa a background. | MUST |
| F-N12-R2 | El sistema SHALL solicitar permiso de ubicación "siempre" (Android) / "while in use + background capability" (iOS). | MUST |
| F-N12-R3 | Si el usuario deniega permiso de background, el tracker SHALL seguir funcionando en foreground pero advertir que viajes con navegación externa no se registrarán. | MUST |
| F-N12-R4 | El tracker SHALL mantener estado interno (puntos acumulados, distancia, tiempo) aunque la app esté en background por períodos de hasta 8 horas. | MUST |

```
Scenario: Usuario inicia viaje y abre Waze
  Given: El tracker está activo en RodarScreen
  When: El usuario toca "Cómo llegar" y Waze se abre al frente
  Then: El tracker continúa en background recolectando puntos GPS
  And: Al volver a AsfaltoClub, el viaje sigue activo con todos los datos acumulados
```

### F-N12-R5: Restauración de estado al volver a foreground
Cuando el usuario regresa de Waze/Maps a AsfaltoClub, el tracker SHALL
restaurar su estado visual inmediatamente sin pérdida de datos.

| ID | Req | Prio |
|----|-----|:----:|
| F-N12-R5 | Al volver a foreground, el tracker SHALL mostrar el estado actual sin reconexión ni reinicio. | MUST |
| F-N12-R6 | El sistema SHALL manejar el ciclo `pause → background → foreground → resume` sin duplicar puntos ni perder segmentos. | MUST |

---

## MODIFIED: F-N02 (Rodar Screen)

### F-N02-R9: POI cards con botón de navegación
Se MODIFICA el comportamiento de los markers de motoposada en el mapa para
incluir el flujo de hand-off a navegación externa.

| ID | Req | Prio |
|----|-----|:----:|
| F-N02-R9 | Al tocar un marker de motoposada en el mapa, SHALL aparecer una tarjeta con info del lugar + botón(es) "Cómo llegar". | MUST |

---

## REMOVED (confirmación explícita)

| Feature | Motivo | Reemplazo |
|---------|--------|-----------|
| GraphHopper routing para trazado de rutas | No necesario — Waze/Maps lo hacen mejor | Deep link |
| ETA en HUD del tracker | No necesario — Waze/Maps lo muestran | Deep link |
| Geocoding reverso para nombre de vía | No necesario — Waze/Maps lo muestran | — |
| UI de navegación paso a paso | Costo alto de desarrollo y mantenimiento | Deep link |
| Recálculo automático de ruta | No necesario — Waze/Maps lo manejan | — |

---

## Resumen de impacto en arquitectura

```
Estado anterior (SDD original):
  RodarScreen
    ├── FlutterMap (OSM tiles + POIs)
    ├── FAB "Rodar" → RouteTrackerScreen
    │     └── (sin conexión a navegación externa)
    └── POI markers → tarjeta info (solo info)

Estado nuevo (con delta):
  RodarScreen
    ├── FlutterMap (OSM tiles + POIs)
    ├── FAB "Rodar" → RouteTrackerScreen
    │     └── (tracker en background mientras Waze/Maps al frente)
    ├── POI markers → tarjeta info
    │     └── Botón "Cómo llegar" → selector Waze/Maps → deep link
    └── GeofenceEngine
          └── Escucha puntos del tracker activo
          └── Detecta entrada/salida de geofences de motoposadas
          └── Timer de dwell time
          └── Marca visita válida → XP + badge + prompt foto
```

## Nuevos archivos

| Archivo | Propósito |
|---------|-----------|
| `lib/core/services/navigation_handler.dart` | Lógica de deep links: detectar apps instaladas, lanzar Waze/Maps con coordenadas |
| `lib/core/services/geofence_service.dart` | Servicio de geofence: recibe puntos del tracker, evalúa contra POIs cercanos, maneja dwell time |
| `lib/features/refugios/data/models/visit_validation_model.dart` | Modelo para registro de visitas validadas con metadatos anti-cheat |

## Supabase cambios

| Tabla | Acción |
|-------|--------|
| `motoposadas` | ADD columna `validation_radius` (INT, default 100) — radio del geofence en metros |
| `motoposadas` | ADD columna `dwell_min_seconds` (INT, default 120) — tiempo mínimo de permanencia |
| `motoposada_visits` (NUEVA) | `id`, `user_id`, `motoposada_id`, `visited_at`, `dwell_seconds`, `tracked_route_id`, `anti_cheat_flags`, `evidence_photo_url` |
