#!/usr/bin/env bash
# Export Apple Development certificate to base64 for GitHub secret BUILD_CERTIFICATE_BASE64.
# Usage: ./scripts/export-signing-certificate.sh ~/Downloads/certs.p12
set -euo pipefail
P12="${1:?Usage: export-signing-certificate.sh /path/to/certificate.p12}"
base64 < "$P12" | pbcopy 2>/dev/null || base64 < "$P12"
echo "Base64 copied to clipboard (or printed above). Paste into GitHub secret BUILD_CERTIFICATE_BASE64."
