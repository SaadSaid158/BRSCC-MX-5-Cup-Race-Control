#!/usr/bin/env bash
# Builds dist/BRSCC-Race-Control-v<version>-install.zip (unzip into the AC root folder).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(sed -n 's/^VERSION *= *//p' src/brscc_race_control/manifest.ini | tr -d '\r')
OUT="dist/BRSCC-Race-Control-v${VERSION}-install.zip"
STAGE=$(mktemp -d)
mkdir -p "$STAGE/apps/lua" dist
cp -r src/brscc_race_control "$STAGE/apps/lua/"
rm -f "$STAGE/apps/lua/brscc_race_control/data/tracks/.gitkeep"
rm -f "$OUT"
python3 - "$STAGE" "$OUT" <<'PY'
import os, sys, zipfile
stage, out = sys.argv[1], os.path.abspath(sys.argv[2])
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(os.path.join(stage, "apps")):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, stage))
PY
rm -rf "$STAGE"
echo "$OUT"
