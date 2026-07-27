#!/bin/bash
# GraphHopper startup — OSM data is already baked into the image
# ============================================================
set -e

GH_JAR="/graphhopper/graphhopper-web.jar"
GRAPH_DIR="/data/graph-cache"

if [ ! -d "$GRAPH_DIR" ]; then
    mkdir -p "$GRAPH_DIR"
    echo "=== First run — importing coast graph (3-5 mins) ==="
fi

echo "=== Starting GraphHopper ==="
echo "JAVA_OPTS: $JAVA_OPTS"
exec java $JAVA_OPTS -jar "$GH_JAR" server /data/gh-config.yml
