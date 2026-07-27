# GraphHopper Router — AsfaltoClub
# Built by GitHub Actions → pushed to GHCR → Railway deploys from GHCR.
# Uses israelhikingmap/graphhopper which auto-downloads OSM via --url.
# ============================================================
FROM israelhikingmap/graphhopper:latest

COPY config.yml /data/gh-config.yml

# Override entrypoint to use our config + start.sh
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV JAVA_OPTS="-Xms1g -Xmx4g -XX:+UseParallelGC"

EXPOSE 8989 8990

ENTRYPOINT ["/start.sh"]
