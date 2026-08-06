# Delta for contacto-whatsapp

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-WA-1 | "Contactar" SHALL open `https://wa.me/<phone>?text=<preloaded availability message>`. The phone SHALL be fetched ON DEMAND via RPC at tap time and SHALL NOT appear in list/card payloads. | MUST |
| M-WA-2 | When WhatsApp is not installed (canLaunchUrl fails), the app SHALL fall back to WhatsApp Web or show a clear message that WhatsApp is required — no silent failure. | MUST |
| M-WA-3 | The app MUST NOT transmit the exact address in any outbound message or link. Whether the host shares it inside the WhatsApp conversation SHALL be the host's own decision, made outside the app. | MUST NOT |

```
Given: user taps Contactar on a casa_motero card
When: the on-demand phone RPC returns the host's phone
Then: the app launches https://wa.me/<phone>?text=<availability message>

Given: a list or card payload is inspected
When: a casa_motero is rendered
Then: no whatsapp_phone key is present
```

```
Given: WhatsApp is not installed (canLaunchUrl returns false)
When: user taps Contactar
Then: the app shows the WhatsApp Web fallback or a clear "WhatsApp required" message
```

```
Given: user taps Contactar
When: the wa.me URL is built
Then: it contains phone + message only — no coordinates or address

Given: the app builds any outbound availability message
When: its content is inspected
Then: the exact address is never included
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Unit tests: wa.me URL builder — phone + preloaded message only, never coordinates/address (M-WA-1, M-WA-3).
- Widget tests: Contactar triggers the on-demand RPC fetch then launch (M-WA-1); canLaunchUrl=false shows the fallback (M-WA-2); list/card models expose no phone key (M-WA-1).
- RLS-aware datasource tests (noSuchMethod pattern): contact RPC returns no phone for inactive or non-casa_motero ids.
