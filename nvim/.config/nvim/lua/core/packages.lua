local function github(repo)
  return "https://github.com/" .. repo
end

vim.pack.add({
  { src = github("editorconfig/editorconfig-vim") },
  { src = github("echasnovski/mini.nvim") },
  { src = github("echasnovski/mini.icons") },
  { src = github("catppuccin/nvim"), name = "catppuccin" },
  { src = github("nvim-lua/plenary.nvim") },
  { src = github("nvim-telescope/telescope.nvim"), version = "0.1.8" },
  { src = github("nvim-telescope/telescope-fzf-native.nvim") },
  { src = github("nvim-tree/nvim-web-devicons") },
  { src = github("folke/which-key.nvim") },
}, { confirm = false, load = true })

-- vim.pack does not run plugin build steps, so build Telescope's native sorter
-- the first time it is installed.
local fzf = vim.pack.get({ "telescope-fzf-native.nvim" })[1]
if fzf and vim.fn.filereadable(fzf.path .. "/build/libfzf.so") == 0 then
  local result = vim.system({ "make" }, { cwd = fzf.path }):wait()
  if result.code ~= 0 then
    vim.notify("Failed to build telescope-fzf-native.nvim", vim.log.levels.WARN)
  end
end

require("plugins.colorschemes")
require("plugins.init")
require("plugins.telescope")
require("plugins.which-key")

vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Update plugins managed by vim.pack" })
