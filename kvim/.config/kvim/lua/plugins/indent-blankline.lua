local highlight = require("plugins.rainbow-delimiters")
local hooks = require("ibl.hooks")

require("ibl").setup({
  scope = {
    highlight = highlight,
  },
})

hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
