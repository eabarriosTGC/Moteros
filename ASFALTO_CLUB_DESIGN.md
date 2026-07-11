# AsfaltoClub: Battle Ride — Design System

> **Sistema de diseño para comunidad motera social multiplayer.**  
> *Versión: 1.0.0 — Julio 2026*

---

## Table of Contents

1. [Philosophy](#1-philosophy)
2. [Color Palette](#2-color-palette)
3. [Typography](#3-typography)
4. [Spacing & Sizing](#4-spacing--sizing)
5. [Border Radius](#5-border-radius)
6. [Shadows & Glows](#6-shadows--glows)
7. [Surface Archetypes](#7-surface-archetypes)
8. [Component Tokens](#8-component-tokens)
9. [Iconography](#9-iconography)
10. [Motion & Transitions](#10-motion--transitions)
11. [Anti-Slop Checklist](#11-anti-slop-checklist)

---

## 1. Philosophy

### Core Principles

| Principle | Application |
|---|---|
| **Surface-First Design** | Each screen belongs to an archetype (Monitor / Operate / Decide). Layout is dictated by the information hierarchy of that archetype, not decorative patterns. |
| **Gestalt Psychology** | Proximity groups live data (speed, distance, heading) into single modules. Figure/Ground makes the map the eternal background. Closure drives minimalist iconography. |
| **Vial Semiotics** | Amber = precaution (fog lights), Green = safe (checkpoint passed), Red = danger (SOS/rally mode). The biker reads these without thought. |
| **Night-First** | Dark theme is not optional — this is used at night on the road. Every contrast ratio meets WCAG AA at minimum. |
| **Glove-Friendly** | Minimum touch target 48px. Buttons full-width on Operate surfaces. No hover-dependent interactions. |

### Surface Archetypes

```
MONITOR  → Mapa en vivo. Densa, jerárquica, sin decoración. El mapa es el fondo.
OPERATE  → Crear raids, lobby, perfil. Acciones, formularios, botones grandes.
DECIDE   → Explorar raids, leaderboard. Una idea por sección, cards escaneables.
```

---

## 2. Color Palette

### Token Table

| Token | Hex | Role | Psychology |
|---|---|---|---|
| **Backgrounds** | | | |
| `background` | `#0A0A0F` | Fondo principal | Asfalto mojado de noche. Negro profundo con matiz azul mínimo. No es negro puro (muy frío), no es gris gaming. |
| `surface` | `#1A1A24` | Superficies elevadas (cards, sheets) | Un escalón sobre el asfalto. Gris-pizarra con matiz azul. |
| `surfaceElevated` | `#121218` | Superficies flotantes (modals, drawers) | Más oscuro que surface para jerarquía de profundidad. |
| `surfaceOverlay` | `#0D0D14` | Overlay del mapa con blur | Lo más oscuro antes del fondo. Translúcido con backdrop blur. |
| `surfaceMonitor` | `#08080C` | Fondo del mapa en vivo | Absolutamente negro con el mínimo azul para OLED. |
| `input` | `#1E1E2A` | Campos de formulario | Ligeramente más claro que surface para indicar interactividad. |
| **Borders** | | | |
| `border` | `#2A2A35` | Bordes estándar | Sutil, no compite con contenido. |
| `borderLight` | `#363645` | Bordes hover/focused | Apenas perceptible, suficiente para feedback. |
| `borderActive` | `#FF8C00` | Borde de elemento activo | Ámbar — indica selección o foco. |
| **Text** | | | |
| `textPrimary` | `#F5F5F7` | Texto principal | Blanco cálido, no puro. Fácil en ojos nocturnos. |
| `textSecondary` | `#A0A0B0` | Texto secundario | Gris azulado para labels, metadata. |
| `textMuted` | `#606070` | Texto deshabilitado / placeholder | Contraste suficiente para ser legible pero secundario. |
| `textDisabled` | `#404050` | Texto desactivado | Claramente inactivo. |
| `textOnAmber` | `#0A0A0F` | Texto sobre fondo ámbar | Negro para máximo contraste sobre ámbar. |
| **Accent — Primary (Amber)** | | | |
| `primary` | `#FF8C00` | Accento principal | Luces de niebla, fogata de ruta, energía contenida. **No es naranja, no es amarillo — es ámbar.** |
| `primaryHover` | `#E67E00` | Hover de acento | 10% más oscuro para feedback táctil. |
| `primaryActive` | `#CC7000` | Active/pressed | 15% más oscuro. |
| `primaryGlow` | `#33FF8C00` | Glow de botón primario | 20% alpha — sombra neón sutil. |
| **Accent — Secondary (Electric Cyan)** | | | |
| `secondary` | `#00D4FF` | GPS, tecnología, velocidad | El azul del tablero de una moto moderna de noche. Balancea el ámbar cálido. |
| `secondaryHover` | `#00BEE6` | Hover | Saturación controlada. |
| `secondaryGlow` | `#3300D4FF` | Glow secundario | 20% alpha. |
| **Semantic** | | | |
| `success` | `#39FF14` | Checkpoint, XP, validado | Neon Green — checkpoints aprobados. |
| `successDark` | `#2ECC40` | Success muted | Para badges secundarios. |
| `error` | `#FF2D55` | SOS, rally mode, peligro | Signal Red — no es rojo sangre, es rojo de alerta vial. |
| `errorDark` | `#CC2440` | Error muted | Para indicadores menos urgentes. |
| `warning` | `#FFD600` | Warning / caution | Amarillo de alerta — uso escaso para mantener impacto. |
| `info` | `#00D4FF` | Info (mismo que secondary) | Un solo token para info/tech. |
| **Track & Progress** | | | |
| `trackInactive` | `#2A2A35` | Fondo de track (sliders, progress) | Mismo que border. |
| `trackActive` | `#FF8C00` | Track activo | Ámbar. |
| `trackSuccess` | `#39FF14` | Track completado | Verde neón. |

### Color Relationships

```
background (#0A0A0F)
  └─ surface (#1A1A24) — 1 step up
      └─ surfaceElevated (#121218) — floating above
          └─ border (#2A2A35) — on top of surface

primary (#FF8C00) — hero color
  └─ secondary (#00D4FF) — cool balance
      └─ success (#39FF14) — positive reinforcement
          └─ error (#FF2D55) — alert/caution

textPrimary (#F5F5F7) — on backgrounds
  └─ textSecondary (#A0A0B0) — on cards/surfaces
      └─ textMuted (#606070) — on elevated surfaces
```

### Amber as Hero Color

**#FF8C00** is deliberately uncommon in tech UIs. Psychology:
- **Warmth**: Amber recalls campfires, dusk rides, human connection.
- **Caution**: Fog lights and warning signs — attention without panic.
- **Controlled energy**: Unlike red (aggressive) or green (passive), amber is *poised*. The rider is ready.
- **Identity**: No other major app uses amber as primary. AsfaltoClub owns it.

---

## 3. Typography

### Font Stack

| Role | Font | Weight | Rationale |
|---|---|---|---|
| **Headings / Display** | **Space Grotesk** | 500–700 | Geométrica, técnica, unique. Alternativa a Inter/SF Pro. Legible en movimiento. |
| **Body / UI** | **DM Sans** | 400–600 | Cálida, humanista, excelente legibilidad en dark mode. |
| **Numbers / Stats** | **Space Grotesk** (tabular) | 600–700 | Monoespaciado proporcional para velocímetro, distancias. |

### Type Scale

| Token | Size | Weight | Line Height | Letter Spacing | Font |
|---|---|---|---|---|---|
| `displayLarge` (hero) | 40px | 700 | 1.1 | -1.0% | Space Grotesk |
| `displayMedium` | 32px | 700 | 1.15 | -0.75% | Space Grotesk |
| `displaySmall` | 28px | 600 | 1.2 | -0.5% | Space Grotesk |
| `headlineLarge` (h1) | 24px | 600 | 1.25 | -0.25% | Space Grotesk |
| `headlineMedium` (h2) | 20px | 600 | 1.3 | 0% | Space Grotesk |
| `headlineSmall` (h3) | 18px | 600 | 1.3 | 0% | Space Grotesk |
| `titleLarge` | 16px | 600 | 1.4 | 0% | DM Sans |
| `titleMedium` | 14px | 600 | 1.4 | 0% | DM Sans |
| `bodyLarge` | 16px | 400 | 1.5 | 0% | DM Sans |
| `bodyMedium` | 14px | 400 | 1.5 | 0% | DM Sans |
| `bodySmall` | 12px | 400 | 1.4 | 0% | DM Sans |
| `labelLarge` (button) | 15px | 600 | 1.25 | 0.3% | DM Sans |
| `labelMedium` | 12px | 500 | 1.3 | 0.5% | DM Sans |
| `labelSmall` | 10px | 500 | 1.3 | 0.8% | DM Sans |
| `monoLarge` | 48px | 700 | 1.0 | -2.0% | Space Grotesk |
| `monoMedium` | 28px | 600 | 1.1 | -1.0% | Space Grotesk |
| `monoSmall` | 18px | 600 | 1.2 | 0% | Space Grotesk |

### Why Not Inter / SF Pro?

- **Inter** is the default "tech startup" font. It communicates *generic SaaS*.
- **SF Pro** is Apple-only. It communicates *iOS default*.
- **Space Grotesk** is distinctive, technical, and slightly aggressive — fits motorcycling.
- **DM Sans** is warm and approachable — balances Space Grotesk's rigidity.

---

## 4. Spacing & Sizing

### Base — 4px Grid

| Token | Value | Usage |
|---|---|---|
| `2xs` | 2px | Micro-padding, divider gaps |
| `xs` | 4px | **Base unit**. Small gaps, icon margins |
| `sm` | 8px | Inner card padding (compact), between related elements |
| `md` | 16px | Card padding, section gaps, screen padding |
| `lg` | 24px | Between sections, modal padding |
| `xl` | 32px | Big sections, bottom sheet padding |
| `xxl` | 48px | Hero spacing, full-screen sections |
| `xxxl` | 64px | Page-top padding, feature separation |

### Touch Targets (Glove-Friendly)

| Token | Value |
|---|---|
| `minTouchTarget` | 48px |
| `buttonHeight` | 52px |
| `buttonHeightSm` | 40px |
| `bottomNavHeight` | 72px |
| `fabSize` | 60px |

### Icon Sizing

| Token | Value |
|---|---|
| `iconXs` | 16px |
| `iconSm` | 20px |
| `iconMd` | 24px |
| `iconLg` | 32px |
| `iconXl` | 48px |

---

## 5. Border Radius

| Token | Value | Usage |
|---|---|---|
| `none` | 0 | Dividers, separators, tabs |
| `xs` | 4px | Small chips, badges inline |
| `sm` | 8px | Input fields, small cards |
| `md` | **12px** | **Default** — cards, buttons, containers |
| `lg` | 16px | Modals, dialogs, bottom sheets |
| `xl` | 24px | Large modals, feature cards |
| `full` | 999px | Pills, avatars, floating badges |

### Radius Philosophy

- **6px** feels unfinished. **8px** is Apple's default. **12px** is AsfaltoClub's signature — substantial but not pill-like.
- Cards use 12px. This feels like a physical object (a dashboard module).
- Modals use 20px — large enough to feel like a distinct surface.
- Pills are 999px for avatars and floating badges.

---

## 6. Shadows & Glows

| Token | Blur | Spread | Offset | Color | Usage |
|---|---|---|---|---|---|
| `card` | 8px | 0 | (0, 2) | #0A0A0F @ 10% | Default card elevation |
| `elevated` | 16px | 0 | (0, 4) | #000000 @ 15% | Modals, drawers |
| `primaryGlow` | 12px + 24px | 1 + 2 | (0, 0) | #FF8C00 @ 20% | Amber button glow |
| `secondaryGlow` | 12px | 1 | (0, 0) | #00D4FF @ 20% | Cyan accent glow |
| `successGlow` | 12px | 1 | (0, 0) | #39FF14 @ 20% | Checkpoint glow |
| `mapOverlay` | 20px + backdrop blur | 0 | (0, 0) | #0A0A0F @ 60% | Map overlays |

---

## 7. Surface Archetypes

### Monitor — Live Map Screen

```
characteristics:
  - Map is 100% background (Figure/Ground)
  - All overlays have backdrop-filter: blur + semi-transparency
  - No decorative elements
  - Dense information hierarchy
  - Speedometer-style stats clustering

layout structure:
  ┌──────────────────────────────────────┐
  │ [top bar]  ping  speed  heading      │ ← compact, glassmorphism
  │                                      │
  │          MAP (FULL SCREEN)           │ ← figure
  │     ┌──────────┐      ┌─────────┐   │
  │     │ rider pos │      │  radar  │   │ ← floating glass cards
  │     └──────────┘      └─────────┘   │
  │                                      │
  │  ┌──────────────────────────────┐   │
  │  │ [stats cluster] KM | TIME | XP│   │ ← Gestalt proximity
  │  └──────────────────────────────┘   │
  │  ┌──┐ ┌──┐ ┌──┐ ┌──┐              │
  │  │SOS│ │PIN│ │C📷│ │⚙ │              │ ← bottom action bar
  │  └──┘ └──┘ └──┘ └──┘              │
  └──────────────────────────────────────┘
```

### Operate — Forms / Actions / Profile

```
characteristics:
  - Full-width buttons (glove-friendly)
  - Large, tappable cards
  - Form fields with clear labels
  - No hover states (touch-only)
  - Bottom sheet for secondary actions

key constraints:
  - minTouchTarget = 48px everywhere
  - Buttons span full container width
  - Input fields have large padding (16px)
  - No drag-to-dismiss (gloves)
```

### Decide — Raid Explorer / Leaderboard

```
characteristics:
  - One idea per section
  - Cards are scannable in <2 seconds
  - High information density
  - Scrollable feed with clear visual hierarchy
  - Status badges are prominent (color-coded)
```

---

## 8. Component Tokens

### Raid Card (`raid_card`)

```
┌──────────────────────────────────────┐
│ [STATUS BADGE]  [MODE]              │ ← amber/green/red pill
│                                      │
│  Ruta: Bogotá → La Calera           │ ← headlineSmall, textPrimary
│  42 km · 1h 30min · 8 riders        │ ← bodySmall, textSecondary
│                                      │
│  ⭐ 4.8  🏁 12:30 PM  🗓️ Sábado     │ ← labelSmall, textMuted
│                                      │
│  [🟢 JOIN] or [🔴 IN PROGRESS]      │ ← action_button
└──────────────────────────────────────┘
```

| Token | Value |
|---|---|
| `backgroundColor` | `surface` (#1A1A24) |
| `borderColor` | `border` (#2A2A35) |
| `borderRadius` | `md` (12px) |
| `padding` | `md` (16px) |
| `gap` | `sm` (8px) |
| `titleText` | `headlineSmall` → `textPrimary` |
| `subtitleText` | `bodySmall` → `textSecondary` |
| `metadataText` | `labelSmall` → `textMuted` |
| `statusBadgeRadius` | `full` (999px) |
| `statusBadgePadding` | `xs` (4px) horizontal, `2xs` (2px) vertical |
| `elevation` | `card` shadow |

### Participant Avatar (`participant_avatar`)

```
┌───┐
│ 🏍 │  ← 32px circular with amber border if captain
└───┘
  name  ← bodySmall, textSecondary
```

| Token | Value |
|---|---|
| `size` | 32px (compact), 40px (default), 48px (large) |
| `borderRadius` | `full` (999px) |
| `borderColor` (default) | `border` (#2A2A35) |
| `borderColor` (captain) | `primary` (#FF8C00) |
| `borderWidth` (captain) | 2px |
| `overlapOffset` | -8px (stacked avatars) |
| `labelText` | `bodySmall` → `textSecondary` |

### Checkpoint Badge (`checkpoint_badge`)

```
┌──────┐
│  🟢  │  ← success glow
│  CP  │  ← monoSmall, textOnAmber or white
│  3   │
└──────┘
```

| Token | Value |
|---|---|
| `size` | 28px × 28px (compact), 36px (default) |
| `backgroundColor` (unreached) | `border` (#2A2A35) |
| `backgroundColor` (reached) | `success` (#39FF14) |
| `backgroundColor` (current) | `primary` (#FF8C00) |
| `borderRadius` | `sm` (8px) |
| `numberText` | `monoSmall` → white on colored bg |
| `glow` | `successGlow` when reached |

### Live Stat (`live_stat`)

```
  84          ← monoLarge, textPrimary
  km/h        ← labelSmall, textSecondary  (or amber if racing)
```

| Token | Value |
|---|---|
| `valueText` | `monoLarge` (48px) or `monoMedium` (28px) → `textPrimary` |
| `unitText` | `labelSmall` (10px) → `textSecondary` |
| `labelText` | `bodySmall` (12px) → `textMuted` |
| `accentColor` | `primary` (#FF8C00) when in race/active mode |
| `spacing` | `2xs` (2px) between value and unit |
| `alignment` | Centered column |

### Action Button (`action_button`)

```
┌──────────────────────────────────────┐
│        UNIRSE AL RAID 🏍️             │
└──────────────────────────────────────┘
  ↑ full-width, 52px height
```

| Token | Value |
|---|---|
| `height` | 52px |
| `minWidth` | 48px |
| `horizontalPadding` | 24px |
| `backgroundColor` (primary) | `primary` (#FF8C00) |
| `textColor` (primary) | `textOnAmber` (#0A0A0F) |
| `backgroundColor` (secondary) | transparent, border `primary` |
| `backgroundColor` (danger) | `error` (#FF2D55) |
| `textColor` (danger) | white |
| `borderRadius` | `md` (12px) |
| `textStyle` | `labelLarge` (15px, 600, 0.3% letter-spacing) |
| `elevation` | `primaryGlow` for primary variant |
| `disabledBackground` | `border` (#2A2A35) |
| `disabledText` | `textDisabled` (#404050) |

### Clan Tag (`clan_tag`)

```
┌─────────────────┐
│ 🏴‍☠️ LOS_ASFALTOS  │
└─────────────────┘
```

| Token | Value |
|---|---|
| `backgroundColor` | `surfaceElevated` (#121218) |
| `borderColor` | `border` (#2A2A35) |
| `borderRadius` | `full` (999px) |
| `padding` | `sm` (8px) horizontal, `2xs` (2px) vertical |
| `textStyle` | `labelMedium` (12px, 500) → `textSecondary` |
| `iconSize` | `iconSm` (20px) |

### Progress Bar (`progress_bar`)

```
┌──────────────────────────────────────┐
│  ████████████░░░░░░░░░░░░  320/840km │
│  ←────── trackActive ─────→          │
│  trackInactive (border)  │
└──────────────────────────────────────┘
```

| Token | Value |
|---|---|
| `height` | 6px |
| `borderRadius` | `full` (999px) |
| `trackColor` | `trackInactive` (#2A2A35) |
| `progressColor` | `trackActive` (#FF8C00) |
| `progressColor` (complete) | `trackSuccess` (#39FF14) |
| `labelText` | `labelSmall` (10px) → `textMuted` |
| `indicatorStyle` | `monoSmall` → `textSecondary` |

### Map Overlay Card (`map_overlay_card`)

```
┌──────────────────────────────┐
│ Glassmorphism container      │ ← backdrop-filter: blur(20px)
│                              │    background: #0A0A0F @ 60%
│  Stats / Info here           │    border: 0.5px #FFFFFF @ 10%
└──────────────────────────────┘
```

| Token | Value |
|---|---|
| `backgroundColor` | `surfaceOverlay` @ 85% opacity |
| `backdropFilter` | blur(20px) |
| `borderColor` | white @ 8% |
| `borderWidth` | 0.5px |
| `borderRadius` | `md` (12px) |
| `padding` | `sm` (8px) internal |
| `elevation` | `mapOverlay` shadow |

---

## 9. Iconography

### Style Guidelines

- **Minimalist / Outline** — Gestalt Closure. The eye completes the shape.
- **Stroke width**: 1.5px–2px (visible on mobile)
- **No filled icons** except for active states (nav bar selected)
- **Color**: `textSecondary` (#A0A0B0) default, `primary` (#FF8C00) for active
- **Linecap**: Round

### Icon Set Recommendations

| Concept | Icon (Material) |
|---|---|
| Raid / Route | `directions_bike` |
| Map / GPS | `map` |
| Speed | `speed` |
| Checkpoint | `flag` or `location_on` |
| Clan | `group` |
| SOS | `warning_amber` |
| Trophy / XP | `emoji_events` |
| Rider / Profile | `person` |
| Chat | `chat` |
| Settings | `settings` |
| Ready (lobby) | `check_circle` |
| Navigate | `navigation` (arrow) |
| Share location | `share_location` |

---

## 10. Motion & Transitions

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `fast` | 150ms | easeOut | Micro-interactions, button press |
| `normal` | 250ms | easeInOut | Page transitions, modal open |
| `slow` | 400ms | easeOut | Hero animations, map transitions |
| `curveStandard` | cubic-bezier(0.2, 0.0, 0.0, 1.0) | Standard accelerate/decelerate |
| `curveEmphasized` | cubic-bezier(0.2, 0.0, 0.0, 1.0) | Screen transitions |

---

## 11. Anti-Slop Checklist

Before shipping, verify:

- [x] **Primary accent is AMBER** (#FF8C00) — not indigo, not purple, not blue.
- [x] **No blue-violet gradients**. Gradients are amber→amber-dark or cyan→cyan-dark only.
- [x] **No feature-tile grids**. This is Monitor/Operate architecture, not a marketing page.
- [x] **Glassmorphism is functional-only** — map overlays with blur, NOT decorative glass cards.
- [x] **Not Inter/SF Pro**. Using Space Grotesk + DM Sans.
- [x] **Surface archetypes respected**. Every screen maps to Monitor, Operate, or Decide.
- [x] **Colors follow vial logic**. Amber = precaution, Green = safe, Red = danger.
- [x] **Touch targets ≥ 48px**. Glove-friendly everywhere.
- [x] **Dark theme is not optional**. Night-first design on the road.
- [x] **Gestalt applied**. Proximity groups data, Figure/Ground makes map the background, Closure drives icons.

---

## Appendix: Flutter Token Mapping

| DESIGN.md Token | Flutter Token |
|---|---|
| `background` | `AppColors.background` |
| `surface` | `AppColors.surface` |
| `surfaceElevated` | `AppColors.elevated` |
| `border` | `AppColors.border` |
| `textPrimary` | `AppColors.textPrimary` |
| `primary` (#FF8C00) | `AppColors.primary` |
| `secondary` (#00D4FF) | `AppColors.secondary` |
| `success` (#39FF14) | `AppColors.success` |
| `error` (#FF2D55) | `AppColors.error` |
| `displayLarge` | `AppTypography.displayLarge` |
| `bodyMedium` | `AppTypography.body` |
| `labelLarge` | `AppTypography.button` |

---

*Built with intention. Every pixel has a reason.*  
— AsfaltoClub Design Team
