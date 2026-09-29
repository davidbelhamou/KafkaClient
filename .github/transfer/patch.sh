#!/bin/sh
# Job "patch": one patch per commit of this push, internet-only paths left out,
# plus manifest.txt. Spec: rules/transfer_ci.md.
# Env: BEFORE (github.event.before), HEAD_SHA (github.sha), PROJECT (repo name),
#      OUT_DIR (default: transfer), GITHUB_OUTPUT (optional).
set -eu
. "$(dirname "$0")/lib.sh"
: "${BEFORE:?}" "${HEAD_SHA:?}" "${PROJECT:?}"
out=${OUT_DIR:-transfer}

emit() {
    if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1" >> "$GITHUB_OUTPUT"; fi
}

rm -rf "$out"
mkdir -p "$out/patches"

if [ -n "$(landed_tag_on "$HEAD_SHA")" ]; then
    echo "Head $HEAD_SHA already carries a landed/ tag: nothing to do."
    emit patches=0
    exit 0
fi

if has_landed_tags; then
    [ "$BEFORE" != "$ZEROS" ] || fail "T001 This run must come from a merge to the default branch."
    git merge-base --is-ancestor "$BEFORE" "$HEAD_SHA" \
        || fail "T002 Base $BEFORE is not an ancestor of head $HEAD_SHA: the default branch was rewritten (R2)."
    base=$BEFORE
    range="$BEFORE..$HEAD_SHA"
    root=
else
    # First transfer: the whole history, root commit included.
    base=none
    range=$HEAD_SHA
    root=--root
fi

[ "$(git rev-list --count "$range")" -gt 0 ] || fail "T003 No commits between base and head."

# Path-limited: commits touching only internet-only paths get no patch.
git format-patch $root -o "$out/patches" "$range" -- $(pathspecs) > /dev/null

count=$(find "$out/patches" -name '*.patch' | wc -l | tr -d ' ')
short=$(printf '%s' "$HEAD_SHA" | cut -c1-7)

cat > "$out/manifest.txt" <<MANIFEST
base: $base
head: $HEAD_SHA
patches: $count
project: $PROJECT
date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
MANIFEST

if [ "$count" -eq 0 ]; then
    echo "No changes to transfer."
else
    echo "$count patch(es), base $base, head $HEAD_SHA."
fi
emit "patches=$count"
emit "zip_name=$PROJECT-$short.zip"
