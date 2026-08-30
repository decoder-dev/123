#!/usr/bin/env bash
# Package an unsigned .app into a sideload-compatible .ipa (Apple unsigned recipe).
# Usage: package_unsigned_ipa.sh [--strip-extensions] <App.app> <output.ipa>
set -euo pipefail

strip_extensions=0
if [[ "${1:-}" == "--strip-extensions" ]]; then
  strip_extensions=1
  shift
fi

if [[ $# -ne 2 ]]; then
  echo "usage: $0 [--strip-extensions] <App.app> <output.ipa>" >&2
  exit 2
fi

app_path="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
mkdir -p "$(dirname "$2")"
output_path="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"

if [[ ! -d "$app_path" || "$app_path" != *.app ]]; then
  echo "invalid .app path: $app_path" >&2
  exit 3
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip (Info-ZIP) is required to package IPA" >&2
  exit 4
fi

work_dir="$(mntemp_dir="$(mktemp -d)"; echo "$mntemp_dir")"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$work_dir/Payload"
export COPYFILE_DISABLE=1
if command -v ditto >/dev/null 2>&1; then
  ditto "$app_path" "$work_dir/Payload/$(basename "$app_path")"
else
  cp -a "$app_path" "$work_dir/Payload/$(basename "$app_path")"
fi

if [[ "$strip_extensions" -eq 1 ]]; then
  rm -rf "$work_dir/Payload/"*.app/PlugIns
  rm -rf "$work_dir/Payload/"*.app/Extensions
  rm -rf "$work_dir/Payload/"*.app/Watch
fi

find "$work_dir/Payload" -name '.DS_Store' -delete 2>/dev/null || true
find "$work_dir/Payload" -name '._*' -delete 2>/dev/null || true

rm -f "$output_path"
(
  cd "$work_dir"
  zip -0 -y -q -r "$output_path" Payload
)

unzip -t "$output_path" >/dev/null

python3 - "$output_path" "$strip_extensions" <<'PY'
import sys
import zipfile

path = sys.argv[1]
strip_extensions = sys.argv[2] == "1"

with zipfile.ZipFile(path) as archive:
    if archive.testzip() is not None:
        raise SystemExit("IPA contains a corrupted ZIP entry")
    names = archive.namelist()
    if "Payload/" not in names:
        raise SystemExit("IPA missing Payload/ directory entry")
    if not all(name.startswith("Payload/") for name in names):
        raise SystemExit("IPA contains files outside Payload")
    app_dirs = [
        name for name in names
        if name.startswith("Payload/") and name.endswith(".app/") and name.count("/") == 2
    ]
    if len(app_dirs) != 1:
        raise SystemExit(f"expected one Payload/*.app/, found {app_dirs!r}")
    if not any(name.endswith(".app/Info.plist") for name in names):
        raise SystemExit("IPA missing Info.plist")
    if strip_extensions and any("/PlugIns/" in name for name in names):
        raise SystemExit("strip-extensions IPA still contains PlugIns/")
PY

echo "Created $output_path"
