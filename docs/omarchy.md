# Restore your environment on Omarchy

Use this guide after installing Omarchy 4 and completing its first desktop login.
The complete setup supports aarch64 and x86_64. It installs software and applies
configuration; you sign in to your accounts afterward.

## Download the project and run setup

Download the project ZIP from GitHub and extract it, or clone the repository.
Put the project in a permanent directory such as `~/.dotfiles` before running
setup. Keep that directory: managed configuration links point into it.
Python 3.11 or newer is required; Git metadata is not required for ZIP downloads.

Preview the complete setup:

```sh
cd ~/.dotfiles
python3 install.py --setup
```

Apply it from a terminal where you can enter your sudo password:

```sh
python3 install.py --setup --apply --set-default-shell
```

The installer completes these steps:

- Install Zsh, Git and Git LFS, fzf helpers, tmux, Neovim, Yazi and its dependencies,
  mise, and the screenshot and AppImage dependencies.
- Install ChatGPT through the [official Arch installer](https://learn.chatgpt.com/docs/linux/linux-app),
  Zed through its [official Linux installer](https://zed.dev/docs/linux), and
  [WeChat's native Linux AppImage](https://linux.weixin.qq.com/) for your architecture.
- Deploy shared agent skills, Zsh, Git, fzf, tmux, Kvim, Yazi, Pi, Zed, and the Linux mise configuration.
- Install the runtimes declared in `linux/mise/config.toml`, including Codex CLI,
  GitHub CLI, Node, Bun, Java, Ruby, Rust, and the editor tools.
- Install Pi at its pinned version, its configured extensions, and the Zsh,
  tmux, and Neovim plugins. Runtime installation precedes plugin builds.
- Restore the saved Foot configuration and Hyprland Command-key shortcuts.
  Check Foot configuration, then reload and check Hyprland when a desktop session is active.
- Change the login shell only when you include `--set-default-shell`.

Before reporting success, setup checks that the selected commands are on PATH,
runs the Codex, Pi, and Zed version commands, and checks ChatGPT's package files.

**First-time ChatGPT installation runs a full Arch system upgrade.** The official
installer verifies the published signing key, package, and repository signatures
before configuring the signed OpenAI repository. It keeps pacman's confirmation
prompt. Review that prompt in your terminal. Already-installed ChatGPT and Zed
are kept; an existing WeChat AppImage is kept after its architecture is checked.

Normal configuration deployment still excludes desktop settings. `--setup`
explicitly selects the complete environment and cannot be combined with
`--packages`. SASE, ActionBridge, and macOS application paths stay off Linux.

If a download or plugin build fails, fix the reported problem and run the same
setup command again. Correct configuration links and installed apps are reused.
Existing plugin checkouts are preserved; a different upstream or pin stops the
installer instead of resetting local work. Missing or incomplete system package
databases stop installation with instructions to update in your own terminal.

## Restore SSH keys from an external backup

Keep your `.ssh` backup outside this repository. Copy that backup directory into
the new VM using your existing transfer method. A backup from the old Omarchy
home and an export from your Mac use the same restore command.

To restore keys along with the complete setup:

```sh
python3 install.py --setup --apply --set-default-shell \
  --restore-ssh /path/to/ssh-backup
```

Pass the directory containing `id_ed25519`, its public key, `config`, or your
other SSH files, rather than the parent home directory. The backup must contain
regular files and real directories. Export any symlinked keys as regular files
first. Agent and connection sockets are skipped.

To restore only SSH files, preview and apply the standalone utility:

```sh
python3 scripts/restore_ssh.py /path/to/ssh-backup
python3 scripts/restore_ssh.py /path/to/ssh-backup --apply
```

The utility copies file contents, preserves unrelated destination keys, and
backs up conflicting files under
`~/.local/state/dotfiles/backups/<timestamp>/ssh/`. SSH directories use mode
`0700`, private keys and configuration use `0600`, and public keys and
`known_hosts` use `0644`. Identical files are kept on repeat runs. A copy failure
restores the files changed by that invocation. Key contents are never printed.

Encrypted keys keep their passphrases. SSH configuration is copied as written;
review any Mac-only `IdentityAgent`, `IdentityFile`, or `Include` paths after
restoring a Mac backup. The utility does not start an agent, run `ssh-add`,
connect to a server, or start an account login. It refuses backups and restored
keys inside this repository.

## Sign in after setup

Open a new terminal, then complete the accounts you use:

- Run `codex login` for Codex CLI.
- Start `pi` and use `/login` for its provider account.
- Run `gh auth login` for GitHub CLI.
- Open ChatGPT from the application menu and sign in.
- Open WeChat from the application menu and scan its login QR code.
- Open Zed and sign in if you use its account features.

Account tokens, SSH keys, WeChat chats, Pi sessions, private MCP configuration,
and local authorization files are not supplied by Git or the project ZIP.
Existing private files remain in place. Restore personal data from your own
backup separately.

## Restore selected configuration instead

The default installer remains a configuration-only preview:

```sh
python3 install.py
```

Its default Linux selection is `agents,zsh,git,fzf,tmux,kvim,yazi,mise`.
For a smaller installation, select packages and installation steps explicitly:

```sh
python3 install.py --apply --packages zsh,tmux,kvim,mise \
  --install-packages --install-runtimes --install-plugins
```

Existing configuration files move to
`~/.local/state/dotfiles/backups/<timestamp>/` before replacement. Skill
`SKILL.md` manifests are regular copies for Codex discovery; other managed files
are links. The installer expands directory links owned by this repository and
refuses unrelated parent-directory symlinks. A failure during file deployment
rolls back that invocation's file changes.

Kvim requires Neovim 0.12+, Tree-sitter CLI 0.26.1+, Node, and the C build tools.
The installer checks its headless startup and native FZF extension. Do not set
`NVIM_APPNAME`; both `nvim` and `knvim` use `~/.config/nvim`.

## Use the restored terminal and shortcuts

The complete profile restores `linux/foot/foot.ini`, `linux/hypr/bindings.lua`,
and `linux/hypr/command-paste.py`. Existing personal overrides are backed up;
other files in `~/.config/hypr` stay in place. Foot starts `/usr/bin/zsh` without
waiting for the current desktop session's inherited `SHELL` to change.

| Shortcut | Action |
| --- | --- |
| Command/Super + Shift + A | Select a screenshot region and annotate it in Satty |
| Command/Super + C | Use Omarchy's universal copy binding |
| Command/Super + S | Save in Satty; toggle the scratchpad elsewhere |
| Command/Super + V | Paste text or images using the clipboard helper |

Pi also accepts Ctrl+V and Alt+V for image paste. Start a new Pi session after
restoring its keybindings. Existing terminals and applications are not restarted.

## Validate installer changes

```sh
python3 scripts/update-install-manifest.py --check
python3 scripts/check-install.py
python3 scripts/check-omarchy-setup.py
git diff --check
```

After adding, moving, or removing managed source files in a Git checkout, run
`python3 scripts/update-install-manifest.py` and include the updated
`install-manifest.json` in the change. ZIP deployment uses that allowlist;
files added locally after extraction are excluded.

The checks use disposable homes, real ZIP extraction and file deployment, and
mocked software installers. They cover repeat runs, interrupted downloads,
SSH permissions, conflict backups, sockets, symlinks, and recovery after a copy
failure. They do not install the full toolchain or prove graphical application
startup in a fresh VM. Clipboard shortcuts require a running Wayland session.
