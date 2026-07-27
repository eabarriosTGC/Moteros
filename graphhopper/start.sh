#!/bin/bash
# GraphHopper startup script — downloads OSM if not cached.
# ============================================================
set -e

OSM_FILE="/data/colombia-latest.osm.pbf"
GRAPH_CACHE_DIR="/data/graph-cache"

# Download OSM data if not present
if [ ! -f "$OSM_FILE" ]; then
    echo "=== Downloading OSM data ==="
    echo "URL: $OSM_URL"
    wget -q --show-progress -O "$OSM_FILE" "$OSM_URL" || {
        echo "ERROR: Failed to download OSM data"
        exit 1
    }
    echo "=== Download complete ==="
fi

# Build graph cache if not present
if [ ! -d "$GRAPH_CACHE_DIR" ] || [ -z "$(ls -A "$GRAPH_CACHE_DIR" 2>/dev/null)" ]; then
    echo "=== Building graph cache (first run — 10-30 mins) ==="
fi

# Find the GraphHopper jar
JAR=$(find / -name "graphhopper-web*.jar" -type f 2>/dev/null | head -1)
if [ -z "$JAR" ]; then
    echo "ERROR: GraphHopper jar not found"
    exit 1
fi

echo "=== Starting GraphHopper ==="
echo "JAR: $JAR"
echo "Config: /data/config.yml"
echo "OSM: $OSM_FILE"
echo "JAVA_OPTS: $JAVA_OPTS"

exec java $JAVA_OPTS \
    -Ddw.graphhopper.datareader.file="$OSM_FILE" \
    -Ddw.graphhopper.graph.location="$GRAPH_CACHE_DIR" \
    -jar "$JAR" server /data/config.yml
