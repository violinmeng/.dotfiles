# macOS Dotfiles

Personal macOS development environment managed with [GNU Stow](https://www.gnu.org/software/stow/). The repository contains configuration for shells, terminals, editors, window management, command-line tools, and AI coding agents.

## Repository layout

Each top-level directory is a Stow package whose contents mirror paths under `$HOME`.

| Package | Configuration |
| --- | --- |
| `aerospace` | AeroSpace tiling window manager, including a Vim-style layout |
| `alacritty` | Alacritty terminal emulator |
| `apple-terminal-themes` | Color schemes for macOS Terminal |
| `emacs` | Emacs |
| `fzf` | Fuzzy-finder shell integration |
| `ghostty` | Ghostty terminal emulator |
| `git` | Global Git settings |
| `kvim` | Kvim editor configuration |
| `nvim` | Lua-based Neovim configuration |
| `pi` | Pi coding-agent settings, extensions, models, and themes |
| `tmux` | tmux and TPM integration |
| `vim` | Vim configuration |
| `yazi` | Yazi file manager, keymaps, and themes |
| `zed` | Zed editor settings and Pi ACP integration |
| `zsh` | Zsh, Oh My Zsh, environment, and custom shell settings |

The `docs` directory contains supporting documentation and diagrams rather than files intended to be stowed.

## Prerequisites

The configuration targets macOS. At minimum, install:

- [Homebrew](https://brew.sh/)
- [GNU Stow](https://www.gnu.org/software/stow/)
- Git

```sh
brew install stow
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
stow zed
stow pi
```

To install several packages at once:

```sh
stow zsh git tmux nvim yazi ghostty aerospace zed pi
```

To remove a package's symlinks without deleting its source files:

```sh
stow --delete nvim
```

If a real file already exists where Stow needs to create a symlink, move or back it up before stowing the package.

## Bootstrap script

`install.sh` is a personal macOS provisioning script. It attempts to install and configure:

- Homebrew and GNU Stow
- Oh My Zsh and selected Zsh plugins
- Alacritty
- FZF, `fd`, and ripgrep
- tmux and TPM
- Pi and Zed configuration
- Rust, Node.js, Ruby, LLVM, Haskell tooling, and `chsrc`

Review the script before running it:

```sh
./install.sh
```

> [!WARNING]
> The bootstrap script is currently a work in progress. It mixes POSIX shell and Bash syntax, contains machine-specific assumptions, performs network installations, and may require SSH credentials or elevated permissions. Prefer installing and stowing packages individually unless you have reviewed the script for your system.

## Neovim

The Neovim configuration lives under `nvim/.config/nvim` and is organized into:

- `lua/config` — options, keymaps, and autocommands
- `lua/core` — package management, LSP setup, and shared infrastructure
- `lua/plugins` — completion, linting, Treesitter, Telescope, Trouble, Which Key, Mason, and colorschemes
- `lsp` — language-server-specific configuration

Plugins are managed through Neovim's native package mechanism, with versions recorded in `nvim-pack-lock.json`.

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
