#!/usr/bin/env bash
# Upload a packaged zip to the Factorio mod portal.
# Uses the releases upload endpoint for existing mods and falls back to the
# publish endpoint for the very first release of a new mod.
# Requires: FACTORIO_API_KEY (factorio.com/create-api-key, scope "ModPortal: Upload Mods";
# first-time publish additionally needs the publish scope).
set -euo pipefail

NAME="$1"
ZIP="$2"
: "${FACTORIO_API_KEY:?FACTORIO_API_KEY ist nicht gesetzt}"

PORTAL="https://mods.factorio.com"

exists=$(curl -s -o /dev/null -w '%{http_code}' "$PORTAL/api/mods/$NAME")
if [ "$exists" = "200" ]; then
  echo "Mod existiert im Portal -> releases/init_upload"
  resp=$(curl -sf -X POST "$PORTAL/api/v2/mods/releases/init_upload" \
    -H "Authorization: Bearer $FACTORIO_API_KEY" \
    -F "mod=$NAME")
else
  echo "Mod existiert noch nicht -> init_publish (Erstveroeffentlichung)"
  resp=$(curl -sf -X POST "$PORTAL/api/v2/mods/init_publish" \
    -H "Authorization: Bearer $FACTORIO_API_KEY" \
    -F "mod=$NAME")
fi

upload_url=$(printf '%s' "$resp" | python3 -c "import json,sys;print(json.load(sys.stdin)['upload_url'])")
result=$(curl -sf -X POST "$upload_url" -F "file=@$ZIP")
echo "Portal-Antwort: $result"
