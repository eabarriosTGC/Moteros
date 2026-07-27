#!/bin/bash
# GraphHopper startup — downloads Colombia OSM, extracts coast region
# ============================================================
# La Guajira + Costa Colombiana bounding box:
#   lon: -78 to -71, lat: 7.5 to 12.5
# Covers: La Guajira, Magdalena, Atlántico, Bolívar, Cesar,
#         Sucre, Córdoba, + partes de Antioquia, Santander
# ============================================================
set -e

FULL_OSM="/data/colombia-latest.osm.pbf"
COAST_OSM="/data/colombia-coast.osm.pbf"
GRAPH_DIR="/data/graph-cache"
GH_JAR="/graphhopper/graphhopper-web.jar"

# Bounding box for Colombian Caribbean coast + La Guajira + northern interior
BBOX="-78,6.0,-71,12.5"

# Download full Colombia OSM if not cached
if [ ! -f "$FULL_OSM" ]; then
    echo "=== Downloading Colombia OSM (~315MB) ==="
    wget -q --show-progress -O "$FULL_OSM" "$OSM_URL" || {
        echo "Retry: deleting incomplete file and re-downloading..."
        rm -f "$FULL_OSM"
        wget -q --show-progress -O "$FULL_OSM" "$OSM_URL" || {
            echo "ERROR: Failed to download OSM data"
            exit 1
        }
    }
    echo "=== Download complete ==="
fi

# Verify OSM file is valid — try osmium extract, delete and retry if corrupted
if [ ! -f "$COAST_OSM" ]; then
    echo "=== Extracting coast region (bbox: $BBOX) ==="
    if osmium extract -b "$BBOX" -o "$COAST_OSM" "$FULL_OSM" 2>/dev/null; then
        echo "=== Extraction complete ==="
    else
        echo "PBF corruption detected — re-downloading full OSM..."
        rm -f "$FULL_OSM" "$COAST_OSM"
        wget -q --show-progress -O "$FULL_OSM" "$OSM_URL" || exit 1
        echo "=== Retry extraction ==="
        osmium extract -b "$BBOX" -o "$COAST_OSM" "$FULL_OSM" || {
            echo "ERROR: Extraction failed even after re-download"
            exit 1
        }
    }
fi

if [ ! -d "$GRAPH_DIR" ]; then
    mkdir -p "$GRAPH_DIR"
    echo "=== First run — importing graph (5-10 mins) ==="
fi

echo "=== Starting GraphHopper ==="
echo "OSM: $COAST_OSM (from $FULL_OSM)"
echo "Config: /data/gh-config.yml"
echo "RAM: $JAVA_OPTS"

exec java $JAVA_OPTS \
    -jar "$GH_JAR" server /data/gh-config.yml
