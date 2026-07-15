# SDD — Battle Pass + Economía In-Game

> **Proyecto:** Moteros / AsfaltoClub
> **Documento:** Propuesta de Cambio — Battle Pass + Sistema Económico (2 features en una entrega cohesiva)
> **Autor:** Hermes Agent / Nous Research
> **Fecha:** Julio 2026
> **Estado:** ✅ Propuesta (Pendiente de aprobación)
> **Base:** `SDD_COMUNIDAD_Y_RUTAS.md`, `ASFALTO_CLUB_DESIGN.md`, migrations 003–010

---

## 1. TÍTULO Y OBJETIVO

**Battle Pass + Economía In-Game — Monedas, tienda cosmética, pase de temporada y misiones semanales/diarias**

### Objetivo

Combinar 2 features en un único cambio que transforma AsfaltoClub de una app de raids con XP a un **ecosistema con economía virtual completa**: monedas (coins) como moneda dura, tienda de cosméticos, Battle Pass por temporada con misiones diarias/semanales, y un pipeline de recompensas que conecta raids → XP → coins → tienda. Aprovecha el schema SQL existente (migration 004 ya creó las tablas `shop_items`, `user_purchases`, `battle_passes`, `battle_pass_progress`, `battle_pass_missions`, `user_missions_progress` + columna `coins` en `user_xp`) y el seed de 12 items iniciales. El trabajo es principalmente **Flutter (BLoCs, screens, widgets) y Edge Functions (compra, progresión de temporada, finalización de misión)**.

---

## 2. ESTADO ACTUAL DEL codebase (Baseline)

### ✅ LO QUE YA EXISTE EN SUPABASE (migration 004 + 003 + 006)

| Tabla / Columna | Schema | Estado |
|----------------|--------|--------|
| `user_xp.coins` | `INT DEFAULT 0 CHECK (coins >= 0)` | ✅ Columna creada, sin lógica de earning/spending |
| `shop_items` | id UUID PK, name, description, type (cosmetic/consumable), subtype, icon_url, coins_cost, battle_pass_only, is_active | ✅ Tabla creada + seed de 12 items (migration 006) |
| `user_purchases` | id UUID PK, user_id FK, item_id FK, is_active, purchased_at | ✅ Tabla creada, sin RLS de INSERT |
| `battle_passes` | id UUID PK, season_name, season_number, start_date, end_date, cosmetic_rewards JSONB, is_active | ✅ Tabla creada |
| `battle_pass_progress` | id UUID PK, user_id FK, battle_pass_id FK, current_tier, xp_in_season, has_premium, claimed_rewards JSONB[] | ✅ Tabla creada, UNIQUE(user_id, battle_pass_id) |
| `battle_pass_missions` | id UUID PK, battle_pass_id FK, title, description, requirement JSONB, xp_reward, tier_unlock, is_daily | ✅ Tabla creada |
| `user_missions_progress` | id UUID PK, user_id FK, mission_id FK, progress, target, is_completed, completed_at | ✅ Tabla creada, UNIQUE(user_id, mission_id) |
| RLS policies | shop_select_public, up_select_own, bp_select_public, bpp_select_own, bpm_select_public, ump_select_own | ✅ Policies existentes (migration 007) |

### ❌ LO QUE NO EXISTE (brecha)

| Componente | Estado |
|-----------|--------|
| Edge Function para procesar compras (descontar coins, insertar purchase) | ❌ No existe |
| Edge Function para finalizar misión de Battle Pass | ❌ No existe |
| Edge Function para progresar tier de Battle Pass | ❌ No existe |
| Edge Function para otorgar coins por hitos (XP level up, raid completion, etc.) | ❌ No existe — `award_xp` existe pero no otorga coins |
| Flutter BLoC para tienda (ShopBloc) | ❌ No existe |
| Flutter BLoC para Battle Pass (BattlePassBloc) | ❌ No existe |
| Flutter screens: tienda, battle pass, inventario | ❌ No existe |
| Flutter widget para mostrar coins en header | ❌ No existe |
| Trigger SQL para otorgar coins al subir de nivel | ❌ No existe |
| Notificación de nuevas temporadas / misiones diarias | ❌ No existe |

### 📦 PROGRESIÓN RPG EXISTENTE (lib/features/progression/)

| Componente | Descripción | Estado |
|-----------|-------------|--------|
| `xp_progress_card.dart` | Widget que muestra nivel, barra XP, racha, raids, checkpoints, km, coins | ✅ Usa fetchXpData() directo de Supabase |
| `achievements_screen.dart` | 17 logros con categorías, grid 2-col, unlocked/locked | ✅ Screen funcional |
| `leaderboard_screen.dart` | Ranking con tabs Nacional/Club/Departamento, periodos mensual/anual/histórico | ✅ Screen funcional |
| `premio_anual_screen.dart` | 5 categorías de premio anual con top 3 | ✅ Screen funcional |
| `leaderboard_bloc.dart` | BLoC que consulta leaderboard_entries + premio_anual_candidates | ✅ BLoC funcional |

### 🧩 SERVICIOS EXISTENTES (lib/core/services/)

| Servicio | Propósito |
|---------|-----------|
| `anti_cheat_service.dart` | Detección GPS mock, validación de checkpoint via EF, logs anti-cheat |
| `sos_service.dart` | Envío de SOS manual, emergencia, suscripción a eventos SOS del clan |

### 🧩 FEATURES EXISTENTES

| Feature | BLoC/Screens | Estado |
|---------|-------------|--------|
| `mileage/` | MileageBloc + 3 screens (dashboard, manual entry, admin verification) | ✅ Completo |
| `clubs/` | ClubBloc + screens de club, miembros, retos | ✅ Completo |
| `routes/` | RouteBloc + screens de rutas | ✅ Completo |
| `raids/` | RaidBloc + lobby, live, list, create | ✅ Completo |
| `membership/` | MembershipBloc + screen (suscripciones basic/premium) | ✅ Completo |

### ⚡ EDGE FUNCTIONS EXISTENTES

| Function | Propósito |
|---------|-----------|
| `finish-raid` | Finaliza raid: calcula XP por modo, streaks, bonuses, anti-cheat flags. Distribuye XP via `award_xp` RPC |
| `validate-checkpoint` | Anti-cheat Layer 2+3: distancia háversine, QR match, speed check, anti-cheat logging |
| `refresh_leaderboard` | Cron diario: snapshot de leaderboard_entries (nacional monthly/yearly/historical) |
| `promote_member` | Valida requisitos de rango y promueve miembro en club |
| `check_rank_eligibility` | Lista rangos disponibles según KM/XP/retos del miembro |
| `verify_mileage` | Admin verifica/rechaza entry manual de kilometraje |
| `suggest_motoposadas` | Sugiere motoposadas cerca de waypoints de ruta |
| `create_route_with_motoposadas` | Crea ruta con waypoints y auto-incluye motoposadas cercanas |

### 🔧 STACK TÉCNICO

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.12+, flutter_bloc 9.1, equatable |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions Deno) |
| DB driver | supabase_flutter 2.16+ (consulta directa sin repositorios) |
| Patrón | BLoC directo (sin capa de repositorio/usecase intermedia en la mayoría de features) |
| Diseño | Sistema de diseño Asfalto (ámbar/cyan, dark-first, tokens en design_tokens.dart) |

---

## 3. ALCANCE

### ✅ INCLUIDO (2 features)

| ID | Feature | Descripción |
|----|---------|-------------|
| **F-40** | Economía In-Game | Sistema de monedas (coins) con triggers de earning al hacer raids/completar logros/subir nivel. Tienda cosmética (shop) con items cosmetic/consumable. Compra vía Edge Function. Inventario de usuario. |
| **F-41** | Battle Pass por Temporada | Pase de temporada con 50 tiers. Misiones diarias (3/día) y semanales (5/semana). Track free + premium (pago con coins). Recompensas cosméticas y consumibles. Progresión vía XP in-season. |
| **F-42** | Showcase Profile | Perfil épico tipo Steam: vitrina de parches equipados, insignias de raids/rutas legendarias, álbum de conquistas (fotos trofeo), banner personalizable, grid de logros 100%, estadísticas de por vida (KM totales, raids, clubs). |

### ♻️ QUÉ SE REUTILIZA / REFACTOREA

| Componente | Acción |
|------------|--------|
| `user_xp.coins` | Usar columna existente. Añadir trigger para earning automático |
| `shop_items` + `user_purchases` | Tablas existentes. Añadir Edge Function para procesar compra |
| `battle_passes` + `battle_pass_progress` + `battle_pass_missions` + `user_missions_progress` | Tablas existentes. Conectar con lógica Flutter + EF |
| `xp_progress_card.dart` | Añadir sección de coins con icono y botón "Ir a tienda" |
| `dashboard_screen.dart` | Añadir badge de coins + botón de Battle Pass |
| `finish-raid` EF | Añadir otorgamiento de coins al completar raid |
| `award_xp` RPC | Extender para también otorgar coins cuando corresponde |
| `006_seed.sql` | Seed de battle pass seasons + missions |
| Sistema de diseño | Usar tokens existentes (AppColors.primary/amber para premium, cyan para free) |

| `profile_screen.dart` | Rediseñar completamente como Showcase Profile con vitrina, stats, conquistas |
| `patches_screen.dart` | Integrar como sección de equipamiento en el showcase (elegir parches a mostrar) |
| `achievements_screen.dart` | Mostrar grid de logros dentro del showcase con progreso 100% |
| `dashboard_screen.dart` | Enlace rápido al showcase profile desde el avatar |

### ❌ EXCLUIDO

| Componente | Razón |
|------------|-------|
| Pago real (IAP) con dinero fiat | Scope separado, requiere Google Play / App Store setup + backend de pagos |
| Sistema de crafting o fusión de items | Post-MVP |
| NFTs o blockchain | No alineado con el diseño |
| Sistema de regalos entre usuarios | Post-MVP |
| Subasta o mercado P2P | Post-MVP |

---

## 4. REQUISITOS FUNCIONALES

### F-40: Economía In-Game

| # | Requisito | Prioridad |
|---|-----------|-----------|
| F40.1 | Los usuarios ganan **coins** al: completar un raid (5 coins base + bonus), capturar un checkpoint (2 coins), subir de nivel (10 coins × nivel), completar un logro (recompensa en coins según achievement) | P0 |
| F40.2 | La tienda (`shop`) muestra items disponibles con precio en coins. Items marcados como `battle_pass_only` no se muestran a usuarios sin BP premium activo | P0 |
| F40.3 | Al hacer tap en "Comprar", se invoca Edge Function que: verifica saldo suficiente, descuenta coins, inserta en `user_purchases`, retorna item | P0 |
| F40.4 | Los items comprados aparecen en un **inventario** (inventario = user_purchases activas). Los cosméticos se pueden equipar/desequipar | P0 |
| F40.5 | Los consumibles (`xp_boost_small`) se activan desde el inventario y expiran tras usarse (is_active=false) | P1 |
| F40.6 | El header de la app y dashboard muestran el saldo actual de coins con icono | P0 |

### F-41: Battle Pass por Temporada

| # | Requisito | Prioridad |
|---|-----------|-----------|
| F41.1 | Cada temporada tiene 50 tiers. Cada tier requiere N puntos de XP de temporada (`xp_in_season`). Fórmula: `xp_per_tier = 100 + (tier × 10)` → tier 1 = 110 XP, tier 50 = 600 XP, total ~17,775 XP | P0 |
| F41.2 | Hay dos tracks: **Free** (recompensas básicas cada ~5 tiers) y **Premium** (recompensa en cada tier, activado pagando 500 coins) | P0 |
| F41.3 | Las **misiones diarias** (3/día, se refrescan cada 24h) otorgan 50-150 XP de temporada. Las **semanales** (5/semana, se refrescan los lunes) otorgan 200-500 XP | P0 |
| F41.4 | Al completar una misión, el progreso se marca como completado y se suma XP al `battle_pass_progress.xp_in_season` | P0 |
| F41.5 | Al acumular suficiente XP de temporada, se desbloquea el siguiente tier. El usuario debe reclamar manualmente la recompensa del tier desde la pantalla de BP | P0 |
| F41.6 | La pantalla de Battle Pass muestra: tiers (grid visual estilo pista de carreras), track free vs premium, progreso, misiones activas, días restantes | P0 |
| F41.7 | Al finalizar la temporada, el progreso no reclamado se pierde. Se crea automáticamente una nueva temporada (via cron/EF) | P2 |
| F41.8 | El XP de temporada se gana también al: completar raids (10% del XP base va a season XP), completar checkpoints (5 XP de temporada), completar rutas (3 XP por km) | P1 |

---

### F-42: Showcase Profile (Perfil Épico tipo Steam)

| # | Requisito | Prioridad |
|---|-----------|-----------|
| F42.1 | El perfil muestra un **header épico** con: avatar con marco (desbloqueable en tienda/BP), nombre, rango/nivel, membresía, título cosmético equipado | P0 |
| F42.2 | **Vitrina de parches equipados**: el usuario selecciona hasta 6 parches de su inventario (user_purchases tipo cosmetic/subtype patch/badge) para mostrar en el perfil. Grid 2×3 o 3×2 con glow/animación | P0 |
| F42.3 | **Insignias de raids legendarios**: badge automático al completar raids especiales (Sobrevivencia, Ruta Gótica, Guerra de Clanes). Sección "Conquistas" separada | P0 |
| F42.4 | **Álbum de conquistas**: fotos trofeo al completar raids/logros (store en Supabase Storage). Grid tipo galería con zoom | P1 |
| F42.5 | **Grid de logros**: 17 logros RPG con progreso (completados con glow, pendientes opacos) + porcentaje global | P0 |
| F42.6 | **Estadísticas de por vida**: KM totales, raids por modo, checkpoints, clubs, racha máxima, coins ganados | P0 |
| F42.7 | **Banner personalizable**: imagen de fondo del perfil (shop_items subtype profile_banner). Elegir desde inventario | P1 |
| F42.8 | **Secciones colapsables**: vitrina, conquistas, logros, stats colapsables para scroll manejable | P1 |
| F42.9 | **Perfil público**: cualquier motero puede ver el showcase (community, club members). Solo lectura | P1 |

---

## 5. ARQUITECTURA TÉCNICA

### 5.1 Esquema de Base de Datos

**NOTA**: Todas las tablas YA EXISTEN en migration 004. Solo se añaden:

```sql
-- Migration 011: Battle Pass + Economy enhancements

BEGIN;

-- ============================================================
-- 1. Función para otorgar coins (usada por triggers + EF)
-- ============================================================
CREATE OR REPLACE FUNCTION award_coins(
    p_user_id UUID,
    p_coins INT
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_new_coins INT;
BEGIN
    UPDATE user_xp
    SET coins = coins + p_coins
    WHERE user_id = p_user_id
    RETURNING coins INTO v_new_coins;
    RETURN v_new_coins;
END;
$$;

-- ============================================================
-- 2. Función para descontar coins (usada por EF de compra)
-- ============================================================
CREATE OR REPLACE FUNCTION spend_coins(
    p_user_id UUID,
    p_coins INT
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current INT;
    v_new INT;
BEGIN
    SELECT coins INTO v_current FROM user_xp WHERE user_id = p_user_id;
    IF v_current IS NULL OR v_current < p_coins THEN
        RAISE EXCEPTION 'Coins insuficientes: tiene %, necesita %', COALESCE(v_current, 0), p_coins;
    END IF;
    UPDATE user_xp SET coins = coins - p_coins WHERE user_id = p_user_id
    RETURNING coins INTO v_new;
    RETURN v_new;
END;
$$;

-- ============================================================
-- 3. Trigger: otorgar coins al subir de nivel
-- ============================================================
CREATE OR REPLACE FUNCTION award_coins_on_level_up()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_levels_gained INT;
    v_bonus INT;
    i INT;
BEGIN
    IF NEW.level > OLD.level THEN
        v_levels_gained := NEW.level - OLD.level;
        v_bonus := 0;
        FOR i IN 1..v_levels_gained LOOP
            v_bonus := v_bonus + (OLD.level + i) * 10;
        END LOOP;
        UPDATE user_xp SET coins = coins + v_bonus WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_coins_on_level_up ON user_xp;
CREATE TRIGGER trg_coins_on_level_up
    AFTER UPDATE OF level ON user_xp
    FOR EACH ROW
    WHEN (NEW.level > OLD.level)
    EXECUTE FUNCTION award_coins_on_level_up();

-- ============================================================
-- 4. Trigger: otorgar coins al completar logro
-- ============================================================
CREATE OR REPLACE FUNCTION award_coins_on_achievement()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_coins_reward INT;
BEGIN
    SELECT COALESCE(xp_reward / 2, 10) INTO v_coins_reward
    FROM achievements WHERE id = NEW.achievement_id;
    UPDATE user_xp SET coins = coins + v_coins_reward WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_coins_on_achievement ON user_achievements;
CREATE TRIGGER trg_coins_on_achievement
    AFTER INSERT ON user_achievements
    FOR EACH ROW
    EXECUTE FUNCTION award_coins_on_achievement();

-- ============================================================
-- 5. RLS: permitir INSERT en user_purchases (solo via EF service_role)
-- ============================================================
CREATE POLICY "up_insert_system" ON user_purchases
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 6. RLS: permitir INSERT/UPDATE en battle_pass_progress y user_missions_progress (solo via EF)
-- ============================================================
CREATE POLICY "bpp_insert_system" ON battle_pass_progress
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "bpp_update_system" ON battle_pass_progress
    FOR UPDATE USING (auth.role() = 'service_role');
CREATE POLICY "ump_insert_system" ON user_missions_progress
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "ump_update_system" ON user_missions_progress
    FOR UPDATE USING (auth.role() = 'service_role');

-- ============================================================
-- 7. Crear season_pass_xp (XP de temporada lograda en raids/rutas)
-- ============================================================
CREATE TABLE IF NOT EXISTS season_pass_xp_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    battle_pass_id  UUID NOT NULL REFERENCES battle_passes(id) ON DELETE CASCADE,
    source          TEXT NOT NULL CHECK (source IN ('raid', 'checkpoint', 'route', 'mission', 'purchase')),
    source_id       BIGINT,
    xp_awarded      INT NOT NULL CHECK (xp_awarded > 0),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sp_xp_log_user_bp ON season_pass_xp_log(user_id, battle_pass_id);

-- ============================================================
-- 8. Función: reclamar tier de Battle Pass
-- ============================================================
CREATE OR REPLACE FUNCTION claim_battle_pass_tier(
    p_user_id UUID,
    p_battle_pass_id UUID
) RETURNS TABLE(new_tier INT, claimed BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_tier INT;
    v_xp_in_season INT;
    v_xp_required INT;
    v_has_premium BOOLEAN;
    v_rewards JSONB;
    v_claimed JSONB;
BEGIN
    -- Get current progress
    SELECT current_tier, xp_in_season, has_premium, claimed_rewards
    INTO v_current_tier, v_xp_in_season, v_has_premium, v_claimed
    FROM battle_pass_progress
    WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id;

    IF v_current_tier IS NULL THEN
        RAISE EXCEPTION 'No hay progreso activo para este Battle Pass';
    END IF;

    -- Check if already claimed this tier
    IF v_claimed IS NOT NULL AND v_claimed @> to_jsonb(v_current_tier) THEN
        RETURN QUERY SELECT v_current_tier, false;
        RETURN;
    END IF;

    -- Calculate XP required for next tier
    v_xp_required := 100 + (v_current_tier * 10);

    IF v_xp_in_season < v_xp_required THEN
        RAISE EXCEPTION 'XP insuficiente para el tier %: necesita %, tiene %',
            v_current_tier, v_xp_required, v_xp_in_season;
    END IF;

    -- Mark tier as claimed
    v_claimed := COALESCE(v_claimed, '[]'::JSONB) || to_jsonb(v_current_tier);

    UPDATE battle_pass_progress
    SET claimed_rewards = v_claimed
    WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id;

    RETURN QUERY SELECT v_current_tier, true;
END;
$$;

-- ============================================================
-- 9. Función: progresar al siguiente tier
-- ============================================================
CREATE OR REPLACE FUNCTION advance_battle_pass_tier(
    p_user_id UUID,
    p_battle_pass_id UUID
) RETURNS TABLE(new_tier INT, advanced BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_tier INT;
    v_xp_in_season INT;
    v_max_tier INT := 50;
BEGIN
    SELECT current_tier, xp_in_season
    INTO v_current_tier, v_xp_in_season
    FROM battle_pass_progress
    WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id;

    IF v_current_tier >= v_max_tier THEN
        RETURN QUERY SELECT v_current_tier, false;
        RETURN;
    END IF;

    IF v_xp_in_season >= 100 + (v_current_tier * 10) THEN
        UPDATE battle_pass_progress
        SET current_tier = current_tier + 1
        WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id
        RETURNING current_tier INTO v_current_tier;

        RETURN QUERY SELECT v_current_tier, true;
    ELSE
        RETURN QUERY SELECT v_current_tier, false;
    END IF;
END;
$$;

COMMIT;
```

##### F-42: Showcase Profile — nuevas tablas

```sql
-- Migration 011 (continuación): Showcase Profile

-- 11. Equipped showcase items (patches, banner, title, frame)
CREATE TABLE IF NOT EXISTS user_showcase (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    equipped_patches UUID[] DEFAULT '{}',         -- hasta 6 patch IDs de user_purchases
    equipped_banner UUID,                          -- user_purchase id del banner activo
    equipped_title  UUID,                          -- user_purchase id del título activo
    equipped_frame  UUID,                          -- user_purchase id del marco de avatar
    bg_color        TEXT DEFAULT '#0A0A0F',        -- color de fondo del showcase
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 12. Conquest photos (fotos trofeo de raids/logros)
CREATE TABLE IF NOT EXISTS conquest_photos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source          TEXT NOT NULL CHECK (source IN ('raid', 'achievement', 'route', 'checkpoint')),
    source_id       TEXT,                          -- raid_id, achievement_id, etc.
    photo_url       TEXT NOT NULL,                 -- Supabase Storage URL
    caption         TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_conquest_photos_user ON conquest_photos(user_id);

-- RLS: user_showcase (lectura pública, escritura solo dueño via EF)
ALTER TABLE user_showcase ENABLE ROW LEVEL SECURITY;
CREATE POLICY "usc_select_public" ON user_showcase FOR SELECT USING (true);
CREATE POLICY "usc_update_own" ON user_showcase FOR UPDATE USING (auth.uid() = user_id);

-- RLS: conquest_photos (lectura pública, escritura solo dueño)
ALTER TABLE conquest_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cp_select_public" ON conquest_photos FOR SELECT USING (true);
CREATE POLICY "cp_insert_own" ON conquest_photos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "cp_delete_own" ON conquest_photos FOR DELETE USING (auth.uid() = user_id);
```

### 5.2 Edge Functions

#### EF: `purchase-item`

```
POST /purchase-item
Body: { item_id: UUID }
Auth: Bearer token (usuario autenticado)
Response: { success: true, item: shop_item, coins_remaining: int }

Lógica:
1. Verificar auth → user_id
2. Obtener item de shop_items (validar is_active, battle_pass_only)
3. Si battle_pass_only: verificar que user tiene BP premium activo
4. Verificar coins suficientes via spend_coins(user_id, item.coins_cost)
5. Insertar en user_purchases (user_id, item_id)
6. Si es consumible: aplicar efecto inmediato (ej: XP boost)
7. Retornar item + saldo restante
```

#### EF: `complete-bp-mission`

```
POST /complete-bp-mission
Body: { mission_id: UUID }
Auth: Bearer token
Response: { success: true, xp_awarded: int, tier_advanced: bool }

Lógica:
1. Verificar auth → user_id
2. Obtener mission de battle_pass_missions
3. Obtener user_missions_progress (user_id, mission_id)
4. Validar que progress >= target y !is_completed
5. Marcar is_completed = true
6. Sumar XP a battle_pass_progress.xp_in_season
7. Insertar en season_pass_xp_log
8. Llamar advance_battle_pass_tier para verificar si avanza de tier
9. Retornar XP + resultado de avance
```

#### EF: `activate-bp-premium`

```
POST /activate-bp-premium
Body: { battle_pass_id: UUID }
Auth: Bearer token
Response: { success: true, has_premium: true }

Lógica:
1. Verificar auth → user_id
2. Verificar que battle_pass está activo
3. Costo: 500 coins (via spend_coins)
4. Actualizar battle_pass_progress.has_premium = true
5. Si no existe registro, crearlo con INSERT
```

### 5.3 Flutter — Estructura de Features

#### `lib/features/economy/` — Nuevo módulo

```
lib/features/economy/
├── economy.dart                                  # barrel export
├── data/
│   ├── datasources/
│   │   └── economy_remote_datasource.dart        # EF calls (purchase, activate)
│   └── models/
│       ├── shop_item_model.dart                  # from shop_items row
│       └── user_purchase_model.dart              # from user_purchases row
├── domain/
│   └── entities/
│       ├── shop_item_entity.dart
│       └── inventory_item_entity.dart
├── presentation/
│   ├── bloc/
│   │   ├── shop_bloc.dart                       # load items, purchase
│   │   ├── shop_event.dart
│   │   └── shop_state.dart
│   └── screens/
│       ├── shop_screen.dart                     # tienda grid
│       └── inventory_screen.dart                # inventario de usuario
│   └── widgets/
│       ├── shop_item_card.dart                  # card individual
│       ├── coins_badge.dart                     # badge flotante de coins
│       └── purchase_confirmation_bottom_sheet.dart
```

#### `lib/features/battle_pass/` — Nuevo módulo

```
lib/features/battle_pass/
├── battle_pass.dart                             # barrel export
├── data/
│   ├── datasources/
│   │   └── battle_pass_remote_datasource.dart   # EF calls (complete mission, activate premium, claim)
│   └── models/
│       ├── battle_pass_model.dart
│       ├── battle_pass_mission_model.dart
│       └── battle_pass_progress_model.dart
├── domain/
│   └── entities/
│       ├── battle_pass_entity.dart
│       ├── battle_pass_tier_entity.dart
│       └── battle_pass_mission_entity.dart
├── presentation/
│   ├── bloc/
│   │   ├── battle_pass_bloc.dart               # load BP, load missions, complete mission, claim tier
│   │   ├── battle_pass_event.dart
│   │   └── battle_pass_state.dart
│   └── screens/
│       ├── battle_pass_screen.dart             # pantalla principal del BP
│       └── mission_detail_screen.dart          # detalle de misión
│   └── widgets/
│       ├── tier_grid.dart                      # grid visual de 50 tiers
│       ├── tier_item.dart                      # cada tier (free vs premium reward)
│       ├── mission_card.dart                   # card de misión con progreso
│       ├── battle_pass_header.dart             # season info + XP bar
│       └── premium_cta_banner.dart            # banner "Upgrade to Premium"
```

#### Modificaciones a features existentes

| Archivo | Cambio |
|---------|--------|
| `xp_progress_card.dart` | Añadir fila de coins con icono y botón "TIENDA" |
| `dashboard_screen.dart` | Añadir badge flotante de coins en header + botón "PASE" en action grid (reemplazar o agregar al grid 3×2 o 2×3) |
| `app.dart` | Registrar `ShopBloc` y `BattlePassBloc` en `MultiBlocProvider` |
| `finish-raid/index.ts` | Al finalizar raid, otorgar 5 coins base + 2 coins por checkpoint capturado + 10% XP goes to season XP |
| `validate-checkpoint/index.ts` | Otorgar 2 coins + 5 XP de temporada al capturar checkpoint |

### 5.4 Estructura del Battle Pass Screen

```
┌─────────────────────────────────────────────┐
│  ↑ Temporada 1: "Ruta del Asfalto"          │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░  65%    Tier 33/50 │
│  ───── 12 días restantes ─────              │
│  [Free Track]         [Premium 💎]          │
├─────────────────────────────────────────────┤
│                                             │
│  TIER 1  TIER 2  TIER 3 ...  TIER 10       │
│  ┌───┐   ┌───┐   ┌───┐       ┌───┐        │
│  │ 🏍️│   │ 🔒│   │ 🔒│       │ 🔒│        │
│  │ FREE│  │    │   │    │       │    │        │
│  │ CASC│   │    │   │    │       │    │        │
│  └───┘   └───┘   └───┘       └───┘        │
│                                             │
│  ... horizontal scroll row by row           │
│                                             │
├─────────────────────────────────────────────┤
│  MISIÓN DIARIA ① 🔥                         │
│  [████████░░░░] 80% — 4/5 raids             │
│  +120 XP · Recompensa: +50 coins           │
│                                             │
│  MISIÓN DIARIA ②                            │
│  [░░░░░░░░░░░] 0% — 0/3 checkpoints        │
│  +80 XP                                      │
│                                             │
│  MISIÓN SEMANAL ①                           │
│  [██████░░░░░░] 50% — 25/50 km             │
│  +400 XP                                     │
└─────────────────────────────────────────────┘
```

### 5.6 Flutter — Showcase Profile Module (`lib/features/showcase/`)

```
lib/features/showcase/
├── showcase.dart                                 # barrel export
├── data/
│   ├── datasources/
│   │   └── showcase_remote_datasource.dart       # queries + update EF calls
│   └── models/
│       ├── showcase_model.dart                   # user_showcase row
│       └── conquest_photo_model.dart             # conquest_photos row
├── domain/
│   └── entities/
│       ├── showcase_entity.dart
│       └── conquest_photo_entity.dart
├── presentation/
│   ├── bloc/
│   │   ├── showcase_bloc.dart                   # load showcase, equip/unequip items
│   │   ├── showcase_event.dart
│   │   └── showcase_state.dart
│   └── screens/
│       └── showcase_profile_screen.dart          # pantalla principal tipo Steam
│   └── widgets/
│       ├── showcase_header.dart                  # avatar + marco + banner + título
│       ├── patches_vitrine.dart                  # grid 2×3 o 3×2 parches equipados
│       ├── conquests_section.dart                # insignias legendarias
│       ├── photo_album.dart                      # galería de conquistas
│       ├── achievements_grid.dart                # logros con progreso
│       └── lifetime_stats.dart                   # estadísticas de por vida
```

### 5.7 Estructura del Showcase Profile Screen

```
┌─────────────────────────────────────────────┐
│  ┌─────┐                                    │
│  │  👤  │  LEYENDA DEL ASFALTO              │
│  │     │  nivel 42 · 15,230 XP             │
│  └─────┘  Miembro Premium · 5 años          │
│  ── [Banner personalizable] ──              │
├─────────────────────────────────────────────┤
│  PARCHES EQUIPADOS      [Editar >]          │
│  ┌──┐ ┌──┐ ┌──┐                            │
│  │🔥│ │👑│ │🏁│                            │
│  └──┘ └──┘ └──┘                            │
│  ┌──┐ ┌──┐ ┌──┐                            │
│  │⚔️│ │🌙│ │💀│                            │
│  └──┘ └──┘ └──┘                            │
├─────────────────────────────────────────────┤
│  CONQUISTAS LEGENDARIAS                     │
│  ⭐ Sobreviviente · ⭐ Ruta Gótica          │
│  ⭐ Velocista · ⭐ 1000km Club              │
├─────────────────────────────────────────────┤
│  ÁLBUM DE CONQUISTAS     [Ver todo >]       │
│  ┌────┐ ┌────┐ ┌────┐                      │
│  │📸  │ │📸  │ │📸  │                      │
│  └────┘ └────┘ └────┘                      │
├─────────────────────────────────────────────┤
│  LOGROS   ▓▓▓▓▓▓▓░░░  12/17 (70%)          │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                 │
│  │🏁│ │🌙│ │👑│ │⚡│ │🗺️│                 │
│  │✅│ │✅│ │🔒│ │✅│ │✅│                 │
│  └──┘ └──┘ └──┘ └──┘ └──┘                 │
├─────────────────────────────────────────────┤
│  ESTADÍSTICAS DE POR VIDA                   │
│  🏍️ 1,247 KM    🏁 43 raids               │
│  📍 158 checkpoints  ⚔️ 8 clubs            │
│  🔥 12 días racha  🪙 2,450 coins          │
└─────────────────────────────────────────────┘
```

### 5.8 Fórmulas Económicas

| Concepto | Fórmula |
|----------|---------|
| **Coins por raid completado** | `5 base + 2 × checkpoints_captured + bonus_night + bonus_streak` |
| **Coins por checkpoint** | `2` |
| **Coins por subir de nivel** | `nuevo_nivel × 10` (automático via trigger) |
| **Coins por logro** | `xp_reward / 2` (automático via trigger) |
| **XP de temporada por raid** | `baseXp × 0.1` (10% del XP base) |
| **XP de temporada por checkpoint** | `5` |
| **XP de temporada por km de ruta** | `3 × km` |
| **Costo premium BP** | `500 coins` (pago único por temporada) |
| **XP por tier** | `100 + (tier × 10)` → tier 1: 110, tier 50: 600 |
| **Tiers totales** | `50` |
| **XP total para max BP** | `sum_{t=1}^{50} (100 + t×10) ≈ 17,775` |
| **Misiones diarias** | `3/día`, `50-150 XP` c/u, se refrescan cada 24h |
| **Misiones semanales** | `5/semana`, `200-500 XP` c/u, se refrescan los lunes |

---

## 6. PLAN DE IMPLEMENTACIÓN

### Fase 1: SQL Migration 011 — Triggers + Funciones (2h)

| # | Tarea | Archivos | Esfuerzo |
|---|-------|----------|----------|
| 1.1 | Crear `award_coins()` + `spend_coins()` functions | `supabase/migrations/011_battle_pass_economy.sql` | 15m |
| 1.2 | Crear trigger `trg_coins_on_level_up` en user_xp | migration 011 | 15m |
| 1.3 | Crear trigger `trg_coins_on_achievement` en user_achievements | migration 011 | 15m |
| 1.4 | Crear `season_pass_xp_log` table | migration 011 | 10m |
| 1.5 | Crear `claim_battle_pass_tier()` + `advance_battle_pass_tier()` RPCs | migration 011 | 20m |
| 1.6 | Añadir RLS policies para INSERT/UPDATE system en economy/BP tables | migration 011 | 15m |
| 1.7 | Seed de temporada 1 + misiones diarias/semanales | migration 011 seed | 30m |

### Fase 2: Edge Functions (3h)

| # | Tarea | Archivos | Esfuerzo |
|---|-------|----------|----------|
| 2.1 | Crear EF `purchase-item` | `supabase/functions/purchase-item/index.ts` | 1h |
| 2.2 | Modificar EF `finish-raid` para otorgar coins + season XP | `supabase/functions/finish-raid/index.ts` | 30m |
| 2.3 | Modificar EF `validate-checkpoint` para otorgar coins + season XP | `supabase/functions/validate-checkpoint/index.ts` | 30m |
| 2.4 | Crear EF `complete-bp-mission` | `supabase/functions/complete-bp-mission/index.ts` | 45m |
| 2.5 | Crear EF `activate-bp-premium` | `supabase/functions/activate-bp-premium/index.ts` | 15m |

### Fase 3: Flutter — Economy Module (4h)

| # | Tarea | Archivos | Esfuerzo |
|---|-------|----------|----------|
| 3.1 | Crear `ShopBloc` (load items, purchase flow) | `lib/features/economy/presentation/bloc/` | 45m |
| 3.2 | Crear `shop_screen.dart` — grid de items con precio y botón comprar | `lib/features/economy/presentation/screens/shop_screen.dart` | 1h |
| 3.3 | Crear `inventory_screen.dart` — lista de purchases activas con equipar/activar | `lib/features/economy/presentation/screens/inventory_screen.dart` | 45m |
| 3.4 | Crear `coins_badge.dart` widget reutilizable | `lib/features/economy/presentation/widgets/coins_badge.dart` | 15m |
| 3.5 | Crear `purchase_confirmation_bottom_sheet.dart` | `lib/features/economy/presentation/widgets/` | 15m |
| 3.6 | Models: `shop_item_model.dart`, `user_purchase_model.dart` | `lib/features/economy/data/models/` | 20m |
| 3.7 | Datasource: `economy_remote_datasource.dart` (EF calls) | `lib/features/economy/data/datasources/` | 30m |
| 3.8 | Barrel export + BLoC registration in app.dart | `lib/features/economy/economy.dart`, `lib/app.dart` | 10m |

### Fase 4: Flutter — Battle Pass Module (6h)

| # | Tarea | Archivos | Esfuerzo |
|---|-------|----------|----------|
| 4.1 | Crear `BattlePassBloc` (load BP, missions, complete, claim tier) | `lib/features/battle_pass/presentation/bloc/` | 1h |
| 4.2 | Crear `battle_pass_screen.dart` — pantalla principal del BP | `lib/features/battle_pass/presentation/screens/battle_pass_screen.dart` | 2h |
| 4.3 | Crear `tier_grid.dart` + `tier_item.dart` — grid horizontal de 50 tiers | `lib/features/battle_pass/presentation/widgets/` | 1h |
| 4.4 | Crear `mission_card.dart` — card de misión con progreso y botón claim | `lib/features/battle_pass/presentation/widgets/mission_card.dart` | 30m |
| 4.5 | Crear `battle_pass_header.dart` + `premium_cta_banner.dart` | `lib/features/battle_pass/presentation/widgets/` | 30m |
| 4.6 | Models: `battle_pass_model.dart`, `mission_model.dart`, `progress_model.dart` | `lib/features/battle_pass/data/models/` | 30m |
| 4.7 | Datasource: `battle_pass_remote_datasource.dart` | `lib/features/battle_pass/data/datasources/` | 30m |
| 4.8 | Barrel export + BLoC registration | `lib/features/battle_pass/battle_pass.dart`, `lib/app.dart` | 10m |

### Fase 5: Integración en Features Existentes (3h)

| # | Tarea | Archivos | Esfuerzo |
|---|-------|----------|----------|
| 5.1 | Modificar `xp_progress_card.dart` — añadir sección coins + botón tienda | `lib/features/progression/presentation/widgets/xp_progress_card.dart` | 30m |
| 5.2 | Modificar `dashboard_screen.dart` — añadir badge coins + botón BP en grid | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | 45m |
| 5.3 | Modificar EF `finish-raid` — integrar coins + season XP | `supabase/functions/finish-raid/index.ts` | 30m |
| 5.4 | Modificar EF `validate-checkpoint` — integrar coins + season XP | `supabase/functions/validate-checkpoint/index.ts` | 30m |
|| 5.5 | Añadir `CoinsBadge` en main shell scaffold | `lib/core/widgets/main_shell.dart` | 15m |
|| 5.6 | Rediseñar `profile_screen.dart` como enlace al ShowcaseProfileScreen | `lib/features/profile/presentation/screens/profile_screen.dart` | 30m |
|| 5.7 | Añadir botón "TIENDA" y "PASE" en dashboard grid | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | 20m |
|| 5.8 | Tests de integración (opcional en esta fase) | — | 30m |

### Fase 6: Flutter — Showcase Profile Module (6h)

| # | Tarea | Archivos | Esfuerzo |
|---|-------|----------|----------|
| 6.1 | Crear `ShowcaseBloc` (load showcase, equip/unequip) | `lib/features/showcase/presentation/bloc/` | 1h |
| 6.2 | Crear `showcase_profile_screen.dart` — pantalla principal tipo Steam | `lib/features/showcase/presentation/screens/showcase_profile_screen.dart` | 2h |
| 6.3 | Crear `showcase_header.dart` — avatar + marco + banner + título equipado | `lib/features/showcase/presentation/widgets/showcase_header.dart` | 45m |
| 6.4 | Crear `patches_vitrine.dart` — grid 2×3 parches equipados con glow | `lib/features/showcase/presentation/widgets/patches_vitrine.dart` | 30m |
| 6.5 | Crear `conquests_section.dart` — insignias de raids legendarios | `lib/features/showcase/presentation/widgets/conquests_section.dart` | 30m |
| 6.6 | Crear `photo_album.dart` — galería de conquistas desde Storage | `lib/features/showcase/presentation/widgets/photo_album.dart` | 45m |
| 6.7 | Crear `achievements_grid.dart` — logros con progreso + porcentaje | `lib/features/showcase/presentation/widgets/achievements_grid.dart` | 30m |
| 6.8 | Crear `lifetime_stats.dart` — estadísticas de por vida | `lib/features/showcase/presentation/widgets/lifetime_stats.dart` | 30m |
| 6.9 | Datasource: `showcase_remote_datasource.dart` | `lib/features/showcase/data/datasources/` | 20m |
| 6.10 | Models + barrel + BLoC registration in app.dart | `lib/features/showcase/` | 20m |

---

## 7. RIESGOS Y MITIGACIONES

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Las tablas de migration 004 existen pero pueden no coincidir exactamente con lo esperado (diferencia entre schema declarado y DB real) | Alto | Verificar con `SELECT * FROM information_schema.columns` antes de migration 011 |
| La columna `user_xp.coins` existe pero nunca se ha poblado — triggers nuevos aplican a futuro pero no a XP histórico | Medio | Script de backfill one-time para otorgar coins retroactivos por nivel actual |
| Battle Pass missions requieren sistema de "daily refresh" — no hay scheduler en Supabase Edge Functions para esto | Medio | Usar cron via `pg_cron` (si disponible) o un timer local en Flutter con la fecha del último refresh guardada en `shared_preferences` |
| Las EF existentes (`finish-raid`, `validate-checkpoint`) se modifican — pueden romper funcionalidad actual | Alto | PR separado por EF modificada, test manual después del deploy |
| Seed de temporada 1 + misiones requiere coordinación con diseño de contenidos | Bajo | Crear seed genérico extensible; los nombres/recompensas se cambian via DB |

---

## 8. DEPENDENCIAS

| Dependencia | Tipo | Para |
|------------|------|------|
| Migration 010 aplicada (clubs, routes, mileage, leaderboard) | 🔴 Bloqueante | El BP usa club_id y route_history para season XP |
| Migration 004 aplicada (shop_items, battle_passes, etc.) | 🔴 Bloqueante | Sin esto no hay tablas que conectar |
| Sistema de autenticación Supabase funcionando | 🔴 Bloqueante | Todas las EF y BLoCs dependen de auth |
| Sistema de diseño Asfalto (design_tokens.dart) | 🟢 Existente | Se reutiliza para nuevos widgets |
| BLoC pattern existente en el proyecto | 🟢 Existente | Nuevos BLoCs siguen el mismo patrón |

---

## 9. ESTIMACIÓN TOTAL

| Fase | Esfuerzo |
|------|----------|
| Fase 1: SQL Migration | 2h |
| Fase 2: Edge Functions | 3h |
| Fase 3: Flutter Economy Module | 4h |
| Fase 4: Flutter Battle Pass Module | 6h |
| Fase 5: Integración | 4h |
| **Fase 6: Flutter Showcase Profile** | **6h** |
| **Total estimado** | **~25h / ~4-5 días** |

---

## 10. DECISIONES DE DISEÑO

1. **Coins como columna en user_xp (no tabla separada)**: Ya existe, evita JOIN adicional. La tabla `user_xp` es single-row por usuario.

2. **Service role para writes en economy/BP tables**: Las EF usan `SUPABASE_SERVICE_ROLE_KEY` para insertar en `user_purchases`, `battle_pass_progress`, `user_missions_progress`. RLS prohíbe INSERT directo desde el cliente (seguridad).

3. **Battle Pass como grid horizontal (no vertical scroll infinito)**: 50 tiers caben en ~5 filas de 10. Scroll horizontal por fila, como un tablero de juego. Diseño tipo "pista de carreras".

4. **XP de temporada como columna en battle_pass_progress (no tabla separada)**: Ya existe `xp_in_season`. La tabla `season_pass_xp_log` es solo para auditoría.

5. **No usar `purchases` con `is_active=true` para inventario**: La consulta es directa a `user_purchases` con JOIN a `shop_items` para obtener metadatos del item comprado.

6. **Recompensas del BP no automáticas**: El usuario debe reclamar manualmente cada tier. Esto da sensación de logro y evita confusión de "qué recibí".

7. **Showcase Profile con tabla separada (user_showcase) en vez de columna en user_xp**: La configuración del showcase es opcional y puede estar vacía sin afectar la tabla principal de XP. UNIQUE(user_id) garantiza 1 registro por usuario.

8. **user_showcase con updates directos (no EF)**: A diferencia de economía/BP que usan service_role, el showcase se actualiza directo por el dueño via RLS. Menos latencia y complejidad para cambios cosméticos.

9. **Conquest photos en tabla separada (no JSONB en user_xp)**: Las fotos pueden ser muchas con el tiempo. Una tabla permite paginación, orden por fecha, y eliminación individual.

10. **Todos los features (economía, BP, showcase) en una sola migration 011**: Comparten tablas (shop_items → user_purchases → user_showcase → conquest_photos). Separar migrations complicaría el orden de ejecución.

---
