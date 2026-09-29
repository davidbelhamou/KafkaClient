# Air-gapped work environment
Code written here is carried by USB into an air-gapped network. Nothing comes
back: I can't paste code, logs, errors or docs from there.

## Errors from the gap
- Never ask me to paste output, tracebacks or logs. Ask for the smallest
  thing: yes/no → an error or exit code → one line → a few specific lines (say which).
- Accept my paraphrased error reports. Work from the source code; ask again
  only if the ambiguity blocks the fix.
- Make failures easy to name: every error the program prints or logs carries a
  short unique code (e.g. E017) plus a one-line hint. Codes are never renumbered
  or reused.

## Dependencies
- Python packages come from an internal Artifactory mirror on the work network, not from PyPI.
- Not sure a package or version is there? Ask me to check before using it.
