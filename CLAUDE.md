# ClarityIngestClient

If `TASK_PLAN.md` exists, read it before doing anything else, including after `/clear`.

## How to work
One task at a time: finish a task from `TASK_PLAN.md`, report it, then wait for me
before starting the next. Only go on without stopping when I say so.

Hosted on: GitHub (internet side)
Repo URL: https://github.com/davidbelhamou/KafkaClient.git
Default branch: main
Python version: 3.12
Test command: <filled in by task 2>
Kit version: 15df384 (2026-09-30)

@rules/workflow.md
@rules/airgap.md
@rules/airgap_transfer.md

`rules/` comes from claude-kit: fix general rules there, then re-copy with
`new-project.ps1 -Update`. A rule needs a line in this file that is missing (after
an update, say)? Ask the user for its value, then add it.

This project is on GitHub, not GitLab: the local `rules/` and `docs/how_to_transfer.md`
are adapted for GitHub, so never run `new-project.ps1 -Update`, which would restore
the GitLab versions.

## Transfer
Before building or editing `.github/workflows/`, read `rules/transfer_ci.md` in full
and follow it exactly.
CI: NOT BUILT
Work-side target branch: develop
Internet-only paths: docs/, CLAUDE.md, rules/, TASK_PLAN.md, .github/, .claude/

## Project docs
Docs live in `docs/`, one line each below. Open one only when a task needs it.
Add a line whenever a doc is added. `docs/` is never transferred (R8).

- `docs/how_to_transfer.md` — how people carry and apply a patch zip.
- `docs/design.md` — package design: interface, delivery and retries, errors, open questions.
