# GraphHopper Routing Engine — AsfaltoClub

Engine de ruteo auto-gestionado para moteros, basado en
[GraphHopper](https://github.com/graphhopper/graphhopper) (Apache 2.0).

## Perfiles

### `motorcycle` (default)
- Evita autopistas, prefiere curvas (secondary/tertiary priority 1.2-1.3)
- Penaliza caminos sin pavimentar, evita restricciones `motorcycle=no`

### `car` (fallback)
- Perfil estándar para auto

## Deploy local

```bash
docker compose up -d
# Build + import OSM Colombia (~15-30 min la primera vez)
# Después:
curl "http://localhost:8989/route?point=4.7110,-74.0721&point=6.2476,-75.5658&profile=motorcycle"
```

## Deploy en Railway

1. Conectá tu repo de GitHub a Railway
2. Creá un **Nuevo Servicio** → **Add GitHub Repo**
3. Configuración del servicio:

| Campo | Valor |
|-------|-------|
| **Root Directory** | `graphhopper` |
| **Build** | automático (Dockerfile) |
| **Start Command** | dejar vacío |

4. Variables de entorno:

| Variable | Valor |
|----------|-------|
| `OSM_URL` | `https://download.geofabrik.de/south-america/colombia-latest.osm.pbf` |
| `JAVA_OPTS` | `-Xms1g -Xmx2g -XX:+UseParallelGC` (plan $7/mes) |

5. Railway asigna un dominio tipo `https://graphhopper.up.railway.app`
6. Copiá esa URL y configurala en Supabase:

```bash
supabase secrets set GRAPHOPPER_URL=https://tu-app.up.railway.app
```

### Notas
- **Primer deploy**: tarda 15-30 min porque descarga + indexa Colombia OSM
- **RAM**: plan Railway $7/mes (512MB→2GB) es suficiente para Colombia si usás `-Xmx2g`
- **Persistencia**: los datos OSM se pierden si Railway reinicia el container (no hay volúmenes persistentes gratis). El startup script redescarga automáticamente.
