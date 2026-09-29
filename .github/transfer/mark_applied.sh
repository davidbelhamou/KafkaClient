#!/bin/sh
# Job "mark_applied": after a zip is applied and merged inside, tag its head
# landed/<head>, once the previous zip is known to have landed.
# Spec: rules/transfer_ci.md.
# Env: BASE_IN, HEAD_IN (from the zip's manifest.txt), NO_PUSH (tests only).
# Runs on a checkout of the default branch.
set -eu
. "$(dirname "$0")/lib.sh"
base=$(printf '%s' "${BASE_IN:?}" | tr -d ' \t\r\n')
head=$(printf '%s' "${HEAD_IN:?}" | tr -d ' \t\r\n')

is_full_hash "$head" || fail "T010 head must be the full 40-character hash from manifest.txt."
git cat-file -e "$head^{commit}" 2> /dev/null || fail "T011 head $head is not in this repository."
git rev-list --first-parent HEAD | grep -qx "$head" \
    || fail "T012 head $head is not on the default branch's first-parent line."

if [ -n "$(landed_tag_on "$head")" ]; then
    echo "head $head already carries a landed/ tag: nothing to do."
    exit 0
fi

if [ "$base" = none ]; then
    if has_landed_tags; then
        fail "T013 base: none is only valid before the first mark_applied. Use the base from this zip's manifest.txt."
    fi
else
    is_full_hash "$base" || fail "T014 base must be none or the full 40-character hash from manifest.txt."
    [ "$base" != "$head" ] || fail "T015 base and head are the same commit."
    git rev-list --first-parent "$head" | grep -qx "$base" \
        || fail "T015 base $base is not on the first-parent line before head $head."

    # The previous zip must have landed: walk back from base to a landed/ tag.
    # Every commit passed on the way must change only internet-only paths.
    c=$base
    while [ -z "$(landed_tag_on "$c")" ]; do
        # Compared with the first parent (merge commits included); the root
        # commit is compared with the empty tree.
        if git rev-parse -q --verify "$c^1" > /dev/null; then
            changed=$(git diff --name-only "$c^1" "$c" -- $(pathspecs))
        else
            changed=$(git diff-tree -r --root --no-commit-id --name-only "$c" -- $(pathspecs))
        fi
        [ -z "$changed" ] \
            || fail "T016 Commit $c was never marked applied: a zip was skipped. Apply the zip whose manifest range contains $c first, run mark_applied for it, then retry."
        c=$(git rev-parse -q --verify "$c^1") \
            || fail "T017 Reached the root commit without a landed/ tag: a zip was skipped. Apply the earliest zip not yet applied first."
    done
fi

git tag "landed/$head" "$head"
if [ -z "${NO_PUSH:-}" ]; then
    git push origin "refs/tags/landed/$head"
fi
echo "Tagged landed/$head."
