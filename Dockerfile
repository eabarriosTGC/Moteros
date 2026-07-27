# Railway root Dockerfile — delegates to graphhopper/
# Railway builds from repo root, this Dockerfile includes everything.
FROM ghcr.io/graphhopper/graphhopper:11.0
COPY graphhopper/config.yml /data/config.yml
COPY graphhopper/start.sh /start.sh
RUN chmod +x /start.sh
ENV JAVA_OPTS="-Xms1g -Xmx4g -XX:+UseParallelGC"
ENTRYPOINT ["/start.sh"]
