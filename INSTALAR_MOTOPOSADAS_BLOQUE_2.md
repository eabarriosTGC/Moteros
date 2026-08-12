# Motoposadas — Bloque 2

Base esperada: `feature/motoposadas` en el commit `f979676` (Bloque 1).

## Incluye

- evaluación mutua después de una estancia completada;
- destinatario y rol derivados en PostgreSQL, no por Flutter;
- una evaluación por participante y estancia;
- prohibición de autoevaluación;
- comentario opcional de hasta 500 caracteres;
- reputación separada como anfitrión y huésped;
- comentarios visibles solo para autor y destinatario;
- botones de evaluación y consulta de reputación en ambas bandejas;
- pruebas de migración, contrato del cliente y RPC.

## Instalación

Copiar el contenido del ZIP sobre la raíz del proyecto y ejecutar:

```bash
flutter analyze
flutter test test/supabase/migration_040_content_test.dart
flutter test test/features/refugios
supabase db reset
supabase db advisors
```

Antes de aplicar a un entorno compartido, probar con tres usuarios: anfitrión,
huésped y tercero. Solo los dos participantes de una solicitud `completed`
deben poder evaluar; repetir la evaluación debe producir
`review_already_exists` y no cambiar nuevamente la reputación.
