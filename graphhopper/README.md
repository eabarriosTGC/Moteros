# GraphHopper Routing Engine — AsfaltoClub

Engine de ruteo auto-gestionado para la app de moteros, basado en
[GraphHopper](https://github.com/graphhopper/graphhopper) (Apache 2.0).

## Requisitos

- Docker + Docker Compose
- ~4-8 GB RAM (Colombia OSM ~200MB, índices ~2GB)
- Opcional: Railway/Render/Fly.io para deploy

## Perfiles

### `motorcycle` (default)
- Evita autopistas (motorway = prioridad 0.1)
- Prefiere curvas (secondary/tertiary = prioridad 1.2-1.3)
- Penaliza caminos sin pavimentar (factor 0.3)
- Evita caminos con restricción motorcycle=no

### `car` (fallback)
- Perfil estándar para auto
- Usa autopistas sin restricción

## Deploy local

```bash
docker compose up -d
```

Probar:
```bash
curl "http://localhost:8989/route?point=4.7110,-74.0721&point=6.2476,-75.5658&profile=motorcycle"
```

## Deploy en Railway

1. Conecta tu repo de GitHub
2. Railway detecta automáticamente el `graphhopper/Dockerfile`
3. Set de build: `graphhopper/Dockerfile`
4. Set de start: `graphhopper/` como root directory
5. Agrega `JAVA_OPTS=-Xms1g -Xmx2g` como variable de entorno
6. Despliega (build inicial ~15-30 min por OSM import)

Luego configura `GRAPHOPPER_URL` en Supabase:
```bash
supabase secrets set GRAPHOPPER_URL=https://tu-graphhopper.up.railway.app
```

## API

GraphHopper expone una API REST en `:8989/route`:

```json
POST /route
{
  "points": [[lng, lat], [lng, lat]],
  "profile": "motorcycle",
  "instructions": true,
  "locale": "es"
}
```

Ver [documentación oficial](https://docs.graphhopper.com/) para más endpoints.
