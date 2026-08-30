#!/usr/bin/env bash
# Strip signatures and entitlement sidecars that break ESign/Sideloadly/Feather resign.
# Usage: prepare_sideload_app.sh <App.app>
set -euo pipefail

app_path="${1:?usage: prepare_sideload_app.sh <App.app>}"

if [[ ! -d "$app_path" || "$app_path" != *.app ]]; then
  echo "invalid .app path: $app_path" >&2
  exit 2
fi

rm -rf "$app_path/_CodeSignature"
find "$app_path" -name '*.xcent' -delete 2>/dev/null || true
find "$app_path" -name 'embedded.mobileprovision' -delete 2>/dev/null || true
find "$app_path" -name '.DS_Store' -delete 2>/dev/null || true
find "$app_path" -name '._*' -delete 2>/dev/null || true

echo "Prepared $app_path for sideload packaging"
