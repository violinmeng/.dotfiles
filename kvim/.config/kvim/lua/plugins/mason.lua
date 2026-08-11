local servers = { "lua_ls", "pyright" }

require("mason").setup({})
require("mason-tool-installer").setup({
  ensure_installed = {
    "lua-language-server",
    "pyright",
    "stylua",
  },
})
require("mason-lspconfig").setup({
  ensure_installed = servers,
  automatic_enable = false,
})
