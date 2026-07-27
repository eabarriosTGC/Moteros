# GraphHopper Router — AsfaltoClub
# Built by GitHub Actions → pushed to GHCR → Railway deploys from GHCR.
# ============================================================
FROM ghcr.io/graphhopper/graphhopper:11.0
COPY config.yml /data/config.yml
COPY start.sh /start.sh
RUN chmod +x /start.sh
ENV JAVA_OPTS="-Xms1g -Xmx4g -XX:+UseParallelGC"
EXPOSE 8989 8990
ENTRYPOINT ["/start.sh"]
