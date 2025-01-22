---@diagnostic disable: undefined-global
vim = vim

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = false

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.hlsearch = false
vim.opt.wrap = true
vim.opt.breakindent = true

-- nvim-tree config
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
-- optionally enable 24-bit colour
vim.opt.termguicolors = true

vim.g.mapleader = ","
vim.g.maplocalleader = ","

require("config.lazy")

require("nvim-treesitter.configs").setup({
  -- 启用语法高亮
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,  -- 禁用传统的正则表达式高亮
  },

  -- 启用代码折叠
	indent = {
		enable = true,
	},

  -- 启用增量选择
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",  -- 进入增量选择模式
      node_incremental = "grn",  -- 扩展选择范围
      scope_incremental = "grc",  -- 选择整个作用域
      node_decremental = "grm",  -- 缩小选择范围
    },
  },

  -- 启用文本对象选择
  textobjects = {
    enable = true,
    -- 自定义文本对象
    keymaps = {
      ["af"] = "@function.outer",  -- 选择整个函数
      ["if"] = "@function.inner",  -- 选择函数体
      ["ac"] = "@class.outer",     -- 选择整个类
      ["ic"] = "@class.inner",     -- 选择类体
    },
  },

  -- 自动安装语法解析器
  ensure_installed = {
    "python", "javascript", "lua", "go", "rust", "cpp", "java", "html", "css",
  },
})

local lspconfig = require('lspconfig')
lspconfig.pyright.setup {}  -- Python
lspconfig.ts_ls.setup {}  -- TypeScript/JavaScript
lspconfig.rust_analyzer.setup {}  -- Rust
lspconfig.gopls.setup {}  -- Go
lspconfig.lua_ls.setup {}  -- Lua
lspconfig.sourcekit.setup {} -- Swift

require("config.keymaps")

-- tips
-- :help auto completion select list, swith the selected item using TAB
