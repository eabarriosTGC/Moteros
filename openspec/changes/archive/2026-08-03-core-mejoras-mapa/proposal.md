# Proposal: Core Map & UX Improvements

## Intent

Enhance Rodar map with place search, tourist POIs, blue dot location, fix platform navigation detection, and add sunlight-legible light theme.

## Scope

### In Scope
- **F-M1**: Place search bar on Rodar map — Nominatim geocoding (1 req/sec, custom User-Agent), debounced results, tap-to-center
- **F-M2**: Tourist POIs ("visita obligada") — curator-only creation, reuse motoposada table/infra, auto-approved
- **F-M3**: Blue dot + heading + floating recenter button on Rodar map
- **F-M4**: Fix Waze/Maps detection via Android `<queries>` + iOS `LSApplicationQueriesSchemes`
- **F-M5**: Light theme (high-contrast M3) with day OSM tiles, manual toggle in Settings

### Out of Scope
- Auto-switch theme by time of day (deferred); public tourist POI creation; route planning; custom tile hosting

## Capabilities

### New Capabilities
- `map-search`: Nominatim geocoding overlay on Rodar map with debounced results and temporary marker.
- `tourist-poi`: Tourist POI subtype within existing motoposada system. Curator-only creation via `profiles.is_city_curator` + `curator_city`. Auto-approved.
- `map-location`: Current-location blue dot with heading indicator + recenter FAB.
- `map-navigation-detection`: Platform config fix for Waze/Google Maps app detection.
- `theme`: Light theme (high-contrast M3) with day-mode OSM tiles, manual toggle.

## Approach

| Feature | Key Decision |
|---------|--------------|
| F-M1 | Dio GET to Nominatim; debounce 300ms; cache 5min TTL |
| F-M2 | Extend motoposada model (`poi_type`, `is_tourist`, `city`); curator check via profile; reuse form pattern |
| F-M3 | `flutter_map` MarkerLayer + `geolocator` heading; reuse tracker "always" permission |
| F-M4 | `<queries>` for `com.waze`, `com.google.android.apps.maps`; iOS `LSApplicationQueriesSchemes` for `waze`, `comgooglemaps` |
| F-M5 | `AppTheme.light` + `ThemeCubit` (BLoC); day tiles via OSM standard layer |

**F-M2 curator requirement:** `profiles` table MUST include `is_city_curator BOOLEAN DEFAULT false` + `curator_city TEXT`. Non-curators SHALL receive 403. Explicit product requirement — not open to all nor hardcoded.

## Affected Areas

| Area | Impact |
|------|--------|
| `rodar_screen.dart` | Search bar, blue dot, recenter button |
| `lib/features/refugios/` | Tourist POI model + form |
| `settings_screen.dart` | Theme toggle |
| `app_theme.dart` | Light ThemeData |
| `AndroidManifest.xml` | `<queries>` entries |
| `ios/Runner/Info.plist` | `LSApplicationQueriesSchemes` |

## Risks

| Risk | Mitigation |
|------|------------|
| Nominatim 429 rate blocks | 1 req/sec throttle, 5min cache |
| Curator columns missing in profiles | Additive nullable migration |
| Light contrast in sunlight | M3 high-contrast tokens + on-device test |
| `canLaunchUrl` still false after fix | Verbose before/after logging |

## Rollback Plan

Theme: revert pref key. POI schema: drop additive columns. `<queries>`: delete block. Search: feature-flag disable via SharedPreferences.

## Dependencies

- Supabase migration: `profiles.is_city_curator` + `curator_city` (F-M2)
- Supabase migration: motoposada columns `poi_type`, `is_tourist`, `city` (F-M2)

## Success Criteria

- [ ] Search bar → Nominatim results → tap centers map with marker
- [ ] Curator creates tourist POI → distinct marker; non-curator gets 403
- [ ] Blue dot tracks location with heading on Rodar map
- [ ] `canLaunchUrl` returns `true` for Waze/Maps on Android 11+ and iOS
- [ ] Theme toggle switches dark/light; light mode is sunlight-legible
