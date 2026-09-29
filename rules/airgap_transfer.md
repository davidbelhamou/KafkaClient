# Air-gapped transfer rules

## 1. The setup

Internet side (GitHub): feature → PR → merge to the default branch → GitHub Actions
builds a patch zip.
The user carries it on USB and applies it with `git am` on the work side (target
branch: `## Transfer` in CLAUDE.md).

## 2. Hard rules

Breaking these breaks a transfer that can only be fixed by hand, inside, without Claude.

**R1 — Claude never touches the work side.** No remotes pointing at internal
hosts, no internal URLs or hostnames, never a claim to have verified anything
inside. When proposing a command, say which side it runs on.

**R2 — Never rewrite the default branch once a zip exists.** No amend, rebase,
force-push or reset on the default branch: those commits may already be applied
inside, and rewriting them makes the next transfer fail. Feature branches are
fine until they merge. The default branch must be protected in GitHub (set up
after the CI is built, `rules/transfer_ci.md`).

**R3 — Every commit must work on its own.** `git am` applies patches one at a
time and stops on the first failure; the halfway state must not be broken.
Mostly ordering: definition before caller, config option before the code that
reads it. Check it before the PR merges: replay the feature
branch onto the remote default branch, running a check after every commit:
- The check is the project's test command from CLAUDE.md, if tests exist.
- No tests yet → smoke check: the cheapest check that the project builds or loads
  (Python: compile every source file and import the package).
- Neither possible → skip, but say so in the PR description. Never skip silently.

**R4 — Commit messages must make sense with no internet.** No `#42`, no PR
links. Put the reasoning in the body.

**R5 — No submodules, no Git LFS.** Both need a fetch that cannot happen
inside. Vendor the code instead.

**R6 — Line endings stay LF.** A file stored with CRLF is silently changed by
`git am` on the work side, so the two sides differ. The kit's `.gitattributes`
(`eol=lf`, `*.patch` binary) prevents it; never remove or weaken it.

**R7 — No change lives in a merge commit.** PRs into the default branch use
"Rebase and merge" only. Merge commits and squash merging are disabled in the
repo settings, and linear history is required. (Squash is out because GitHub
appends `(#N)` to the squash commit subject, which breaks R4.) Never propose a
merge commit, and
never resolve conflicts inside a merge: rebase the source branch instead
(allowed by R2 until it merges). Reason: `format-patch` skips merge commits,
so a fix made in a merge is lost in transfer.

**R8 — Internet-only paths never reach the work side.** They are listed in
`## Transfer` in CLAUDE.md (`docs/` included), and the transfer CI leaves them
out. Code, tests and config must never read, import or link to them.

## 3. Checklist

- [ ] `## Transfer` missing or `CI: NOT BUILT`? → no transfer work until the CI is
      built (task 1: read `rules/transfer_ci.md` in full first).
- [ ] `Internet-only paths` changed? → update the CI in the same change.
- [ ] Feature PR about to merge? → R3 check done, or the skip is stated in the PR.
- [ ] User says a zip was applied and merged inside? → remind them to run
      `mark_applied`.

Human steps, zip contents and failure handling are in `docs/how_to_transfer.md`.
Read it when the user asks about a transfer or reports a transfer problem.
