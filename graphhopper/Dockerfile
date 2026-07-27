# GraphHopper Router — AsfaltoClub
# OSM data downloaded at RUNTIME (fast build, works on Railway/Render).
# ============================================================
# Required env vars:
#   OSM_URL — URL to .osm.pbf file (default: Colombia)
#   JAVA_OPTS — JVM tuning flags
# ============================================================

FROM ghcr.io/graphhopper/graphhopper:11.0

COPY config.yml /data/config.yml
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV OSM_URL=https://download.geofabrik.de/south-america/colombia-latest.osm.pbf
ENV JAVA_OPTS="-Xms1g -Xmx4g -XX:+UseParallelGC -XX:MaxRAM=4g"

EXPOSE 8989 8990

ENTRYPOINT ["/start.sh"]
