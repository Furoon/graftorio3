#!/usr/bin/env bash
# Three-way release guard: git tag == info.json version == newest changelog entry.
# Prevents the version drift the celestialorb exporter shipped with
# (portal 0.2.2 vs repo 0.2.0).
set -euo pipefail
TAG="${1:?Usage: check_release.sh vX.Y.Z}"
TAG_VERSION="${TAG#v}"

INFO_VERSION=$(python3 -c "import json;print(json.load(open('info.json'))['version'])")
CHANGELOG_VERSION=$(grep -m1 '^Version:' changelog.txt | awk '{print $2}')

echo "tag=$TAG_VERSION info.json=$INFO_VERSION changelog=$CHANGELOG_VERSION"
if [ "$TAG_VERSION" != "$INFO_VERSION" ] || [ "$TAG_VERSION" != "$CHANGELOG_VERSION" ]; then
  echo "FEHLER: Versionen sind nicht synchron." >&2
  exit 1
fi
echo "OK: Versionen synchron"
