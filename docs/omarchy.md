# Set up the shell and editors on Omarchy

This port targets Omarchy on Arch Linux, including ARM64. It leaves your desktop,
terminal settings, and login shell unchanged. It does not deploy AeroSpace or
Apple Terminal themes. SASE and ActionBridge are only referenced inside macOS
shell guards.

## Preview the configuration

From the repository, run:

```sh
./install.py --dry-run
```

The default selection is `agents,zsh,git,fzf,tmux,nvim,kvim,yazi,mise`. Each file gets a
symlink into `shared/<app>/` or `linux/<app>/` in this repository. Shared home
directories remain real directories, so unrelated files stay in place. The
`mise` package uses `linux/mise/config.toml`; macOS uses its own declaration.

## Install dependencies and apply the configuration

```sh
./install.py --apply --install-packages
```

The package step checks the configured repositories before calling
`omarchy pkg add`. Run this in a terminal where you can enter your sudo password.
It does not refresh package databases or perform a system upgrade. If a package
is unavailable, the installer stops before deploying configuration.

Existing files move to `~/.local/state/dotfiles/backups/<timestamp>/` with their
relative paths preserved. To restore a file, remove its new symlink and move its
backup to the original path. Repeating the installer leaves correct links alone.
An error during link creation restores the files changed in that invocation.
The installer expands directory links owned by this repository. It refuses
unrelated directory symlinks to avoid modifying another checkout.

Start `zsh` to use the shell configuration. The installer runs `chsh` only with `--set-default-shell`.
Without Oh My Zsh, Zsh uses completion and a basic prompt. Existing Oh My Zsh,
TPM, and `z` installations are reused. Plugin downloads require `--install-plugins`.
The custom `wangalin` theme and Zsh plugins require Oh My Zsh and its plugins;
tmux's Catppuccin theme requires TPM and the plugin checkout. Missing themes do
not prevent shell or tmux startup.

## Install the configured shell and tmux plugins

```sh
./install.py --apply --packages zsh,tmux --install-plugins
```

Add `--install-packages` if Zsh or tmux is missing. Omit `--apply` to preview.
The installer reads the active Zsh and tmux plugin declarations. It installs
Oh My Zsh, autosuggestions, syntax highlighting, the `z` directory helper, TPM,
and Catppuccin at the version pinned in `.tmux.conf`. Commented plugin examples
are excluded. Existing checkouts are reused without updates or resets; a
conflicting upstream or version stops installation. Failed clones are removed.
The custom `wangalin` theme is deployed with the Zsh configuration.

To reload an existing tmux session after installation, run:

```sh
tmux source-file ~/.tmux.conf
```

New tmux servers load it automatically. The tmux prefix is `Ctrl+a`.

## Install Neovim plugins

```sh
./install.py --apply --packages nvim --install-plugins
```

Add `--install-packages` when Neovim or the C build tools are missing. The
installer starts the selected profile headlessly. Neovim's native `vim.pack`
manager installs the active plugins from `lua/core/packages.lua` using the
profile's lockfile. The configuration builds Telescope's native FZF extension.
A verification step checks startup errors, plugin directories, the compiled
library, and loading the FZF extension; failures stop the installer.

The `nvim` profile currently has nine active plugins. Legacy Mason, Treesitter,
and Blink declarations inside Lua comments are not enabled by this command.
Use `--packages kvim --install-plugins` for the separate Kvim profile. That
profile has its own plugin set. The `knvim` shell alias selects this profile,
so it needs `~/.config/kvim` as well as its own installed plugins. Kvim is included
in the default configuration selection. It requires Neovim 0.12+ and the
supported `main` Treesitter and text-object APIs. `--install-packages` installs
Tree-sitter CLI 0.26.1+ through Omarchy; parser generation also needs Node.
If an older npm CLI shadows the distro binary, remove it with
`npm uninstall --global --prefix ~/.local tree-sitter-cli`.
During installer runs, parser builds are synchronous and verified before success. Neither command invokes `PackUpdate` or
installs language runtimes. You can include `zsh,tmux,nvim` in a single selection
to reproduce the installed shell, multiplexer, and editor plugins.

## Select additional editors

```sh
./install.py --dry-run --packages zsh,git,fzf,tmux,nvim,kvim,emacs,yazi,mise,zed
```

Add `--apply` to deploy that selection. Optional `vim`, `pi`, and `herdr` packages
are also supported. Configuration-only deployment does not install Zed, Pi, or Herdr. For Pi, add
`--install-packages --install-plugins` to install the CLI and its configured packages.
The Pi package contains personal provider, model, and MCP settings; select it
only when you intend to use those settings. No credentials are created or copied
from local private files.

Zed and Ghostty support Linux. Their package names were absent from this
machine's configured ARM64 indexes during the port. Zed publishes an official
[aarch64 build](https://zed.dev/docs/linux); Ghostty documents its
[Linux installation options](https://ghostty.org/docs/linux). Ghostty's configuration
is unchanged and excluded from the Linux installer. Launch Zed from a configured
shell so its agent processes inherit the runtime PATH. Agent configuration no
longer hard-codes the Mac home directory.

## Install language runtimes separately

Install mise for your architecture first. Then run:

```sh
./install.py --apply --packages mise --install-runtimes
```

The Linux declaration retains the Mac versions for Bun, Java, Lua language
server, Node, Pyright, Ruby, Rust, Stylua, and Zig. It omits Tuist and SwiftFormat
from the default installation. This is a conservative Linux toolchain selection,
not a claim that those tools cannot run on Linux. Tuist now
[supports Linux](https://tuist.dev/en/docs/guides/install-tuist), but Xcode builds
and the Xcode Neovim plugin require a Mac. Kvim loads the Xcode plugin only on
macOS, and enables SourceKit and SwiftFormat only when their executables exist.
Runtime downloads and Ruby/Java builds have not been validated on this machine.
The installer leaves GHCup, gh, chsrc, mobile SDKs, and agent CLIs for explicit
installation. Android defaults to `~/Android/Sdk`; override `ANDROID_HOME` for a
different location.

## Optional WeChat desktop app

WeChat is installed separately from the dotfiles. Use the native Linux build
from [WeChat's official download page](https://linux.weixin.qq.com/), not a
Wine wrapper. On this ARM64 machine (`uname -m` reports `aarch64`), select
**ARM → AppImage**; the x86_64 build is for Intel/AMD machines.

For a fresh ARM64 installation, run these commands in a terminal:

```sh
omarchy pkg add fuse2
mkdir -p ~/Applications
curl -fL --retry 3 \
  https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.AppImage \
  -o ~/Applications/WeChat.AppImage.download &&
  chmod +x ~/Applications/WeChat.AppImage.download &&
  mv -i ~/Applications/WeChat.AppImage.download ~/Applications/WeChat.AppImage &&
  ~/Applications/WeChat.AppImage
```

Scan the login QR code using WeChat on your phone. The download URL serves the
current upstream release rather than a pinned version. To update, quit WeChat
first, back up the existing AppImage, and repeat the download steps.

The local installation also has an app-launcher entry at
`~/.local/share/applications/wechat-appimage.desktop`, pointing to
`~/Applications/WeChat.AppImage`, with its extracted icon at
`~/.local/share/icons/wechat-appimage.png`. These are generated per user and are
not deployed by `install.py`. On another machine, create a launcher entry using
that machine's absolute home path; `.desktop` `Exec` and `Icon` fields do not
expand `~` or `$HOME`.

Keep the AppImage, extracted icons, login/session data (`~/.xwechat/`), and chat
files (`~/Documents/xwechat_files/`) outside this repository. Do not copy them
into `linux/` or another user's home.

## Screenshot and Command-key shortcuts

`linux/hypr/` preserves the working desktop shortcuts. These files are
excluded from `install.py`, including explicit package selection. Restore them
separately if you want this desktop customization. The saved `bindings.lua`
replaces your personal binding overrides, so merge it instead if you have others.

| Shortcut | Action |
| --- | --- |
| Command/Super + Shift + A | Select a screenshot region and open Satty; replaces the ChatGPT web app binding |
| Command/Super + C | Copy using Omarchy's existing universal copy binding |
| Command/Super + S | Save in Satty; toggle the scratchpad elsewhere |
| Command/Super + V | Paste text or images; terminals receive Shift+Insert for text and Ctrl+V for images |

The paste helper checks clipboard MIME types in a separate process so it does
not block Hyprland's Wayland event loop. Pi's tracked `keybindings.json` accepts
both Ctrl+V and Alt+V for image paste. Restart Pi after changing that file.

To restore the saved desktop files, run these commands from the repository in
an Omarchy desktop session:

```sh
omarchy pkg add satty grim slurp wl-clipboard imagemagick
cp -a ~/.config/hypr ~/.config/hypr.backup-$(date +%Y%m%dT%H%M%S)
cp linux/hypr/bindings.lua ~/.config/hypr/bindings.lua
cp linux/hypr/command-paste.py ~/.config/hypr/command-paste.py
hyprctl reload
hyprctl configerrors
```

The screenshot binding uses Omarchy's `capture screenshot region save` command.
It saves images under your configured Pictures directory and opens Satty with
that file as both input and save destination.

## Check the port

```sh
python3 scripts/check-install.py
```

This exercises preview, real links, backups, repeat application, package
selection errors, and directory-symlink refusal in disposable targets. It also
parses TOML and checks Python and Lua syntax. If Zsh is installed, it
checks shell syntax and starts an isolated interactive shell. It does not load
editor plugins or download runtimes. Clipboard operations require a running
Wayland session and `wl-clipboard`; tmux falls back to OSC 52 outside that session.

FZF's Chrome history and bookmark helpers remain Chrome-specific. They now use
Linux paths and report a missing profile instead of assuming one exists. They
do not install or select a browser.
