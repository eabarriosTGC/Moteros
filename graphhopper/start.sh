#!/bin/bash
# GraphHopper startup — OSM data is already baked into the image
# ============================================================
set -e

GH_JAR="/graphhopper/graphhopper-web.jar"
GRAPH_DIR="/data/graph-cache"

# Always rebuild graph cache — ensures config changes (encoded_values, etc.)
# take effect. GraphHopper import takes 3-5 min for the coast extract.
rm -rf "$GRAPH_DIR"
mkdir -p "$GRAPH_DIR"

echo "=== Importing coast graph (3-5 mins) ==="
echo "=== Starting GraphHopper ==="
echo "JAVA_OPTS: $JAVA_OPTS"
exec java $JAVA_OPTS -jar "$GH_JAR" server /data/gh-config.yml
