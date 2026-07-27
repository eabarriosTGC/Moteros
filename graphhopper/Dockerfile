# GraphHopper Routing Engine — self-hosted for AsfaltoClub
# ============================================================
# Base image: uses the official GraphHopper Docker image
# OSM data: Colombia (Geofabrik)
# Profiles: car + motorcycle custom
# Deployment: Railway / Render / Fly.io
#
# Memory: Colombia OSM ~200MB compressed, ~2GB extracted
# RAM needed: ~4-8GB with Contraction Hierarchies
# ============================================================

FROM ghcr.io/graphhopper/graphhopper:11.0 AS download

# Download Colombia OSM data
RUN mkdir -p /data && \
    wget -q -O /data/colombia-latest.osm.pbf \
    https://download.geofabrik.de/south-america/colombia-latest.osm.pbf

FROM ghcr.io/graphhopper/graphhopper:11.0

COPY --from=download /data/colombia-latest.osm.pbf /data/colombia-latest.osm.pbf
COPY config.yml /data/config.yml

# GraphHopper will auto-detect the OSM file and config
# Expose API port
EXPOSE 8989

# JVM tuning for limited-memory environments (Railway $7 plan)
# -Xms1g -Xmx4g: adjust based on your plan
ENV JAVA_OPTS="-Xms1g -Xmx4g -XX:+UseParallelGC -XX:MaxRAM=4g"
