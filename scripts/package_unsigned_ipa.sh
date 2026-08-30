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

work_dir="$(mktemp -d)"
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
    if not names:
        raise SystemExit("IPA is empty")
    if "Payload/" not in names:
        raise SystemExit(
            "IPA is missing explicit Payload/ directory entry "
            "(required by many sideload unzippers)"
        )
    if not all(name.startswith("Payload/") for name in names):
        raise SystemExit("IPA contains files outside Payload")
    junk = [
        name
        for name in names
        if name.startswith("__MACOSX")
        or "/__MACOSX/" in name
        or name.rsplit("/", 1)[-1].startswith("._")
    ]
    if junk:
        raise SystemExit(
            "IPA contains AppleDouble/junk entries: " + ", ".join(junk[:5])
        )
    app_dirs = [
        name
        for name in names
        if name.startswith("Payload/")
        and name.endswith(".app/")
        and name.count(".app/") == 1
        and name.count("/") == 2
    ]
    if len(app_dirs) != 1:
        raise SystemExit(
            "IPA must contain exactly one Payload/*.app/ directory entry, "
            f"found {app_dirs!r}"
        )
    if not any(name.endswith(".app/Info.plist") for name in names):
        raise SystemExit("IPA is missing application Info.plist")
    if any("/Watch/" in name for name in names):
        raise SystemExit(
            "IPA contains legacy Watch/ content; watchOS requires PlugIns/"
        )
    if strip_extensions:
        if any("/PlugIns/" in name for name in names):
            raise SystemExit("strip-extensions IPA still contains PlugIns/")
        if any("/Extensions/" in name for name in names):
            raise SystemExit("strip-extensions IPA still contains Extensions/")

    bad_attrs = []
    for info in archive.infolist():
        if info.filename.endswith("/"):
            continue
        mode = (info.external_attr >> 16) & 0xFFFF
        if mode and (mode & 0o170000) == 0:
            bad_attrs.append(info.filename)
    if bad_attrs:
        raise SystemExit(
            "IPA file entries missing Unix file-type bits: "
            + ", ".join(bad_attrs[:5])
        )
PY

echo "Created $output_path"
