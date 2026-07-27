# GraphHopper Router — AsfaltoClub
# ============================================================
# Coast OSM extract is baked into the image during GitHub Actions build.
# No runtime download needed — container starts instantly.
# ============================================================

FROM eclipse-temurin:21-jre AS builder

WORKDIR /build

# Install osmium for extraction
RUN apt-get update && apt-get install -y osmium-tool && rm -rf /var/lib/apt/lists/*

# Download full Colombia OSM and extract coast region
RUN curl -sL --retry 5 --retry-delay 10 -o colombia-latest.osm.pbf \
    "https://download.geofabrik.de/south-america/colombia-latest.osm.pbf" && \
    ls -lh colombia-latest.osm.pbf && \
    osmium extract -b "-78,6.0,-71,12.5" -o colombia-coast.osm.pbf \
        --overwrite colombia-latest.osm.pbf && \
    ls -lh colombia-coast.osm.pbf && \
    rm colombia-latest.osm.pbf

# ── Runtime image ──
FROM eclipse-temurin:21-jre

WORKDIR /graphhopper

# Download GraphHopper web JAR
ARG GH_VERSION=11.0
RUN wget -q -O graphhopper-web.jar \
    "https://github.com/graphhopper/graphhopper/releases/download/${GH_VERSION}/graphhopper-web-${GH_VERSION}.jar"

# Copy coast OSM extract and config
COPY --from=builder /build/colombia-coast.osm.pbf /data/colombia-coast.osm.pbf
COPY config.yml /data/gh-config.yml

# Startup is now trivial — just run GraphHopper
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV JAVA_OPTS="-Xms512m -Xmx1g -XX:+UseParallelGC"
EXPOSE 8989 8990

ENTRYPOINT ["/start.sh"]
