return {
  -- 诊断和格式化插件
  -- {
  --   'jose-elias-alvarez/null-ls.nvim',
  --   config = function()
  --     local null_ls = require('null-ls')
  --     null_ls.setup({
  --       sources = {
  --         null_ls.builtins.formatting.prettier,  -- Prettier 格式化
  --         null_ls.builtins.diagnostics.eslint,   -- ESLint 诊断
	-- 				null_ls.builtins.formatting.swift_format,  -- Swift 格式化
  --       },
  --     })
  --   end,
  -- },
  -- 其他实用插件
  -- {
  --   'ray-x/lsp_signature.nvim',
  --   config = function()
  --     require('lsp_signature').setup()
  --   end,
  -- }
    -- editor config support
  {
    "editorconfig/editorconfig-vim",
  },

  -- {
  --   "folke/flash.nvim",
  --   event = "VeryLazy",
  --   ---@type Flash.Config
  --   opts = {},
  --   -- stylua: ignore
  --   keys = {
  --     { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
  --     { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
  --     { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
  --     { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
  --     { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
  --   },
  -- },
    {
    "echasnovski/mini.nvim",
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      -- require("mini.ai").setup({ n_lines = 500 })

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require("mini.surround").setup()

      require("mini.pairs").setup()


      local statusline = require("mini.statusline")
      statusline.setup({
        use_icons = vim.g.have_nerd_font,
      })
      -- ---@diagnostic disable-next-line: duplicate-set-field
      -- statusline.section_location = function()
      --   return "%2l:%-2v"
      -- end
    end,
  },

  {
    "echasnovski/mini.icons",
    enabled = true,
    opts = {},
    lazy = true,
  },

  -- {
  --   "fladson/vim-kitty",
  --   "MunifTanjim/nui.nvim",
  -- },
  -- {
  --   "nvchad/showkeys",
  --   cmd = "ShowkeysToggle",
  --   opts = {
  --     timeout = 1,
  --     maxkeys = 6,
  --     -- bottom-left, bottom-right, bottom-center, top-left, top-right, top-center
  --     position = "bottom-right",
  --   },

  --   keys = {
  --     {
  --       "<leader>ut",
  --       function()
  --         vim.cmd("ShowkeysToggle")
  --       end,
  --       desc = "Show key presses",
  --     },
  --   },
  -- },
}
