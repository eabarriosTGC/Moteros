# Verify Report — 2026-08-06-beta-prioridades

> Veredicto: **PASS — 23/23 requisitos** (18 PASS test · 5 PASS source-verified · 0 WARNING · 0 FAIL)
> Verificado contra código real (no contra apply-progress) por sub-agente fresh-context, 2026-08-06.

## Evidencia de runtime (ejecutada por el verificador)

| Gate | Resultado |
|---|---|
| `flutter test` (suite completa) | **314/314 PASS** (00:17) |
| `flutter analyze` (branch) | **579 issues** — delta **-1 vs main (580)** |
| Hits analyze en hunks tocados | Solo `settings_screen.dart:611/624` (use_build_context_synchronously) — pre-existentes, fuera de los hunks (+294-313) |
| Errores analyze backend/ + features_archive/ | Pre-existentes (dead code, fuera del diff) |
| Tests nuevos/extendidos | 67 en 14 archivos (250 → 314) |

## Matriz de especificación (resumen)

| Dominio | Requisitos | Estado |
|---|---|---|
| profile-scope-leak | M-PN-1..4 | 4/4 PASS (test) — gear→Settings, editar/logout re-homados, cero imports vivos (M-PN-3 grep), parches sobre PatchesBloc |
| progreso-motoposada-cta | M-MPC-1..4 | 4/4 PASS (test) — 3 estados, typo, minHeight 76, sin botón muerto |
| raid-trip-registration | M-RTR-1..6 | 6/6 PASS — waypoints 0→N→N+1, HUD Marcar parada, trace ordenado (source+unit), RLS sin EXISTS, is_raid_participant, _save fix sin catch vacío |
| conquest-photos | M-CPU-1..4 | 4/4 PASS — upload+insert seams, nunca source_id null, misma lista (contador+álbum), PhotoAlbum vivo en Progreso |
| expired-raids-visibility | M-ERV-1..5 | 5/5 PASS — isExpiredRaid pura, gte UTC, RaidBloc sin filtro, route_history intacto, bottom-sheet intacto |

## Hallazgos no-bloqueantes

- **INFO-1:** M-CPU-4 end-to-end (contador > 0 + álbum con foto) requiere verificación en dispositivo (task 8.2).
- **INFO-2:** M-RTR-3/6 y M-CPU-1/2 surfaces FlutterMap/SnackBar = source/pure-verified (precedente del repo: tile stream cuelga FakeAsync).
- **INFO-3:** Deuda 3.8 → **issue GitHub #4 creado por el orquestador** (https://github.com/eabarriosTGC/Moteros/issues/4).
- **INFO-4:** Open question M-ERV-5 (bottom-sheet de Rodar listable con raids pasados) — spec-literal, documentada.

## Pendientes post-verify

1. sdd-archive (sync specs → openspec/specs/).
2. Aplicar migraciones 028/029 a prod ANTES de distribuir el APK (regla migration-first) — con revisión del usuario.
3. Verificación en dispositivo del usuario (APK 1.1.0+4): M-MPC-4 (motoposada), M-CPU-4 (fotos), M-PN-1/2, M-RTR-1/2/3.
