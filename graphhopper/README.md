# GraphHopper Router — AsfaltoClub
# Railway deploy config
# ============================================================
# Uses the official ghcr.io/graphhopper/graphhopper image directly.
# OSM data and config are mounted via environment and startup.
#
# Railway config:
#   Image: ghcr.io/graphhopper/graphhopper:11.0
#   Root Directory: graphhopper
#   Start Command: (see start.sh)

# No build needed — Railway uses the image directly.
# The start.sh entrypoint handles:
#   1. Download OSM data if not cached
#   2. Start GraphHopper with motorcycle profile
