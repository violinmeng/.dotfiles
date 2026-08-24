# AGENTS.md

## Cursor Cloud specific instructions

This is a **macOS dotfiles** repository managed with GNU Stow. There is no
compiled application, no automated test suite, and no package manager manifest.
The two runnable artifacts are the `install.sh` bootstrap and the
`.secret-audit.py` git secret scanner.

Cloud Agent VMs run **Linux**, so keep the following caveats in mind:

- `install.sh` intentionally refuses to run on anything other than macOS: its
  `validate_environment` guard exits with `This installer currently supports
  macOS only.`. This also applies to `./install.sh --dry-run`, since the guard
  runs before any dry-run logic. Only `./install.sh --help` (and argument
  parsing) works on Linux. This is expected behavior, not a bug — do not "fix"
  it to make it run on Linux.
- The Homebrew Brewfile, `mise` runtimes, and full stow deployment target a real
  macOS `$HOME` and cannot be exercised end to end here. To validate a stow
  package structure on Linux, use a throwaway target, e.g.
  `stow --simulate --verbose=2 --dir /workspace --target "$(mktemp -d)" git tmux`.

### Linting

- Shell (`install.sh`): `bash -n install.sh` for syntax, then
  `shellcheck install.sh`. The current script emits only info/warning findings
  (`SC2016` single-quote literals used deliberately for profile-line comparison,
  and one `SC2155`); these are pre-existing and not errors.
- Python (`.secret-audit.py`): `python3 -m py_compile .secret-audit.py`. The
  script is dependency-free and targets Python 3 (system `python3` is fine).

### Running the secret audit (the runnable app on Linux)

- Normal usage compares `HEAD` against the branch's upstream:
  `./.secret-audit.py` (see `README.md` for exit codes and flags).
- On Cloud Agent VMs the authenticated `origin` remote embeds a token in its
  push URL, so the audit reports a `credential-in-push-url` hard finding and
  exits `2` even on a clean tree. This is an environment artifact of the cloud
  git remote, not a repository problem.
- To exercise the full scanner against real history, pass an explicit base, e.g.
  `./.secret-audit.py --base "$(git rev-list --max-parents=0 HEAD)" --head HEAD`.

### Before pushing

Follow `README.md`'s secret-audit guidance (`git fetch origin` then
`./.secret-audit.py`). Note the `credential-in-push-url` caveat above when
interpreting results from within a Cloud Agent VM.
