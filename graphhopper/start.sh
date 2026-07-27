#!/bin/bash
# GraphHopper startup — uses the official JAR directly
# ============================================================
set -e

OSM_FILE="/data/colombia-latest.osm.pbf"
GRAPH_DIR="/data/graph-cache"
GH_JAR="/graphhopper/graphhopper-web.jar"

# Download OSM if not cached
if [ ! -f "$OSM_FILE" ]; then
    echo "=== Downloading OSM data ==="
    wget -q --show-progress -O "$OSM_FILE" "$OSM_URL" || {
        echo "ERROR: Failed to download OSM data"
        exit 1
    }
    echo "=== Download complete ==="
fi

if [ ! -d "$GRAPH_DIR" ]; then
    mkdir -p "$GRAPH_DIR"
    echo "=== First run — importing graph (10-30 mins) ==="
fi

echo "=== Starting GraphHopper ==="
echo "OSM: $OSM_FILE"
echo "Config: /data/gh-config.yml"
echo "JAVA_OPTS: $JAVA_OPTS"

exec java $JAVA_OPTS \
    -Ddw.graphhopper.datareader.file="$OSM_FILE" \
    -Ddw.graphhopper.graph.location="$GRAPH_DIR" \
    -jar "$GH_JAR" server /data/gh-config.yml
