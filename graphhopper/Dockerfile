# GraphHopper Router — AsfaltoClub
# ============================================================
# Builds from official GraphHopper release JAR.
# No external scripts — everything is self-contained.
# OSM data downloaded at runtime.
# ============================================================

FROM eclipse-temurin:21-jre

WORKDIR /graphhopper

# Install wget
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Download GraphHopper web JAR
ARG GH_VERSION=11.0
RUN wget -q -O graphhopper-web.jar \
    "https://github.com/graphhopper/graphhopper/releases/download/${GH_VERSION}/graphhopper-web-${GH_VERSION}.jar"

# Copy config and startup
COPY config.yml /data/gh-config.yml
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV JAVA_OPTS="-Xms512m -Xmx1g -XX:+UseParallelGC"
EXPOSE 8989 8990

ENTRYPOINT ["/start.sh"]
