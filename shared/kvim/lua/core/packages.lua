local function github(repo)
  return "https://github.com/" .. repo
end

local packages = {
  { src = github("NMAC427/guess-indent.nvim") },
  { src = github("nvim-telescope/telescope.nvim") },
  { src = github("nvim-lua/plenary.nvim") },
  { src = github("nvim-telescope/telescope-fzf-native.nvim") },
  { src = github("nvim-telescope/telescope-ui-select.nvim") },
  { src = github("nvim-tree/nvim-web-devicons") },
  { src = github("folke/lazydev.nvim") },
  { src = github("neovim/nvim-lspconfig") },
  { src = github("j-hui/fidget.nvim") },
  { src = github("saghen/blink.cmp"), version = vim.version.range("1.*") },
  { src = github("L3MON4D3/LuaSnip"), version = vim.version.range("2.*") },
  { src = github("stevearc/conform.nvim") },
  { src = github("folke/todo-comments.nvim") },
  { src = github("nvim-treesitter/nvim-treesitter"), version = "master" },
  { src = github("nvim-treesitter/nvim-treesitter-textobjects"), version = "master" },
  { src = github("lukas-reineke/indent-blankline.nvim") },
  { src = github("HiPhish/rainbow-delimiters.nvim") },
  { src = github("windwp/nvim-autopairs") },
  { src = github("nvim-neo-tree/neo-tree.nvim") },
  { src = github("MunifTanjim/nui.nvim") },
  { src = github("echasnovski/mini.nvim") },
  { src = github("folke/tokyonight.nvim") },
  { src = github("lewis6991/gitsigns.nvim") },
  { src = github("folke/which-key.nvim") },
  { src = github("kevinhwang91/nvim-ufo") },
  { src = github("kevinhwang91/promise-async") },
  { src = github("keith/swift.vim") },
}
if vim.fn.has("macunix") == 1 then
  table.insert(packages, { src = github("wojciech-kulik/xcodebuild.nvim") })
end
vim.pack.add(packages, { confirm = false, load = true })

local function is_newer(left, right)
  if left.sec ~= right.sec then
    return left.sec > right.sec
  end
  return left.nsec > right.nsec
end

local function build_if_needed(name, marker, command)
  local plugin = vim.pack.get({ name })[1]
  if not plugin then
    return
  end

  local marker_stat = vim.uv.fs_stat(plugin.path .. "/" .. marker)
  local index_stat = vim.uv.fs_stat(plugin.path .. "/.git/index")
  if marker_stat and index_stat and not is_newer(index_stat.mtime, marker_stat.mtime) then
    return
  end

  local result = vim.system(command, { cwd = plugin.path }):wait()
  if result.code ~= 0 then
    vim.notify("Failed to build " .. name, vim.log.levels.WARN)
  end
end

if vim.fn.executable("make") == 1 then
  build_if_needed("telescope-fzf-native.nvim", "build/libfzf.so", { "make" })
  build_if_needed("LuaSnip", "deps/luasnip-jsregexp.so", { "make", "install_jsregexp" })
end

require("plugins")

vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Update plugins managed by vim.pack" })
