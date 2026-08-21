# macOS Dotfiles

Personal macOS development environment managed with [GNU Stow](https://www.gnu.org/software/stow/). The repository contains configuration for shells, terminals, editors, window management, command-line tools, and AI coding agents.

## Repository layout

Each top-level directory is a Stow package whose contents mirror paths under `$HOME`.

| Package | Configuration |
| --- | --- |
| `aerospace` | AeroSpace tiling window manager, including a Vim-style layout |
| `alacritty` | Alacritty terminal emulator |
| `apple-terminal-themes` | Color schemes for macOS Terminal |
| `emacs` | Emacs configuration under `~/.config/emacs` |
| `fzf` | Fuzzy-finder shell integration |
| `ghostty` | Ghostty terminal emulator |
| `git` | Global Git settings |
| `kvim` | Kvim editor configuration |
| `mise` | Global declarative runtime configuration |
| `nvim` | Lua-based Neovim configuration |
| `pi` | Pi coding-agent settings, extensions, models, and themes |
| `tmux` | tmux and TPM integration |
| `vim` | Vim configuration |
| `yazi` | Yazi file manager, keymaps, and themes |
| `zed` | Zed editor settings and Pi ACP integration |
| `zsh` | Zsh, Oh My Zsh, environment, and custom shell settings |

The `docs` directory contains supporting documentation and diagrams rather than files intended to be stowed. The root `Brewfile` declares system packages and applications managed by Homebrew Bundle.

## Prerequisites

The configuration targets macOS. For the automated bootstrap, the only external prerequisite is a working Git installation, normally provided by the Xcode Command Line Tools:

```sh
xcode-select --install
```

`install.sh` provisions Homebrew and applies the root `Brewfile` when needed. To install the declared Homebrew dependencies manually:

```sh
brew bundle install --no-upgrade --file Brewfile
```

Some packages require their corresponding applications to be installed separately.

## Installation with Stow

Clone the repository into your home directory:

```sh
git clone <repository-url> ~/.dotfiles
cd ~/.dotfiles
```

Install individual packages from the repository root:

```sh
stow zsh
stow git
stow tmux
stow nvim
stow emacs
stow zed
stow pi
```

To install several packages at once:

```sh
stow zsh git tmux nvim emacs yazi ghostty aerospace zed pi
```

To remove a package's symlinks without deleting its source files:

```sh
stow --delete nvim
```

If a real file already exists where Stow needs to create a symlink, move or back it up before stowing the package.

## Bootstrap script

`install.sh` is an idempotent Bash bootstrap script for macOS. By default, it installs the core command-line environment, deploys the primary Stow packages, and configures language toolchains.

Preview the complete setup without changing the system:

```sh
./install.sh --dry-run
```

Run the default installation:

```sh
./install.sh
```

Install selected components or Stow packages:

```sh
./install.sh --packages zsh,tmux,nvim
```

Homebrew dependencies are treated as one atomic system layer. Selecting `brew` or any component backed by Homebrew applies the complete `Brewfile`, rather than installing only one formula from it.

Deploy configuration without installing software:

```sh
./install.sh --stow-only --packages zsh,mise,tmux,zed,pi
```

Use `./install.sh --help` for the full component list and available options. Change system dependencies in `Brewfile` and runtime versions in the root `mise.toml`; the installer contains no duplicated package or runtime version list.

### Tool-management layers

The bootstrap deliberately assigns one responsibility to each manager:

| Layer | Manager | Responsibilities |
| --- | --- | --- |
| macOS system | Homebrew Bundle | `mise`, GNU Stow, terminals, CLI tools, and runtime build dependencies declared in `Brewfile` |
| Language runtimes | mise | Bun, Java, Node.js, Ruby, Rust, Tuist, and Zig declared in the global mise config |
| Haskell ecosystem | GHCup | GHC, Cabal, and HLS as one compatible toolchain |
| Configuration | GNU Stow | Shell, editor, terminal, agent, and application configuration |
| Plugins and source checkouts | Git | Oh My Zsh, Zsh plugins, TPM, and `z` |

Mise uses `~/.config/mise/config.toml` as its standard global declaration path. The repository keeps the canonical declaration in the root `mise.toml`; `mise/.config/mise/config.toml` is a relative symlink to that file, allowing Stow to expose the same declaration globally without duplication. The installer then runs `mise install`. On first migration, an existing regular config file is atomically moved to a timestamped backup before Stow takes ownership; if Stow fails, the original config is restored automatically. The tracked config includes the previously configured Bun, Java, Node.js, Tuist, and Zig entries plus Ruby and Rust. Project-specific versions can still be declared in each project's `mise.toml` and override these global defaults.

Existing NVM, rbenv, or rustup installations are not deleted automatically. After verifying that projects and editor integrations resolve the mise-managed runtimes, those legacy installations can be removed manually if they are no longer needed.

The mise shims directory is added to shell startup so globally configured runtimes also work in scripts and non-interactive shells. Interactive Zsh additionally uses `mise activate zsh` for automatic project switching. GHCup's bin directory is prepended after mise activation so the Haskell toolchain remains owned by GHCup.

If the stowed Zsh configuration is unavailable, the installer adds minimal runtime setup to `~/.zshenv` and `~/.zshrc`. A later Zsh Stow installation automatically removes those files only when they still contain installer-generated lines exclusively; user-extended files are left untouched so Stow can report the conflict safely. Pass `--no-profile-update` to print required setup without modifying profile files.

> [!WARNING]
> The bootstrap downloads and executes official Homebrew and GHCup installers and clones third-party Git repositories. Runtime downloads are delegated to mise. Review the script and upstream sources before running it in a sensitive environment.

## Neovim

The Neovim configuration lives under `nvim/.config/nvim` and is organized into:

- `lua/config` — options, keymaps, and autocommands
- `lua/core` — package management, LSP setup, and shared infrastructure
- `lua/plugins` — completion, linting, Treesitter, Telescope, Trouble, Which Key, Mason, and colorschemes
- `lsp` — language-server-specific configuration

Plugins are managed through Neovim's native package mechanism, with versions recorded in `nvim-pack-lock.json`.

## Emacs

The `emacs` package keeps the canonical configuration under `~/.config/emacs`, including `init.el`, Custom settings, and the package bootstrap helpers in `emacs.rc`. Because Emacs prefers an existing `~/.emacs.d`, a small compatibility loader at `~/.emacs.d/init.el` forwards startup to the XDG configuration while existing ELPA packages and runtime state remain in `~/.emacs.d`. The previous configuration is retained as `~/.config/emacs/init.el.backup`.

## Pi and Zed

The `pi` package includes coding-agent configuration under `~/.pi/agent`, including:

- custom TypeScript extensions
- model and MCP configuration
- keybindings
- themes
- tool-display and context-management settings

The `zed` package configures Zed to work with Pi through the Agent Client Protocol (ACP). See `docs/pi-zed-acp-setup.svg` for an overview of the setup.

Generated Pi runtime state stays inside the Stow package but is excluded from Git where appropriate.

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
