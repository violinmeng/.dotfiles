# Dotfiles for macOS and Omarchy

Personal shell, terminal, editor, and coding-agent configuration. Sources are
grouped by platform and application. One Python installer owns file links,
backups, dependencies, and plugin installation on both platforms.

```text
shared/          Cross-platform shell, editors, and agents
linux/           Linux runtime declaration and optional Hyprland shortcuts
macos/           Homebrew, runtimes, terminals, and AeroSpace
scripts/         Validation and migration tools
docs/            Setup guides
install.py       Public installer and source-to-home mappings
```

Source paths do not mirror your home directory. For example,
`shared/nvim/init.lua` links to `~/.config/nvim/init.lua`, and
`shared/zsh/zshrc` links to `~/.zshrc`.

## Requirements

Install Python 3.11 or newer and Git before running the installer. A fresh Mac
also needs the Xcode Command Line Tools for Git and native plugin builds:

```sh
xcode-select --install
```

The installer does not need GNU Stow. If you previously installed that package,
you can remove it independently; removing the program does not remove existing
configuration links. Repository-owned directory links from earlier deployments
are expanded safely during application. Unrelated directory links are refused.

After pulling this layout change into an existing installation, preview the
repair of old repository links with `python3 scripts/restructure.py`. Add
`--apply` to repair them. This migration only updates existing links that point
to moved sources; it does not install additional configuration or software.
Preview and apply normal deployment through `install.py` afterward.

## Preview the setup

```sh
cd ~/.dotfiles
./install.py --dry-run
```

Preview is the default, even without `--dry-run`. No software, links, login
changes, or authentication flows run until you add `--apply`.

The default Linux selection is `agents,zsh,git,fzf,tmux,nvim,kvim,yazi,mise`.
It leaves the Omarchy desktop and terminal settings unchanged. See the
[Omarchy setup guide](docs/omarchy.md).

The optional [Omarchy shortcut configuration](docs/omarchy.md#screenshot-and-command-key-shortcuts)
is saved under `linux/hypr/`. It is excluded from the installer.
The optional [Foot/Zsh startup configuration](docs/omarchy.md#start-new-terminals-in-zsh)
is saved under `linux/foot/` and is also restored manually.
[WeChat for Linux](docs/omarchy.md#optional-wechat-desktop-app) is installed
separately; the guide records the official ARM64 AppImage setup.

The default Mac selection is
`agents,zsh,alacritty,git,fzf,tmux,nvim,kvim,mise,herdr,pi,zed`.
`aerospace`, `ghostty`, `emacs`, `vim`, and `yazi` can also be selected.
To preview the Mac branch from Linux:

```sh
./install.py --platform macos --dry-run --install-packages
```

Applying a different platform is refused. The macOS package path is covered by
preview and command-routing tests; it has not been executed on a Mac here.

## Install the selected configuration

```sh
./install.py --apply --packages zsh,tmux,nvim,kvim --install-packages --install-plugins
```

On macOS, `--install-packages` installs Homebrew if missing, applies
`macos/Brewfile` without upgrading existing dependencies, and installs selected optional
application dependencies. Homebrew may request system authentication. On
Omarchy, it calls `omarchy pkg add` after checking the local package databases.
Run the command in a terminal where you can enter a password if required.

Use `--apply` without installation flags to deploy configuration only. Existing
files are backed up under `~/.local/state/dotfiles/backups/<timestamp>/`.
Correct links are left alone on repeat runs. A failure while creating links
restores the files and directory links changed by that invocation. Software
installation is separate from that file rollback.

For a normal file restore, remove its new symlink and move the corresponding
backup to its original path. Expanded repository directory links are recorded
in `directory-links.json`, with the original link stored in `.directory-links/`.
Expansion keeps unrelated contents reachable through links to their old source.

## Choose software installation steps

| Option | Operation |
| --- | --- |
| `--install-packages` | Homebrew Bundle or Omarchy system dependencies |
| `--install-plugins` | Configured Zsh, tmux, selected Neovim, and Pi plugins |
| `--install-runtimes` | Trust and install the selected mise declaration |
| `--install-haskell` | GHCup, GHC, Cabal, and HLS |
| `--github-login` | Start the GitHub CLI web login flow |
| `--set-default-shell` | Use `chsh` to make Zsh the login shell |

Every option still requires `--apply` to make changes. Plugin installation
requires Git. Kvim requires Neovim 0.12+, Tree-sitter CLI 0.26.1+, and Node for parser
generation. `--install-packages` installs the CLI through Homebrew or Omarchy.
Remove an older npm CLI if it shadows the system binary.
Install runtimes before Kvim plugins on a fresh machine:

```sh
# The mise package selects the current platform's declaration.
./install.py --apply --packages zsh,mise --install-runtimes
./install.py --apply --packages zsh,tmux,nvim,kvim --install-packages --install-plugins
```

On Mac, `--install-packages` provisions mise through Homebrew. On Omarchy, install
mise for the machine's architecture first. The `mise` package selects
`linux/mise/config.toml` or `macos/mise/config.toml` for the current platform.

Configuration-only deployment does not install application executables.
For a selected `pi` package, `--install-packages` installs Pi 1.3.0 with npm and
`--install-plugins` installs and verifies its pinned extensions. Herdr's
application installation remains separate.
Downloads use the configured upstreams for plugins and the official installers
for Homebrew and GHCup. Existing plugin checkouts are reused without resetting
local work. Version or upstream conflicts stop installation.

## Install Pi with your configuration

```sh
./install.py --apply --packages pi --install-packages --install-plugins
```

Node/npm must be available, normally through mise. Pi is installed under
`~/.local`; its settings, themes, extensions, models, and MCP example are
linked from this repository. Existing settings are backed up. Active MCP server
configuration, credentials, and sessions remain local and are excluded from
deployment.

The `packages` array in `shared/pi/settings.json` is authoritative. Exact npm
versions, Git commits, and resource filters are preserved. Installation uses
Pi's package manager without rewriting those settings. Verification checks that
all declared packages exist, the configured theme and extensions load, the next
startup needs no downloads, and a real RPC session responds without sending a
prompt or contacting a model provider.

The npm launcher points to Pi's modular CLI. The bundled CLI cannot resolve an
SDK import used by the pinned Vim integration. MCP uses Pi's built-in support,
not `pi-mcp-adapter`. Some pinned third-party packages still emit host dependency
metadata warnings; those are upstream package declarations and are not patched
locally.

New Pi sessions select the newest general-purpose OpenAI GPT release in Pi's
available model catalog, including the `-sol` family, without a fixed model ID.
Explicit CLI model choices and resumed conversations keep their selected model.
New releases become selectable when Pi's catalog includes them; update Pi when
its bundled catalog is out of date. ChatGPT requests use HTTP streaming (`sse`)
so server errors remain readable. The pinned server-compaction extension is
installed but disabled because it sends `store=true` for the unified `openai`
provider, which ChatGPT subscription requests reject. Pi's built-in compaction
remains enabled.

Run `node scripts/check-pi-latest-model.mjs` with Node 22.18+ to check model
ordering, or add `--live` to verify a real reply using your existing login.

Start `pi` in your project and use `/login` to connect a provider. Authentication
is not part of installation.

### Native MCP servers

Pi 1.3.0 includes `/mcp`, `pi mcp`, and the `codemode` / `tool_search` tools.
The built-in MCP, codemode, and tool-search extensions stay enabled; no separate
MCP package is installed. Servers default to `codemode` exposure, which activates
codemode when a server connects. Choose `deferred` or `direct` exposure with
`pi mcp add --exposure` or `/mcp` if desired.

Active server definitions live in the **machine-local** `~/.pi/agent/mcp.json`.
The installer deploys only `mcp.example.json` and never replaces the active file.
For example, with Figma's desktop MCP server running:

```sh
pi mcp add figma --url http://127.0.0.1:3845/mcp --exposure codemode
pi mcp list
```

Use `/mcp` to inspect or reconnect servers, or sign in with `pi mcp login <name>`.
Native OAuth tokens live in `~/.pi/agent/mcp-auth.json`; keep that file and MCP
logs out of Git. Older adapter credentials in `mcp-oauth/` are not automatically
converted; OAuth servers may need a new sign-in. Do not delete the old directory
until the replacement connection works.

When migrating from `pi-mcp-adapter`, copy the effective imported server
definitions into the local native file before removing the adapter. If the old
`mcp.json` is a dotfiles symlink, back it up and replace the link with a regular
file first; never write private imported values through that link. Native MCP
does **not** read the adapter's `imports` list or automatically follow later
Cursor/Codex configuration changes. Preserve private `env` and `headers` locally,
convert `disabled: true` to `enabled: false`, and convert `requestTimeoutMs` to
`timeout` in seconds. Remove transportless disabled placeholders rather than
enabling them. Remove `-builtin:mcp` and adapter-specific tool-display overrides.
Restart Pi after migration; subsequent native config edits can use `/reload`.

## Configuration packages

| Package | Configuration |
| --- | --- |
| `zsh`, `fzf` | Shell environment, custom theme, and fuzzy-finder helpers |
| `git`, `tmux` | Git identity/settings and terminal multiplexer |
| `nvim`, `kvim`, `vim`, `emacs` | Independent editor profiles |
| `mise` | Platform-specific global runtime declaration |
| `alacritty`, `ghostty`, `aerospace` | Optional macOS terminal and window-manager settings |
| `yazi` | File manager, keymaps, and themes |
| `zed`, `pi`, `herdr` | Editor and coding-agent settings |
| `agents` | Shared global agent skills and installation metadata under `~/.agents` |

`nvim` selects `~/.config/nvim`. The `knvim` alias selects `~/.config/kvim`.
They use separate configuration, plugins, and runtime data. `macos/terminal-themes`
contains manually imported Mac Terminal themes and is not deployed by the installer.

The installer selects only versioned or nonignored source files using Git.
Ignored credentials, plugin checkouts, and generated runtime state are excluded.
Keep private machine settings in local override files.

## Validate changes

```sh
python3 scripts/check-install.py
```

This runs disposable deployments, backup and rollback checks, repeat runs,
repository-directory-link migration, ignored-file exclusion, platform previews,
and mocked package-manager routing. Neovim plugin installation also runs a real
headless startup check, including native FZF and Kvim parser loading.

## Neovim

The Neovim configuration lives under `shared/nvim` and is organized into:

- `lua/config` — options, keymaps, and autocommands
- `lua/core` — package management, LSP setup, and shared infrastructure
- `lua/plugins` — completion, linting, Treesitter, Telescope, Trouble, Which Key, Mason, and colorschemes
- `lsp` — language-server-specific configuration

Plugins are managed through Neovim's native package mechanism, with versions recorded in `nvim-pack-lock.json`.

## Emacs

The `emacs` package keeps the canonical configuration under `~/.config/emacs`, including `init.el`, Custom settings, and the package bootstrap helpers in `emacs.rc`. Because Emacs prefers an existing `~/.emacs.d`, a small compatibility loader at `~/.emacs.d/init.el` forwards startup to the XDG configuration while existing ELPA packages and runtime state remain in `~/.emacs.d`. The previous configuration is retained as `~/.config/emacs/init.el.backup`.

## AeroSpace workspace memory

Applications installed under `/Applications` restore their last recorded workspace
when their first managed window opens. Without a saved workspace, the existing
bundle overrides (Feishu → `1`, Cursor → `U`) and first-ASCII-letter rule apply.
Later windows from the same process stay where they opened.

The routing helper records focus changes and moves made with the configured
workspace/monitor shortcuts. If an app has windows in multiple workspaces, a move
takes priority; otherwise the last focused window determines the saved workspace.
New windows are registered only after routing, so their initial position cannot
overwrite the saved destination. Existing windows are registered at AeroSpace
startup without replacing saved destinations.

State is stored outside Git in
`~/Library/Application Support/AeroSpace/app-workspaces.json`. The helper requires
Python 3 and uses file locking and atomic writes. To record moves made through an
external CLI that do not change focus, run:

```sh
~/.config/aerospace/route-window.sh --remember-workspaces
```

To reset remembered workspaces, remove that JSON file. Run the regression tests:

```sh
python3 -m unittest discover -s tests -p 'test_aerospace*.py'
```

## Shared agent skills

The `agents` package keeps global skills and `.skill-lock.json` under
`shared/agents`. It is included in both platform defaults. Preview or apply it
separately with the public installer:

```sh
./install.py --dry-run --packages agents
./install.py --apply --packages agents
```

The installer links individual files into `~/.agents`, backs up conflicting
files, and preserves unrelated local skills. Updates to linked skill files are
visible in the dotfiles working tree; review newly added files before tracking
them. GNU Stow is not required.

Pi discovers `~/.agents/skills` automatically. Other compatible agents can use
this shared location or their existing links to it. The included
[`show-me`](https://github.com/humanlayer/skills/tree/main/plugins/show-me/skills/show-me)
skill explains code visually. In Pi, invoke it with `/skill:show-me` after
restarting Pi to discover newly installed skills.

Keep credentials and local runtime state out of the package, and review
third-party skills before use.

## Pi and Zed

The `pi` package includes coding-agent configuration under `~/.pi/agent`, including:

- custom TypeScript extensions
- model configuration and a credential-free MCP example
- keybindings
- themes
- tool-display and context-management settings

The `zed` package configures Zed to work with Pi through the Agent Client Protocol (ACP). See `docs/pi-zed-acp-setup.svg` for an overview of the setup.

Generated Pi runtime state stays inside the configuration package but is excluded from Git where appropriate.

## Additional macOS setup

Disable the press-and-hold character picker so holding a key repeats it:

```sh
defaults write -g ApplePressAndHoldEnabled -bool false
```

Useful desktop applications include:

- [Google Chrome](https://www.google.com/chrome/)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Pearcleaner](https://github.com/alienator88/Pearcleaner)
- [Easydict](https://github.com/tisfeng/Easydict)

For Visual Studio Code, use the command palette and run **Shell Command: Install 'code' command in PATH** after installation.

## Secret audit before pushing

The root `.secret-audit.py` script performs a dependency-free audit of the committed Git objects that the next push would introduce. Run it after refreshing the remote-tracking branch:

```sh
git fetch origin
./.secret-audit.py
```

The current branch's upstream is used as the base automatically. Override either side when needed:

```sh
./.secret-audit.py --base origin/main
./.secret-audit.py --base origin/main --head feature-branch
./.secret-audit.py --fail-on-privacy
```

### How the audit works

1. The script resolves the upstream base and selected head revision.
2. `git rev-list --objects <head> ^<base>` identifies every Git object reachable from the head but not from the base.
3. Every unique outgoing text blob is scanned, including blobs introduced in an intermediate commit and removed by a later commit. Scanning only the final diff would miss that case because Git pushes the complete commit history.
4. The scanner checks for known credential formats, private-key headers, credentials embedded in URLs, generic secret assignments, suspicious filenames, and high-entropy opaque strings.
5. Email addresses, non-loopback IP addresses, commit author emails, and absolute home paths are reported separately as privacy-only findings.
6. Matched secret values are never printed. Reports contain only a category, path, abbreviated blob or commit ID, and line number.
7. Binary and oversized blobs are not silently accepted. The audit is marked incomplete unless they are reviewed separately or `--allow-unscanned` is explicitly supplied.

The audit covers committed outgoing history. `working_tree_dirty=true` means uncommitted changes exist and were not part of the scan; they are also not part of a normal `git push`.

### Reading the result

| Field | Meaning | Default effect |
| --- | --- | --- |
| `hard_findings` | Known token formats, private keys, credential-bearing URLs, or credentials in the push URL | Blocks with exit `2` |
| `generic_secret_assignments` | Non-placeholder values assigned to names such as `api_key`, `password`, or `client_secret` | Blocks with exit `2`; manually confirm possible false positives |
| `high_entropy_candidates` | Long, opaque strings that statistically resemble tokens but do not match a known format | Requires review with exit `3` |
| `sensitive_paths` | Files named like `.env`, `auth.json`, private keys, credentials, or secrets | Blocks with exit `2`, even if the content looks harmless |
| `commit_message_findings` | Known secret patterns found in an outgoing commit message | Blocks with exit `2` |
| `privacy_only_findings` | Usernames in home paths, emails, author metadata, or non-loopback IP addresses | Informational by default; exit `4` with `--fail-on-privacy` |
| `unscanned_blobs` | Binary or oversized blobs that were not fully inspected | Marks the scan incomplete with exit `5` |

Other useful fields:

- `base_is_ancestor=false` indicates branch divergence. The unique objects are still scanned, but the branch relationship should be reviewed before pushing.
- `working_tree_dirty=true` indicates that local uncommitted changes were outside the audit.
- `outgoing_commits` and `unique_outgoing_objects` describe the scope of the scan.
- `result=PASS` and exit `0` mean no blocking, entropy, or unscanned findings were detected. Privacy-only findings may still be present unless strict privacy mode was requested.

Exit codes are stable for scripting:

| Exit code | Result |
| --- | --- |
| `0` | `PASS` |
| `1` | Git/configuration/audit execution error |
| `2` | `BLOCKED` by a known or structurally suspicious secret |
| `3` | `REVIEW_REQUIRED` for high-entropy candidates |
| `4` | `PRIVACY_REVIEW_REQUIRED` when strict privacy mode is enabled |
| `5` | `INCOMPLETE` because one or more blobs were not scanned |
| `130` | Interrupted by the user |

This is a heuristic safety net, not a proof that a repository contains no secrets. Review unusual findings manually. If a real credential is found, rotate or revoke it first and remove it from every affected commit; deleting it only from the latest file does not remove it from the history that Git pushes.

## Local customization

Keep machine-specific or secret values out of tracked files. Prefer local override files, environment variables, or ignored configuration for credentials and host-specific settings.
