#!/bin/bash
# GraphHopper startup — downloads Colombia OSM, extracts coast region
# ============================================================
set -e

FULL_OSM="/data/colombia-latest.osm.pbf"
COAST_OSM="/data/colombia-coast.osm.pbf"
GRAPH_DIR="/data/graph-cache"
GH_JAR="/graphhopper/graphhopper-web.jar"

# Bounding box: Colombian Caribbean coast + La Guajira + northern interior
BBOX="-78,6.0,-71,12.5"

# Always start fresh — remove corrupted files from previous runs
rm -f "$COAST_OSM"

# Download full Colombia OSM — retry once on failure
download_osm() {
    echo "=== Downloading Colombia OSM (~315MB) ==="
    if curl -sL --retry 3 --retry-delay 5 -o "$FULL_OSM" "$OSM_URL"; then
        echo "=== Download complete ==="
        return 0
    fi
    echo "=== Download failed, retrying once more... ==="
    rm -f "$FULL_OSM"
    curl -sL --retry 3 --retry-delay 5 -o "$FULL_OSM" "$OSM_URL" || {
        echo "ERROR: Failed to download OSM data"
        exit 1
    }
}

if [ ! -f "$FULL_OSM" ]; then
    download_osm
fi

# Extract coast region if needed — retry on corruption
extract_coast() {
    echo "=== Extracting coast region (bbox: $BBOX) ==="
    if osmium extract -b "$BBOX" -o "$COAST_OSM" "$FULL_OSM" 2>/dev/null; then
        echo "=== Extraction complete ==="
        return 0
    fi
    echo "PBF corruption — re-downloading..."
    rm -f "$FULL_OSM" "$COAST_OSM"
    download_osm
    echo "=== Retrying extraction ==="
    osmium extract -b "$BBOX" -o "$COAST_OSM" "$FULL_OSM" || {
        echo "ERROR: Extraction failed"
        exit 1
    }
}

if [ ! -f "$COAST_OSM" ]; then
    extract_coast
fi

if [ ! -d "$GRAPH_DIR" ]; then
    mkdir -p "$GRAPH_DIR"
    echo "=== First run — importing graph (5-10 mins) ==="
fi

echo "=== Starting GraphHopper ==="
echo "JAVA_OPTS: $JAVA_OPTS"

exec java $JAVA_OPTS -jar "$GH_JAR" server /data/gh-config.yml
