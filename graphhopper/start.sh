#!/bin/bash
# GraphHopper startup — uses israelhikingmap/graphhopper's built-in entrypoint
# ============================================================
set -e

OSM_FILE="/data/colombia-latest.osm.pbf"
GRAPH_HOME="/data/default-gh"

# Download OSM if not cached
if [ ! -f "$OSM_FILE" ]; then
    echo "=== Downloading OSM data ==="
    wget -q --show-progress -O "$OSM_FILE" "$OSM_URL" || {
        echo "ERROR: Failed to download OSM data"
        exit 1
    }
    echo "=== Download complete ==="
fi

if [ ! -d "$GRAPH_HOME" ] || [ -z "$(ls -A "$GRAPH_HOME" 2>/dev/null)" ]; then
    echo "=== First run — building graph index (10-30 mins) ==="
fi

echo "=== Starting GraphHopper ==="
echo "Config: /data/gh-config.yml"
echo "OSM: $OSM_FILE"
echo "JAVA_OPTS: $JAVA_OPTS"

exec ./graphhopper.sh \
    -c /data/gh-config.yml \
    -o "$GRAPH_HOME" \
    web \
    -i "$OSM_FILE"
