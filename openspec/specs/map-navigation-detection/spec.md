# Delta for map-navigation-detection

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| MND-R1 | AndroidManifest.xml MUST include `<queries>` entries for `com.waze` and `com.google.android.apps.maps`. | MUST |
| MND-R2 | iOS Info.plist MUST include `LSApplicationQueriesSchemes` for `waze` and `comgooglemaps`. | MUST |
| MND-R3 | Before and after `canLaunchUrl` results SHALL be logged for verification that the fix resolves detection failures. | SHALL |

```
Given: App is installed on Android 11+
When: canLaunchUrl checks Waze or Google Maps URI
Then: Returns true — app detected

Given: App is installed on iOS
When: canLaunchUrl checks waze:// or comgooglemaps://
Then: Returns true — app detected
```
