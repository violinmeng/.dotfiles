require("mini.ai").setup({ n_lines = 500 })
require("mini.surround").setup()
require("mini.comment").setup()

local hipatterns = require("mini.hipatterns")
hipatterns.setup({
  highlighters = {
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})

local statusline = require("mini.statusline")
statusline.setup({ use_icons = vim.g.have_nerd_font })
statusline.section_location = function()
  return "%2l:%-2v"
end
