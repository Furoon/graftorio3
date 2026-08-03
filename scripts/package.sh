#!/usr/bin/env bash
# Build a clean mod-portal zip for graftorio3.
# Allowlist-based: only files listed here ship. Anything else in the repo
# (Grafana dashboards, docker-compose, CI config, dev tooling) never enters
# the zip. A forgotten new file fails loudly instead of shipping silently.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NAME=$(python3 -c "import json;print(json.load(open('info.json'))['name'])")
VERSION=$(python3 -c "import json;print(json.load(open('info.json'))['version'])")
DIST="$REPO_ROOT/dist"
STAGE="$DIST/${NAME}_${VERSION}"

# The complete shipping manifest. Directories are copied recursively.
ALLOWLIST=(
  info.json
  changelog.txt
  LICENSE
  README.md
  thumbnail.png
  control.lua
  events.lua
  power.lua
  research.lua
  train.lua
  utils.lua
  yarm.lua
  circuit-network.lua
  settings.lua
  locale
  prometheus
)

rm -rf "$DIST"
mkdir -p "$STAGE"
for f in "${ALLOWLIST[@]}"; do
  if [ ! -e "$f" ]; then
    echo "FEHLER: Allowlist-Eintrag fehlt im Repo: $f" >&2
    exit 1
  fi
  cp -r "$f" "$STAGE/"
done

# Denylist self-check: fail if anything smells like dev infrastructure.
if find "$STAGE" \( -name 'docker-compose*' -o -name 'Justfile' -o -name '*.json' ! -name 'info.json' ! -name '.luarc.json' -o -path '*config*' -o -path '*grafana*' -o -name 'node_modules' \) | grep -q .; then
  echo "FEHLER: Verbotene Datei im Paket:" >&2
  find "$STAGE" \( -name 'docker-compose*' -o -name 'Justfile' -o -name '*.json' ! -name 'info.json' -o -path '*config*' -o -path '*grafana*' \) >&2
  exit 1
fi

( cd "$DIST" && zip -qr "${NAME}_${VERSION}.zip" "${NAME}_${VERSION}" )
rm -rf "$STAGE"
echo "OK: dist/${NAME}_${VERSION}.zip"
unzip -l "$DIST/${NAME}_${VERSION}.zip" | tail -3
