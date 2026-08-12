# Overlay v0.12.1-alpha — raids y conquistas verificadas

Base obligatoria: `v0.11.0-alpha`, commit `ed60bae9011bafc7dbb524a2405683d691171a74`,
o una rama que contenga ese commit.

Este paquete añade raids permanentes y temporales, contador/lista de inscritos,
múltiples QR por destino, llegada verificada con GPS y fotoconquista opcional.
Los raids dejan de depender del rastreo continuo para acreditar kilómetros.
La pantalla activa ya no ofrece «Grabar ruta». Si el proveedor vial no
responde, el creador ve una distancia aproximada y puede publicar de todos
modos; QR + ubicación siguen siendo obligatorios para completar el raid.

## 1. Preparar una rama limpia

Desde la raíz de tu repositorio:

```bash
git status
git switch beta-prioridades
git pull --ff-only
git switch -c feature/raid-conquests
```

Si `git status` muestra cambios, guárdalos en un commit o en `git stash` antes
de extraer el ZIP. El paquete no contiene `.env`, llaves de firma ni carpetas
de compilación.

## 2. Extraer el ZIP

Copia `AsfaltoClub-raids-conquistas-v0.12.1-alpha.zip` a la raíz y ejecuta:

```bash
unzip -o AsfaltoClub-raids-conquistas-v0.12.1-alpha.zip -d .
```

Comprueba el overlay:

```bash
bash tool/verify_raid_conquests.sh
```

## 3. Resolver dependencias y validar Flutter

El paquete actualiza la app a `1.2.1+8` y agrega `qr_flutter: ^4.1.0`.
Regenera el lockfile con tu Flutter
estable:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

No borres ni reemplaces `.env`. Debe conservar `SUPABASE_URL` y la clave
publicable que ya usa la app. Nunca pongas `service_role` en Flutter.

## 4. Aplicar Supabase primero en pruebas

La APK nueva requiere `supabase/migrations/035_raid_conquests.sql`. No instales
la APK antes de aplicar la migración.

Revisa los comandos disponibles en tu versión y enlaza el proyecto de pruebas:

```bash
supabase --version
supabase db push --help
supabase link --project-ref TU_PROJECT_REF_DE_PRUEBAS
supabase db push
supabase migration list
```

Prueba con cuentas reales de ensayo:

1. Un presidente crea un raid permanente y otro con fecha.
2. Desactiva la conexión o el servicio vial, selecciona A y B y confirma que
   aparezca «Distancia estimada» sin bloquear `PUBLICAR RAID`.
3. Un usuario normal no puede crear raids ni generar QR.
4. El presidente genera dos QR y desactiva uno.
5. Un motero se une al temporal y decide si aparece en la lista.
6. Un QR incorrecto, GPS con precisión mayor a 100 m y ubicación fuera del
   radio deben ser rechazados.
7. Una llegada válida debe sumar kilómetros una sola vez.
8. La fotoconquista debe aparecer en `Mis conquistas`.
9. Verifica que la app pueda cerrarse durante el trayecto y completar la
   llegada al abrirla en el destino.

Cuando esas pruebas pasen, enlaza producción, confirma visualmente el `ref` y
ejecuta nuevamente `supabase db push`. La migración es aditiva, pero revoca la
creación directa de `raids`: por eso el código Flutter y el esquema deben salir
en la misma ventana de despliegue.

## 5. Compilar APK

```bash
flutter build apk --release
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Resultado esperado:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Instálala primero en un teléfono de prueba y repite el flujo QR + GPS antes de
distribuirla.

## 6. Subir a GitHub

```bash
git status
git add .github/workflows/ci.yml pubspec.yaml pubspec.lock \
  lib/core/services/routing_service.dart \
  lib/features/dashboard/presentation/screens/rodar_screen.dart \
  lib/features/raids supabase/migrations/035_raid_conquests.sql \
  test/supabase/migration_035_content_test.dart \
  tool/verify_raid_conquests.sh INSTALAR_RAIDS_CONQUISTAS.md
git commit -m "feat(raids): agregar conquistas verificadas por QR y ubicación"
git push -u origin feature/raid-conquests
```

Abre un PR hacia `beta-prioridades`. No subas `.env`, APKs dentro del árbol del
proyecto ni llaves de firma. Para publicar la APK, adjúntala a una pre-release
`v0.12.1-alpha` después de que CI esté verde.

## Recuperación

Antes de desplegar la migración, volver atrás consiste en borrar la rama o
revertir el commit. Después de desplegarla, revierte solo el código si es
necesario y deja las tablas: eliminarlas podría borrar conquistas reales. La
migración conserva los raids anteriores y los clasifica como programados.
