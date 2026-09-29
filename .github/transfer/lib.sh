# Shared by the transfer scripts. POSIX sh: the jobs run in alpine (busybox).

# Internet-only paths: never transferred (R8). Keep in sync with "## Transfer"
# in CLAUDE.md.
INTERNET_ONLY="docs/ CLAUDE.md rules/ TASK_PLAN.md .github/ .claude/"

ZEROS=0000000000000000000000000000000000000000

# No globbing: pathspecs are passed unquoted so they split into words.
set -f

# Pathspecs selecting everything except the internet-only paths.
pathspecs() {
    printf '%s ' ':/'
    for p in $INTERNET_ONLY; do
        printf '%s ' ":(top,exclude)$p"
    done
}

fail() {
    echo "ERROR $*" >&2
    exit 1
}

has_landed_tags() {
    [ -n "$(git tag -l 'landed/*')" ]
}

landed_tag_on() {
    git tag --points-at "$1" -l 'landed/*'
}

is_full_hash() {
    printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$'
}
