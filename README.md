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

## Local customization

Keep machine-specific or secret values out of tracked files. Prefer local override files, environment variables, or ignored configuration for credentials and host-specific settings.
