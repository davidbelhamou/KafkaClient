# How to transfer code to the work network

Goal: get each merge from the internet-side GitHub repo onto the work network, one zip at a time.

Every merge to the default branch makes GitHub Actions build a zip of patches (it expires after 1 day).
You carry the zip in on USB, apply it on the work side, and merge it into the work target branch
through your work Git server's usual review (merge request or pull request).
Back on the internet side, you run `mark_applied` so the next zip knows where to start.

## 1. Internet side: get the zip

In GitHub, open Actions → the `transfer` run of the merge → Artifacts → download
`<project>-<hash>.zip`, and copy it to the USB. If the run has no zip artifact and says
"No changes to transfer.", there is nothing to carry.

## 2. Work side: apply the zip

`develop` is the work target branch here; `## Transfer` in CLAUDE.md names yours.

```bash
# unpack the zip next to the work repo
unzip <project>-<hash>.zip -d transfer

# check nothing got corrupted on the USB: every line must say OK
cd transfer && sha256sum -c SHA256SUMS && cd ..

# read the head hash and the number of patches
cat transfer/manifest.txt

# go to the work repo and start from the latest target branch
cd <work repo>
git fetch origin
git checkout -b transfer/<hash> origin/develop

# apply every patch in order, keeping authors, dates and messages
git am ../transfer/patches/*.patch

# push the branch, then open a merge/pull request into develop on the work Git server and merge it
git push -u origin transfer/<hash>
```

First transfer only: clone the empty work repo, skip the `git fetch` and the
`git checkout -b` lines, and after `git am` push straight to the target branch.
If several zips were made before the first `mark_applied` run, apply only the
newest: each one holds the whole history.

```bash
# first transfer: the patches become the whole history of develop
git push -u origin HEAD:develop
```

## 3. Internet side: mark it applied

Do this only after the transfer is merged on the work side. In GitHub, open
Actions → `transfer` → Run workflow, on the default branch. Fill in `base` and `head`
exactly as they appear in that zip's `manifest.txt`, then run it. If it fails, it
names the older zip you skipped: apply that one first, then run it again.

## When something goes wrong

```bash
# git am stopped on a patch: undo everything it applied, the branch is back as it was
git am --abort
```

Then tell Claude the patch number and the one error line. The fix is always a
new commit on the internet side and a new zip, never a change made by hand inside.

The zip expired before you carried it: in GitHub, open that `transfer` run and choose
"Re-run all jobs" to get a fresh zip. GitHub allows re-runs for 30 days after the run.
