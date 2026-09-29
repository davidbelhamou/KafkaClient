# Task Workflow

## 1. The plan file

`TASK_PLAN.md` at the repo root records what is done and what is next; it is the
only thing that survives `/clear`, a new session or a compaction.

If it doesn't exist, don't mention it or offer one. Create it only when the user
asks (a `## Bootstrap` section in `CLAUDE.md` counts as asking): understand the
project, draft the list in chat (one task = one branch = one merge, ordered so none
depends on a later one), and write the file only after a yes.

## 2. Format

```markdown
# Task Plan — <project name>

<One or two lines: what this project is.>

[X] 1. Project structure — feature/project_setup
[X] 2. Config loader — feature/config_loader
[] 3. Add login form — feature/login_form
[] 4. Write tests for the config loader
```

Bracket, number, title, and the branch name once the branch exists. Nothing else.

## 3. Keeping it current

A new task appears — the user names one, or you work out that one is needed. Write it
into the file straight away with `[]`, even if you're about to do it immediately. A task
that only exists in the conversation is gone at the next `/clear`. If you worked it
out yourself, say you added it.

Tasks keep their number and their place forever. Only the bracket changes, and a done
task's title shortens to a few words, because the file is read every session. Numbers
are never reused; a new task gets the next one and goes at the bottom.

## 4. Working a task to done

Branch off the default branch (named in `CLAUDE.md`): `type/snake_case_description`,
where type is one of `feature`, `fix`, `refactor`, `chore`, `docs`, `test`. Write the
branch name into the task line. Do the work.

Then, in order:

- **Update the docs.** If the change alters how something works or flows, update
  every file that describes it (CLAUDE.md, rules, diagrams, file tables, README,
  `docs/`) in the same change, and name them in the report. A decision made in chat
  with no task open becomes a task (§3).
- **Mark it in the task's own commit.** Flip `[]` to `[X]` in the same commit as the
  code, never a separate one, so the `[X]` reaches the default branch exactly when
  the code does.
- **Ask before anything leaves the machine.** When the work looks finished, ask
  whether to commit and push.
- **On yes:** commit, push the branch, open the pull request (PR) against the default
  branch at the repo URL in `CLAUDE.md` (missing either? ask once and write it in),
  and hand back the PR link.
- **The user says it's merged.** Verify it: fetch, then check that the branch's commit
  is an ancestor of the remote default branch. If it isn't, the merge may have
  rebased or squashed it, which changes the hashes: check instead that the PR shows
  as merged, or that every change on the branch is already in the remote default
  branch. Say plainly whether it landed. If it didn't, the `[X]` hasn't landed
  either — it's still sitting on the branch. Say that too.

A task is done when the commit carrying its `[X]` is merged — not when the code is
written or the PR is open.

## 5. Subagents

Subagents help with the current task; they never start another one.

- **Search and research:** use one when the work would fill this session with file
  contents (a broad search, many files, web research). Ask for the conclusion only.
- **Review:** for a large or risky change (the CI, anything touching R1–R8, many
  files), have one review it before you ask to commit, against this file and R1–R8
  (`rules/airgap_transfer.md`).
- **Limits:** subagents read and report. They don't commit, push, open PRs or edit
  `TASK_PLAN.md`, and they edit files only when the user asked for that.
- **Reports are input, not decisions:** check a finding before acting on it, and
  pass on to the user what matters.
- Run them in the background and keep working. Say when one starts and what it does.
