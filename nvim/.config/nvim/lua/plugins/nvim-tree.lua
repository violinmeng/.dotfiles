-- ~/.config/nvim/lua/plugins/nvim-tree.lua

local function my_on_attach(bufnr)
  local api = require "nvim-tree.api"

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- default mappings
  api.config.mappings.default_on_attach(bufnr)

  -- custom mappings
  vim.keymap.set('n', '<C-t>', api.tree.change_root_to_parent,        opts('Up'))
  vim.keymap.set('n', '?',     api.tree.toggle_help,                  opts('Help'))
end

return {
  'nvim-tree/nvim-tree.lua',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
		require('nvim-tree').setup({
			sort = {
				sorter = "case_sensitive",
			},
			view = {
				width = 30,
				side = 'left',
			},
			renderer = {
				group_empty = true,
			},
			filters = {
				dotfiles = true,
			},
			on_attach = my_on_attach
		})
  end,
}
