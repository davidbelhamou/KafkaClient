#!/bin/sh
# Job "zip": patches/ + manifest.txt + SHA256SUMS into <project>-<short head>.zip.
# Spec: rules/transfer_ci.md.
# Env: ZIP_NAME, OUT_DIR (default: transfer; holds patches/ and manifest.txt).
# The zip is written next to OUT_DIR.
set -eu
: "${ZIP_NAME:?}"
out=${OUT_DIR:-transfer}
cd "$out"

if [ -z "$(ls patches 2> /dev/null)" ]; then
    echo "No changes to transfer."
    exit 0
fi

find patches manifest.txt -type f | sort | xargs sha256sum > SHA256SUMS
rm -f "../$ZIP_NAME"
zip -q -r -X "../$ZIP_NAME" patches manifest.txt SHA256SUMS
echo "Built $ZIP_NAME."
