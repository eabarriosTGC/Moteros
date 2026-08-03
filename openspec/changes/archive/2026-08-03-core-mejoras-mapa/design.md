# SDD Technical Design — Core Map & UX Improvements

> **Proyecto:** Moteros / AsfaltoClub
> **Documento:** Technical Design para `core-mejoras-mapa`
> **Base:** `proposal.md` + 5 delta specs
> **Estado:** ✅ Aprobado para implementación

---

## 1. F-M1 — Map Search (Búsqueda de lugares en Rodar)

### 1.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| SearchBloc location | `lib/features/map/` (new module) | Co-locate in `lib/features/dashboard/` | **Option B — co-locate** | Search is tightly coupled to RodarScreen; a separate module adds navigation friction with zero reuse. Dashboard already owns the map. |
| Nominatim client | New `NominatimDatasource` | Extend existing `ApiClient` | **New datasource** | Nominatim has its own base URL, custom User-Agent, and rate-throttle semantics. Extending ApiClient would pollute a generic HTTP client with Nominatim-specific logic. |
| Rate throttle | Bloc-level (debounce + BLoC timer) | Dio interceptor | **Bloc-level** | The 300ms debounce is already BLoC-level (event transformer). A Dio interceptor would throttle *all* calls to the same host including cache hits, which is wrong. Bloc controls when to fire. |
| Cache strategy | In-memory `Map<String, List<SearchResult>>` with TTL | SharedPreferences / Hive | **In-memory with TTL** | Small data (place names + coords), ephemeral, lost on app restart is acceptable. No disk persistence needed. |

### 1.2 Module structure (co-located in dashboard)

```
lib/features/dashboard/
├── data/
│   └── datasources/
│       └── nominatim_datasource.dart          ← NEW
├── domain/
│   └── entities/
│       └── search_result_entity.dart           ← NEW
├── presentation/
│   ├── bloc/
│   │   ├── search_bloc.dart                    ← NEW
│   │   ├── search_event.dart                   ← NEW
│   │   └── search_state.dart                   ← NEW
│   ├── widgets/
│   │   ├── place_search_bar.dart               ← NEW
│   │   └── search_results_list.dart            ← NEW
│   └── screens/
│       └── rodar_screen.dart                   ← MODIFIED
```

### 1.3 Data flow

```
RodarScreen
  ├── PlaceSearchBar (onChanged → debounce 300ms)
  │     └── SearchBloc.add(SearchPlace(query))
  │           ├── check cache → hit? emit cache
  │           └── miss? → NominatimDatasource.search(query)
  │                 ├── Dio GET https://nominatim.openstreetmap.org/search
  │                 │     ├── headers: {'User-Agent': 'MoterosApp/1.0 (contact@moteros.app)'}
  │                 │     ├── params: {q, format: 'json', limit: 5, addressdetails: 0}
  │                 │     └── throttle: 1 req/sec (Bloc-level ticker)
  │                 ├── parse → List<SearchResultEntity>
  │                 ├── store in cache (5min TTL)
  │                 └── emit SearchResultsLoaded(results)
  │
  └── SearchResultsList (BlocBuilder<SearchBloc>)
        └── onTap result
              ├── SearchBloc.add(SelectPlace(result))
              ├── _mapController.move(result.latLng, 15)
              ├── show temporary Marker (color: secondary cyan)
              └── emit PlaceSelected(result) → clear list after 5s
```

### 1.4 Widget tree changes (RodarScreen)

```
RodarScreen (MODIFIED)
├── Stack
│   ├── FlutterMap (existing)
│   │   ├── TileLayer (existing — dark tiles)
│   │   ├── MarkerLayer (existing — motoposada POIs)
│   │   ├── MarkerLayer (NEW — temporary search result marker)
│   │   └── MarkerLayer (NEW — blue dot, see F-M3)
│   ├── Positioned(top) — KmOverlay (existing)
│   ├── Positioned(top, below KmOverlay)          ← NEW
│   │   └── PlaceSearchBar
│   │         └── TextField + SearchResultsList (conditional)
│   ├── Positioned(bottom-right, above FAB)        ← NEW (F-M3)
│   │   └── RecenterButton (FloatingActionButton.small)
│   ├── RodarFAB (existing)
│   └── DraggableScrollableSheet (existing)
```

### 1.5 BLoC layer crossing

| From | To | Method |
|------|----|--------|
| RodarScreen | SearchBloc | New BlocProvider (co-located in dashboard) |
| RodarScreen | MotoposadasBloc | Existing (unchanged) |
| RodarScreen | DashboardBloc | Existing (unchanged) |
| SearchBloc | NominatimDatasource | Direct instantiation, no DI framework |
| NominatimDatasource | Dio (standalone) | New Dio instance with Nominatim base URL |

### 1.6 Testing strategy

| Layer | Test | Tool |
|-------|------|------|
| BLoC | Debounce produces single event after 300ms | `flutter_test` + `bloc_test` |
| BLoC | Cache returns stored results, no HTTP call | `flutter_test` + mock datasource |
| BLoC | Rate throttle: 2 rapid queries → 1 HTTP call | `flutter_test` |
| Datasource | Correct Nominatim URL, User-Agent, params | `flutter_test` (unit) |
| Widget | SearchBar renders, typing triggers debounce | `flutter_test` |
| Widget | Results list renders 5 items max, tap emits select | `flutter_test` |
| Widget | Temporary marker shows/hides | `flutter_test` |

### 1.7 Rollback

- Feature-flag disable via `SharedPreferences` key `search_enabled`.
- If disabled, `PlaceSearchBar` widget returns `SizedBox.shrink()`.
- No schema changes, no migrations.

---

## 2. F-M2 — Tourist POIs (Puntos de Interés Turístico)

### 2.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Schema | Separate `tourist_pois` table | Extend `motoposadas` with `poi_type`, `is_tourist`, `city` | **Option B — extend existing** | Proposal explicitly mandates reuse. Tourist POI is a subtype — same CRUD, same markers, same map. Separate table duplicates FK relations, RLS, and form UI for marginal gain. |
| Auth check | BLoC level (check profile before insert) | Datasource level (RLS policy) | **Both — BLoC + RLS** | BLoC level gives fast 403 UX (no network round-trip). RLS is defense-in-depth: even if client bypasses BLoC, Supabase rejects. |
| Bloc reuse | Reuse `MotoposadasBloc` with new `CreateTouristPoi` event | Separate `TouristPoiBloc` | **Reuse MotoposadasBloc** | Tourist POI is a motoposada subtype. Same load, display, review, request flow. Separate bloc duplicates ~80% of handler code. |
| Profile check source | `profiles` table query | JWT claims | **profiles table** | `is_city_curator` and `curator_city` are dynamic (admin can grant/revoke). JWT claims require re-auth on change. Querying profiles is correct. |

### 2.2 Module structure

```
lib/features/refugios/                           ← EXISTING, extended
├── data/
│   └── models/
│       └── motoposada_model.dart                 ← MODIFIED (add poi_type, is_tourist, city)
├── presentation/
│   ├── bloc/
│   │   ├── motoposadas_event.dart                ← MODIFIED (add CreateTouristPoi)
│   │   ├── motoposadas_state.dart                ← MODIFIED (add TouristPoiCreated)
│   │   └── motoposadas_bloc.dart                 ← MODIFIED (_onCreateTouristPoi handler)
│   ├── screens/
│   │   └── create_motoposada_screen.dart          ← MODIFIED (add tourist toggle + city field)
│   └── widgets/
│       └── tourist_poi_marker.dart                ← NEW (distinct icon/color)
```

### 2.3 Supabase schema migrations

```sql
-- Migration: profiles table
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_city_curator BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS curator_city TEXT;

-- Migration: motoposadas table
ALTER TABLE motoposadas
  ADD COLUMN IF NOT EXISTS poi_type TEXT DEFAULT 'standard',  -- 'standard' | 'tourist'
  ADD COLUMN IF NOT EXISTS is_tourist BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS city TEXT;

-- RLS: curator-only create for tourist POIs
CREATE POLICY "curator_create_tourist" ON motoposadas
  FOR INSERT WITH CHECK (
    (poi_type != 'tourist') OR
    (poi_type = 'tourist' AND EXISTS (
      SELECT 1 FROM profiles
      WHERE user_id = auth.uid()
        AND is_city_curator = true
        AND curator_city = city
    ))
  );

-- RLS: auto-approve tourist POIs (RLS already allows read; is_approved = true by default)
-- Tourist POIs bypass moderation: set is_approved = true on insert when poi_type = 'tourist'
```

### 2.4 Sequence diagram — Tourist POI creation

```
Curator                    CreateMotoposadaScreen        MotoposadasBloc        Supabase
  │                              │                          │                     │
  │  toggles "Visita obligada"   │                          │                     │
  │─────────────────────────────>│                          │                     │
  │                              │                          │                     │
  │  fills city + other fields   │                          │                     │
  │─────────────────────────────>│                          │                     │
  │                              │                          │                     │
  │  taps "PUBLICAR"             │                          │                     │
  │─────────────────────────────>│                          │                     │
  │                              │  CreateTouristPoi(event) │                     │
  │                              │─────────────────────────>│                     │
  │                              │                          │                     │
  │                              │                          │ 1. SELECT profiles  │
  │                              │                          │    WHERE user_id    │
  │                              │                          │─────────────────────>
  │                              │                          │<────────────────────
  │                              │                          │ {is_city_curator,   │
  │                              │                          │  curator_city}      │
  │                              │                          │                     │
  │                              │                          │ if !is_curator      │
  │                              │                          │ OR city mismatch    │
  │                              │                          │ → emit Error(403)   │
  │                              │<─ TouristPoiForbidden ──│                     │
  │                              │                          │                     │
  │                              │                          │ else:               │
  │                              │                          │ 2. INSERT motoposada│
  │                              │                          │ poi_type='tourist'  │
  │                              │                          │ is_tourist=true     │
  │                              │                          │ is_approved=true    │
  │                              │                          │─────────────────────>
  │                              │                          │<────────────────────
  │                              │                          │ {id: 42}            │
  │                              │                          │                     │
  │                              │<── TouristPoiCreated ───│                     │
  │                              │                          │                     │
  │  SnackBar "✅ Creada"        │                          │                     │
  │<─────────────────────────────│                          │                     │
  │  pops back + refresh map     │                          │                     │
```

### 2.5 BLoC changes (MotoposadasBloc)

New event `CreateTouristPoi`:
- Extends `CreateMotoposada` with: `city`, `poiType = 'tourist'`
- Handler `_onCreateTouristPoi`:
  1. `SELECT is_city_curator, curator_city FROM profiles WHERE user_id = _uid`
  2. If `!is_city_curator || curator_city != city` → emit `TouristPoiForbidden`
  3. Else → INSERT (same as `_onCreate` but adds `poi_type`, `is_tourist`, `city`, `is_approved = true`)

### 2.6 Widget changes — CreateMotoposadaScreen

- Add toggle: "¿Es un lugar de visita obligada?" (Switch)
- When toggled: show `city` TextField (autocomplete cities list)
- When toggled: hide `visibility`, `max_guests` fields (not relevant for tourist POIs)
- On submit: dispatch `CreateTouristPoi` instead of `CreateMotoposada`

### 2.7 Marker distinctiveness — RodarScreen

Tourist POIs get a different marker:
- Icon: `Icons.star_rounded` (instead of home/garage)
- Color: `AppColors.warning` (yellow) instead of `AppColors.primary` (amber)
- Label prefix: "⭐ " before name

### 2.8 BLoC layer crossing

| From | To | Method |
|------|----|--------|
| CreateMotoposadaScreen | MotoposadasBloc | Existing (unchanged) |
| RodarScreen | MotoposadasBloc | Existing (filter `is_tourist` for icon) |

### 2.9 Testing strategy

| Layer | Test | Tool |
|-------|------|------|
| BLoC | Curator with matching city → TouristPoiCreated | `flutter_test` + mock Supabase |
| BLoC | Non-curator → TouristPoiForbidden (403) | `flutter_test` |
| BLoC | Curator wrong city → TouristPoiForbidden | `flutter_test` |
| Widget | Tourist toggle shows/hides city field | `flutter_test` |
| Widget | Tourist marker renders with star icon | `flutter_test` |
| RLS | Direct INSERT as non-curator → rejected | Manual / pgTAP |

### 2.10 Rollback

- Drop columns: `ALTER TABLE motoposadas DROP COLUMN poi_type, is_tourist, city`
- Drop columns: `ALTER TABLE profiles DROP COLUMN is_city_curator, curator_city`
- Drop RLS policy: `DROP POLICY curator_create_tourist ON motoposadas`
- Dart: remove event handler, restore create form (additive column check nullable → graceful)

---

## 3. F-M3 — Map Location (Blue Dot + Heading + Recenter)

### 3.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Position stream | New `MapLocationBloc` | Reuse `LocationTrackingService` stream directly in widget | **Option B — reuse tracker** | Tracker already owns permission + position stream. Adding a bloc duplicates the stream subscription and creates sync issues. The map dot just needs current position, not tracking state. |
| Heading source | `geolocator` heading (device compass) | `flutter_compass` package | **geolocator** | Already a dependency. `Position.heading` field from `geolocator` is the fused sensor heading (compass + gyro) — more accurate than raw magnetometer. No new package needed. |
| Update threshold | 5m displacement OR 5° heading | 3m / 10° | **5m / 5°** | Spec says ≤5m / ≤5°. Motorcycle speeds mean 5m is a fraction of a second — fine for map display. 5° gives smooth heading rotation without jitter. |
| Recenter button | FAB in RodarScreen | Separate widget | **FAB in RodarScreen** | Co-located with map. A separate widget would need to pass MapController across widget boundaries. |

### 3.2 Module structure

```
lib/core/services/
  └── location_tracking_service.dart               ← MODIFIED (expose position+heading stream)

lib/features/dashboard/
  └── presentation/
      └── widgets/
          ├── blue_dot_marker.dart                  ← NEW
          └── recenter_button.dart                  ← NEW
      └── screens/
          └── rodar_screen.dart                     ← MODIFIED
```

### 3.3 Service extension — LocationTrackingService

Add a lightweight "passive" position stream that does NOT record trace points:

```dart
/// Passive position stream for map display (no tracking, no trace recording).
Stream<Position> get passivePositionStream =>
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,       // 5m threshold
        timeLimit: null,
      ),
    );

/// Heading stream from geolocator (fused compass+gyro).
/// Only emits when heading changes by >= 5°.
Stream<double> get headingStream =>
    passivePositionStream
        .map((p) => p.heading)
        .where((h) => h.isFinite && h >= 0)
        .distinct((prev, next) => (next - prev).abs() < 5);
```

### 3.4 Widget tree — RodarScreen additions

```
RodarScreen (MODIFIED)
├── Stack
│   ├── FlutterMap
│   │   ├── TileLayer (existing)
│   │   ├── MarkerLayer (existing motoposadas)
│   │   ├── MarkerLayer (NEW — search result, F-M1)
│   │   └── MarkerLayer (NEW — BlueDotMarker)
│   │         └── StreamBuilder<Position>
│   │               └── BlueDotMarker(heading: heading, latLng: position)
│   ├── PlaceSearchBar (NEW, F-M1)
│   ├── RecenterButton (NEW, F-M3)
│   │     └── Positioned(bottom: 100, right: 16)
│   │           └── FloatingActionButton.small
│   │                 └── Icons.my_location
│   │                 └── onPressed: _mapController.move(currentPos, zoom)
│   └── RodarFAB (existing)
```

### 3.5 BlueDotMarker design

```dart
class BlueDotMarker extends StatelessWidget {
  final LatLng position;
  final double heading;
  
  // Visual: blue filled circle (radius 8dp) + white border (2dp)
  // Heading: small triangle/arrow pointing in heading direction
  // Opacity: 0.9 (slightly transparent to see map underneath)
  
  // Color: Color(0xFF4285F4) — Google Maps blue
  // Outer glow: Color(0xFF4285F4).withAlpha(30), blurRadius 8
}
```

### 3.6 BLoC layer crossing

| From | To | Method |
|------|----|--------|
| RodarScreen (initState) | LocationTrackingService.instance | Direct service call (requestPermission) |
| RodarScreen (StreamBuilder) | LocationTrackingService.passivePositionStream | Stream listen in widget |
| RecenterButton | MapController (local) | Direct _mapController.move() |

No new bloc. The position stream is UI-local state via `StreamBuilder`. This avoids building a bloc with 2 states (position+heading) that mirrors what a stream already provides natively.

### 3.7 Testing strategy

| Layer | Test | Tool |
|-------|------|------|
| Widget | BlueDotMarker renders with correct color/size | `flutter_test` |
| Widget | BlueDotMarker rotates with heading changes | `flutter_test` |
| Widget | RecenterButton calls mapController.move | `flutter_test` |
| Widget | Permission denied → no blue dot, no errors | `flutter_test` |
| Unit | passivePositionStream uses correct distanceFilter | Unit test with mock geolocator |

### 3.8 Rollback

- Remove BlueDotMarker from MarkerLayer in rodar_screen.dart
- Remove RecenterButton widget
- Remove passivePositionStream/headingStream from LocationTrackingService
- No schema changes

---

## 4. F-M4 — Map Navigation Detection (Platform Config Fix)

### 4.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Approach | Config-only (manifest + plist) | Runtime permission check | **Config-only** | Android 11+ requires `<queries>` to see other packages. iOS requires `LSApplicationQueriesSchemes`. These are declarative, not runtime. No code changes needed beyond logging. |
| Logging | NavigationHandler logs before/after | Separate debug utility | **NavigationHandler** | Add `debugPrint` in `canLaunchWaze()`/`canLaunchGoogleMaps()`. Existing methods are the right place. |

### 4.2 Android — exact XML snippet

File: `android/app/src/main/AndroidManifest.xml`

Add inside existing `<queries>` block (after the PROCESS_TEXT intent):

```xml
<queries>
    <!-- Existing PROCESS_TEXT query -->
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
    <!-- NEW: Navigation app detection (Android 11+ package visibility) -->
    <package android:name="com.waze" />
    <package android:name="com.google.android.apps.maps" />
</queries>
```

### 4.3 iOS — exact Plist snippet

File: `ios/Runner/Info.plist`

Add before `</dict>` (closing root dict):

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>waze</string>
    <string>comgooglemaps</string>
</array>
```

### 4.4 NavigationHandler logging addition

In `lib/core/services/navigation_handler.dart`:

```dart
static Future<bool> canLaunchWaze() async {
  try {
    final result = await canLaunchUrl(
      Uri.parse('https://waze.com/ul?ll=4.0,-74.0&navigate=yes'),
    );
    debugPrint('[NavHandler] canLaunchWaze: $result (before fix)');
    return result;
  } catch (e) {
    debugPrint('[NavHandler] canLaunchWaze error: $e');
    return false;
  }
}
// Same pattern for canLaunchGoogleMaps
```

### 4.5 Affected files

| File | Change | Detail |
|------|--------|--------|
| `android/app/src/main/AndroidManifest.xml` | MODIFIED | 2 `<package>` entries in `<queries>` |
| `ios/Runner/Info.plist` | MODIFIED | `LSApplicationQueriesSchemes` array |
| `lib/core/services/navigation_handler.dart` | MODIFIED | `debugPrint` before/after canLaunchUrl |

### 4.6 Testing strategy

| Test | How | Tool |
|------|-----|------|
| Android 11+: `canLaunchUrl(Waze)` → true | Manual on device | Physical Android 11+ device |
| iOS: `canLaunchUrl(waze://)` → true | Manual on device | Physical iOS device |
| Logs show result | Check `flutter run` output | Terminal |
| Existing NavigationHandler tests still pass | Unit test | `flutter_test` |

### 4.7 Rollback

- Android: delete the 2 `<package>` lines from `<queries>`
- iOS: delete `LSApplicationQueriesSchemes` key
- Logging: remove `debugPrint` lines (or keep, they're harmless)

---

## 5. F-M5 — Light Theme (Tema Claro)

### 5.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| ThemeCubit location | `lib/core/theme/theme_cubit.dart` (new file in existing core) | `lib/features/theme/` (new module) | **Option A — core file** | Theme is a cross-cutting concern, not a feature. Following existing pattern (`app_theme.dart` lives in `lib/core/theme/`). A Cubit is sufficient (no async events), lighter than BLoC. |
| Persistence | SharedPreferences | Hive / secure storage | **SharedPreferences** | Already a dependency. Theme preference is non-sensitive. Single boolean key. |
| Tile layer switch | Different `urlTemplate` in TileLayer | Separate TileLayer conditionally | **Different urlTemplate** | `flutter_map` TileLayer accepts a `urlTemplate` string. Just swap the string based on theme — no duplicate widget trees. |
| Day tile URL | CartoDB Positron (light) | OSM standard | **CartoDB Positron** | Positron is designed for light backgrounds, high contrast, good in sunlight. Already using CartoDB dark for the dark theme — consistent provider. |

### 5.2 Module structure

```
lib/core/theme/
├── design_tokens.dart                             ← MODIFIED (add light color palette)
├── app_theme.dart                                 ← MODIFIED (add AppTheme.light getter)
└── theme_cubit.dart                               ← NEW
```

### 5.3 ThemeCubit

```dart
/// Manages theme mode state. Persisted to SharedPreferences.
/// Uses Cubit (not BLoC) — theme toggle is synchronous state, no async events.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark) {
    _load();
  }

  static const _key = 'theme_mode'; // 'dark' | 'light'

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_key) ?? 'dark';
    emit(mode == 'light' ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    emit(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
  }
}
```

### 5.4 Light ThemeData — M3 token inversion

Current dark theme palette → light theme palette:

| Dark Token | Dark Value | Light Token | Light Value | Rationale |
|------------|-----------|-------------|-------------|-----------|
| `background` | `#0A0A0F` | `background` | `#F5F5F0` | Warm off-white — comfortable in sunlight, not pure #FFF which glares |
| `surface` | `#1A1A24` | `surface` | `#FFFFFF` | Pure white for cards — maximum contrast |
| `elevated` | `#121218` | `elevated` | `#F0F0EB` | Slightly darker than background for depth |
| `monitor` | `#08080C` | `monitor` | `#E8E8E0` | Map background — light but not white |
| `overlay` | `#DD0D0D14` | `overlay` | `#DDFFFFFF` | Semi-transparent white instead of dark |
| `input` | `#1E1E2A` | `input` | `#FFFFFF` | White input fields with border |
| `primary` | `#FF8C00` | `primary` | `#E67A00` | Slightly darker amber for light bg contrast |
| `primaryDark` | `#CC7000` | `primaryDark` | `#CC6600` | Darker variant |
| `textPrimary` | `#EAEAEA` | `textPrimary` | `#1A1A1A` | Near-black on light bg |
| `textSecondary` | `#999999` | `textSecondary` | `#666666` | Medium gray |
| `textMuted` | `#666666` | `textMuted` | `#999999` | Lighter gray |
| `textDisabled` | `#444444` | `textDisabled` | `#CCCCCC` | Very light gray |
| `border` | `#2A2A36` | `border` | `#DDDDDD` | Light gray borders |
| `borderLight` | `#22222E` | `borderLight` | `#EEEEE8` | Very subtle border |
| **Secondary** | `#00D4FF` | — | **unchanged** | Cyan works on both dark and light |
| **Success** | `#39FF14` | `success` | `#2ECC40` | Darker green needed on light |
| **Error** | `#FF2D55` | `error` | `#CC2440` | Darker red on light |

Design tokens additions:

```dart
// In design_tokens.dart — light palette additions
// Light backgrounds
static const Color lightBackground = Color(0xFFF5F5F0);
static const Color lightSurface = Color(0xFFFFFFFF);
static const Color lightElevated = Color(0xFFF0F0EB);
static const Color lightMonitor = Color(0xFFE8E8E0);
static const Color lightOverlay = Color(0xDDFFFFFF);
static const Color lightInput = Color(0xFFFFFFFF);

// Light text
static const Color lightTextPrimary = Color(0xFF1A1A1A);
static const Color lightTextSecondary = Color(0xFF666666);
static const Color lightTextMuted = Color(0xFF999999);
static const Color lightTextDisabled = Color(0xFFCCCCCC);

// Light border
static const Color lightBorder = Color(0xFFDDDDDD);
static const Color lightBorderLight = Color(0xFFEEEEE8);
static const Color lightTrackInactive = Color(0xFFE0E0E0);

// Light semantic (adjusted for light backgrounds)
static const Color lightSuccess = Color(0xFF2ECC40);
static const Color lightError = Color(0xFFCC2440);
static const Color lightPrimary = Color(0xFFE67A00);
```

### 5.5 AppTheme.light getter

```dart
static ThemeData get light => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: const ColorScheme.light(
    primary: AppColors.lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryDark,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.black,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    surfaceContainerHighest: AppColors.lightElevated,
    onSurfaceVariant: AppColors.lightTextSecondary,
    error: AppColors.lightError,
    onError: Colors.white,
    outline: AppColors.lightBorder,
    outlineVariant: AppColors.lightBorderLight,
  ),
  // ... same textTheme (both themes use same typography)
  // ... same component themes with light color references
);
```

### 5.6 Tile layer swap

In `rodar_screen.dart`:

```dart
// In build():
final isDark = context.watch<ThemeCubit>().state == ThemeMode.dark;

TileLayer(
  urlTemplate: isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c'],
  userAgentPackageName: 'com.moteros.moteros_app',
),
```

### 5.7 Settings screen addition

In `settings_screen.dart`, add to "APARIENCIA" section (new section):

```dart
// APARIENCIA Section
_sectionHeader('APARIENCIA'),
_sectionCard([
  _settingRow(
    icon: Icons.brightness_6_outlined,
    title: 'Tema claro',
    subtitle: 'Modo claro de alto contraste para luz solar',
    trailing: BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, state) => _amberToggle(
        state == ThemeMode.light,
        (v) => context.read<ThemeCubit>().toggle(),
      ),
    ),
  ),
]),
```

### 5.8 App-level integration

In `lib/app.dart`, wrap `MaterialApp`:

```dart
BlocProvider<ThemeCubit>(
  create: (_) => ThemeCubit(),
  child: BlocBuilder<ThemeCubit, ThemeMode>(
    builder: (context, themeMode) => MaterialApp(
      themeMode: themeMode,
      darkTheme: AppTheme.dark,
      theme: AppTheme.light,
      // ... rest
    ),
  ),
),
```

### 5.9 BLoC layer crossing

| From | To | Method |
|------|----|--------|
| MaterialApp (app.dart) | ThemeCubit | BlocProvider + BlocBuilder |
| SettingsScreen | ThemeCubit | BlocBuilder (read toggle state) |
| RodarScreen | ThemeCubit | BlocBuilder (read for tile URL) |
| ThemeCubit | SharedPreferences | Direct (no datasource needed) |

### 5.10 Testing strategy

| Layer | Test | Tool |
|-------|------|------|
| Cubit | Initial state = ThemeMode.dark | `flutter_test` |
| Cubit | toggle() switches dark↔light | `flutter_test` |
| Cubit | Persistence: restart emits saved mode | `flutter_test` + mock SharedPreferences |
| Widget | Theme toggle in Settings switches theme | `flutter_test` |
| Widget | Light theme uses light tile URL | `flutter_test` |
| Widget | Dark theme uses dark tile URL | `flutter_test` |
| Visual | Light theme legible in sunlight | Manual on-device test |

### 5.11 Rollback

- Change SharedPreferences key from `theme_mode` to `theme_mode_v2` (or delete key)
- Force `ThemeMode.dark` in `ThemeCubit` by hardcoding `emit(ThemeMode.dark)`
- Remove `AppTheme.light` getter
- Remove light palette from design_tokens
- Remove ThemeCubit BlocProvider from app.dart

---

## 6. Combined Widget Tree — RodarScreen (full)

```
RodarScreen
├── BlocProvider<ThemeCubit>            ← NEW (F-M5)
├── BlocProvider<SearchBloc>            ← NEW (F-M1)
├── Scaffold
│   └── Stack
│       ├── BlocBuilder<ThemeCubit>      ← NEW (F-M5 — tile URL)
│       │   └── FlutterMap
│       │       ├── TileLayer (dark_all OR light_all)
│       │       ├── MarkerLayer — motoposada POIs (existing)
│       │       │   └── per marker: icon = is_tourist ? star : home/garage  ← MODIFIED (F-M2)
│       │       ├── MarkerLayer — temporary search result (F-M1)
│       │       │   └── StreamBuilder<SearchBloc> → cyan marker
│       │       └── MarkerLayer — blue dot (F-M3)
│       │           └── StreamBuilder<Position> → BlueDotMarker
│       │
│       ├── Positioned(top) — KmOverlay (existing)
│       │
│       ├── Positioned(top, below Km)   ← NEW (F-M1)
│       │   └── PlaceSearchBar
│       │         └── BlocBuilder<SearchBloc> → SearchResultsList
│       │
│       ├── Positioned(bottom-right)    ← NEW (F-M3)
│       │   └── RecenterButton
│       │         └── onPressed: _mapController.move(currentPos)
│       │
│       ├── RodarFAB (existing)
│       └── DraggableScrollableSheet (existing)
```

---

## 7. Affected Files Summary

| # | File | Change | Feature | Notes |
|---|------|--------|---------|-------|
| 1 | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | MODIFIED | F-M1, F-M3, F-M5 | Search bar, blue dot, recenter, tile URL |
| 2 | `lib/features/dashboard/presentation/bloc/search_bloc.dart` | NEW | F-M1 | Search + debounce + cache |
| 3 | `lib/features/dashboard/presentation/bloc/search_event.dart` | NEW | F-M1 | SearchPlace, SelectPlace |
| 4 | `lib/features/dashboard/presentation/bloc/search_state.dart` | NEW | F-M1 | Initial, Loading, Loaded, Error |
| 5 | `lib/features/dashboard/data/datasources/nominatim_datasource.dart` | NEW | F-M1 | Dio → Nominatim API |
| 6 | `lib/features/dashboard/domain/entities/search_result_entity.dart` | NEW | F-M1 | Place name, lat, lng, type |
| 7 | `lib/features/dashboard/presentation/widgets/place_search_bar.dart` | NEW | F-M1 | TextField + debounce |
| 8 | `lib/features/dashboard/presentation/widgets/search_results_list.dart` | NEW | F-M1 | Scrollable result list |
| 9 | `lib/features/dashboard/presentation/widgets/blue_dot_marker.dart` | NEW | F-M3 | Blue dot + heading widget |
| 10 | `lib/features/dashboard/presentation/widgets/recenter_button.dart` | NEW | F-M3 | Floating recenter FAB |
| 11 | `lib/core/services/location_tracking_service.dart` | MODIFIED | F-M3 | Add passivePositionStream + headingStream |
| 12 | `lib/features/refugios/presentation/bloc/motoposadas_event.dart` | MODIFIED | F-M2 | Add CreateTouristPoi event |
| 13 | `lib/features/refugios/presentation/bloc/motoposadas_state.dart` | MODIFIED | F-M2 | Add TouristPoiCreated, TouristPoiForbidden |
| 14 | `lib/features/refugios/presentation/bloc/motoposadas_bloc.dart` | MODIFIED | F-M2 | _onCreateTouristPoi handler |
| 15 | `lib/features/refugios/data/models/motoposada_model.dart` | MODIFIED | F-M2 | Add poi_type, is_tourist, city fields |
| 16 | `lib/features/refugios/presentation/screens/create_motoposada_screen.dart` | MODIFIED | F-M2 | Tourist toggle + city field |
| 17 | `lib/features/refugios/presentation/widgets/tourist_poi_marker.dart` | NEW | F-M2 | Star marker widget |
| 18 | `android/app/src/main/AndroidManifest.xml` | MODIFIED | F-M4 | 2 `<package>` entries |
| 19 | `ios/Runner/Info.plist` | MODIFIED | F-M4 | LSApplicationQueriesSchemes |
| 20 | `lib/core/services/navigation_handler.dart` | MODIFIED | F-M4 | debugPrint logging |
| 21 | `lib/core/theme/theme_cubit.dart` | NEW | F-M5 | ThemeCubit + SharedPreferences |
| 22 | `lib/core/theme/design_tokens.dart` | MODIFIED | F-M5 | Light palette tokens |
| 23 | `lib/core/theme/app_theme.dart` | MODIFIED | F-M5 | AppTheme.light getter |
| 24 | `lib/features/settings/presentation/screens/settings_screen.dart` | MODIFIED | F-M5 | Appearance section + toggle |
| 25 | `lib/app.dart` | MODIFIED | F-M5 | ThemeCubit provider + themeMode |

**Totals:** 13 NEW files, 12 MODIFIED files, 0 DELETED files.

---

## 8. Supabase Migrations

Two additive migrations required (order matters):

```sql
-- Migration M01: profiles curator fields (F-M2)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_city_curator BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS curator_city TEXT;

-- Migration M02: motoposadas tourist fields + RLS (F-M2)
ALTER TABLE motoposadas
  ADD COLUMN IF NOT EXISTS poi_type TEXT DEFAULT 'standard',
  ADD COLUMN IF NOT EXISTS is_tourist BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS city TEXT;

CREATE POLICY "curator_create_tourist" ON motoposadas
  FOR INSERT WITH CHECK (
    (poi_type IS DISTINCT FROM 'tourist') OR
    (poi_type = 'tourist' AND EXISTS (
      SELECT 1 FROM profiles
      WHERE user_id = auth.uid()
        AND is_city_curator = true
        AND curator_city = city
    ))
  );
```

---

## 9. Implementation Order

| Phase | Features | Rationale |
|-------|----------|-----------|
| 1 | F-M5 (theme) | Foundation — affects every screen's visual testing |
| 2 | F-M4 (navigation detection) | Config-only, no code dependencies, quick win |
| 3 | F-M3 (blue dot) | Reuses tracker, independent of search/POI |
| 4 | F-M1 (search) | Touches RodarScreen heavily, build after dot is stable |
| 5 | F-M2 (tourist POI) | Most complex — schema + RLS + BLoC + UI. Last so search+dot are already rendering correctly with POI markers |
