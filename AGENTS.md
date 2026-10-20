# AGENTS.md

This repository supports macOS and Omarchy through one Python 3.11+ installer,
`install.py`. GNU Stow is no longer a dependency. Sources live in `shared/`,
`linux/`, and `macos/`; explicit mappings in `install.py` define home destinations.

## Installer rules

- Preview is the default. Mutations require `--apply`.
- Keep macOS and Omarchy system dependencies separate. Default Linux deployment
  excludes desktop and terminal settings. The explicit `--setup` profile includes
  Omarchy 4 Foot and Hyprland settings. SASE and ActionBridge remain macOS-only.
- Preserve existing files with backups. Expand only directory links owned by
  this repository, with rollback; refuse unrelated directory symlinks.
- Deploy only versioned or nonignored sources. Never copy ignored runtime data,
  plugin checkouts, or private configuration into another home.
- Preserve plugin pins and existing local plugin work.
- Login-shell changes and GitHub authentication require their explicit flags.
- Keep one public installer. Update callers and docs when changing its interface.
- Ship `install-manifest.json` for ZIP downloads. After changing managed sources,
  run `python3 scripts/update-install-manifest.py`; archive deployment uses only
  this allowlist, never a recursive copy of local state.
- SSH restoration reads an explicit backup outside the repository. Copy regular
  files with private permissions, preserve conflicts, and keep credentials out of Git.

## Validation

Run `python3 scripts/check-install.py`, `python3 scripts/check-omarchy-setup.py`,
`python3 scripts/update-install-manifest.py --check`, and `git diff --check`.
The tests use disposable targets and mocked package-manager calls. Previewing
macOS on Linux does not validate real Homebrew installs or Mac application
startup. Exercise the real selected Neovim profile when changing its setup.

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
