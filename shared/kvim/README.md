# kvim

Personal Neovim configuration for Neovim 0.12 or newer.

## Structure

- `init.lua` loads editor settings and the package configuration.
- `lua/config/` contains options, keymaps, and autocommands.
- `lua/core/packages.lua` declares plugins with Neovim's built-in `vim.pack` manager.
- `lua/plugins/` contains one configuration module per plugin.
- `nvim-pack-lock.json` pins plugin revisions and should be committed.

## Plugin management

Plugins are installed automatically on startup. Run `:PackUpdate` to review and apply plugin updates. In the update buffer, write the buffer to confirm or quit to cancel.

External tools used by this configuration include `git`, `make`, a C compiler, `ripgrep`, and `fd`. Language servers and formatters (`lua-language-server`, Pyright, StyLua, and SwiftFormat) are declared in the repository's root `mise.toml`; SourceKit-LSP is provided by Xcode.
