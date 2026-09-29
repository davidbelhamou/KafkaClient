# Transfer CI spec (GitHub Actions)

The transfer method for this project. Build exactly this, as one GitHub Actions
workflow in `.github/workflows/transfer.yml`. The job logic lives in POSIX `sh`
scripts in `.github/transfer/` (`patch.sh`, `zip.sh`, `mark_applied.sh`, and
`lib.sh`, which holds the internet-only paths), so it can be tested locally.
Other workflows (tests, for example) live in their own files; they never change
this one. Every merge to the default
branch produces one zip.

(Local override: the kit's version of this spec targets GitLab CI. This one is the
GitHub translation. See `CLAUDE.md`.)

## Before building

Show the user the `Internet-only paths` line from `## Transfer` in `CLAUDE.md`
and ask if it is right. Write the confirmed list back there, and build it into
the workflow.

## When it runs

- Triggers: `push` to the default branch, and `workflow_dispatch` (for
  `mark_applied` only). No other trigger.
- Jobs `patch` and `zip` run only when the event is `push`. Job `mark_applied`
  runs only when the event is `workflow_dispatch` and the ref is the default
  branch. Re-running jobs of an existing run is fine: a re-run keeps that run's
  event, so it keeps its base.
- `patch` and `zip` do nothing if `github.sha` already carries a `landed/` tag.
  `mark_applied` ends as a successful no-op if its `head` input already carries
  one.
- Job names: `patch`, `zip` (needs `patch`), `mark_applied`.
- Every job runs on `ubuntu-latest` in the container `alpine:3.20`. Its first step
  installs git and zip with `apk`, before checkout: without git in the container,
  `actions/checkout` silently downloads a tarball with no `.git`. After checkout,
  fail if `.git` is missing, and mark the workspace as a git `safe.directory`.
- Every job checks out the full history with all tags (`actions/checkout@v7` with
  `fetch-depth: 0` and `fetch-tags: true`). The default is a shallow clone, which
  would break the patches and the tag lookup.
- Permissions: `contents: read` for the workflow, `contents: write` only for
  `mark_applied`.

## Job 1 — `patch`

- Base = `github.event.before`, the commit the default branch pointed at before
  this push.
- First transfer (no `landed/` tag exists anywhere in the repo): there is no
  base. The patches start at the root commit, root included, and the manifest
  says `base: none`. The zip is applied on an empty work repo. Until the first
  `mark_applied` run, every zip is a first transfer: the user applies only the
  newest zip and runs `mark_applied` with that zip's manifest.
- Otherwise, a base of forty zeros means there is no previous commit: fail with
  "This run must come from a merge to the default branch."
- Produce one patch file per commit from base (excluded) to head, in order,
  keeping author, author date and message. `git am` recreates them with new
  hashes (the committer and commit date change). Use git's default patch names
  (`0001-<subject>.patch`) in a folder `patches/`.
- Leave every internet-only path out of the patches. A commit left with no change
  gets no patch; never produce an empty patch. (Done with a path-limited
  `format-patch`: pathspec `:/` plus `:(top,exclude)<path>` per internet-only path.)
- Produce `manifest.txt`, one `key: value` per line: `base` (full hash or
  `none`), `head` (full hash), `patches` (count), `project` (GitHub repository
  name, without the owner), `date` (UTC, ISO 8601).
- Fail if there are no commits between base and head.
- No patch left (only internet-only paths changed): print "No changes to
  transfer." and succeed. Job 2 sees that `patches/` is empty, prints the same
  line and succeeds without doing anything.
- Pass `patches/` and `manifest.txt` to job 2 as an artifact (retention 1 day).

## Job 2 — `zip`

- Take `patches/` and `manifest.txt` from job 1.
- Add `SHA256SUMS`: one line per file in the zip except itself, in the format
  `sha256sum -c` reads, with paths relative to the zip root. It catches USB
  corruption.
- The zip root holds `patches/`, `manifest.txt` and `SHA256SUMS`, nothing else.
- Name it `<project>-<short head hash>.zip` (7 characters), where `<project>` is
  the GitHub repository name.
- Upload it with `actions/upload-artifact@v7` and `archive: false`, retention 1
  day. The artifact is the zip file itself, named after it, so the download is
  the zip with no second wrapper. No apply instructions inside: the runbook is
  `docs/how_to_transfer.md`.

## Job 3 — `mark_applied`

GitHub has no manual job inside a push run, so this is a manual run of the same
workflow (Actions → workflow → Run workflow) on the default branch.

- Inputs: `base` and `head`, copied from the `manifest.txt` of the zip that was
  applied. `base` is a full hash or `none`.
- Validate the inputs: `head` is a full hash on the default branch's first-parent
  line. `base` is `none` or a full hash on the first-parent line strictly before
  `head`. `base: none` is accepted only when no `landed/` tag exists yet. Fail with
  a clear message otherwise.
- Before tagging, check that the previous zip landed (skipped when `base` is
  `none`). Start at the base commit itself and walk back along the default
  branch, first parent only, until a commit carries a `landed/` tag; if the base
  carries one, the check passes at once. Every commit passed on the way, base
  included, must change only internet-only paths (compared with its first
  parent). If one doesn't, fail with a message naming that commit: a zip was
  skipped, and the user must apply the zip whose manifest range contains it
  first. Reaching the root with no tag also fails, with the same advice.
- Then create a lightweight tag `landed/<full head hash>` on the head commit and
  push it with the workflow's `GITHUB_TOKEN` (`contents: write`). A tag pushed with
  `GITHUB_TOKEN` does not trigger another run.

## Token

No personal token is needed: `mark_applied` pushes the tag with the built-in
`GITHUB_TOKEN`. Two repo settings can block it:

1. The job requests `contents: write` itself, which normally overrides the default
   in Settings → Actions → General → Workflow permissions. It matters only if the
   organization blocks that override: then allow "Read and write" there.
2. Only if a tag ruleset covers `landed/*`: add GitHub Actions to its bypass list.

Claude never sees a token value and never writes one anywhere.

## After building

1. Update `## Transfer` in `CLAUDE.md`: `CI: built (.github/workflows/transfer.yml)`.
2. Walk the user through the two token settings above once.
3. Have the user set Settings → General → Pull Requests: allow "Rebase merging"
   only, and turn off "Allow merge commits" and "Allow squash merging" (R4, R7).
4. Have the user protect the default branch (Settings → Branches, or Rules →
   Rulesets): require a pull request before merging, require linear history,
   block force pushes and deletion, and no bypass for direct pushes. Every push to
   the default branch makes a zip, so changes must come only through PRs (R2).
   This comes after the bootstrap push, which goes straight to the default branch.
   On a private repo, branch protection needs a paid plan (Pro, Team or
   Enterprise). Without it, say so plainly: R2 then depends on discipline alone.
5. Remind them the first `mark_applied` run happens after the first zip is
   applied inside.
