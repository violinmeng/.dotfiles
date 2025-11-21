-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  "nvim-neo-tree/neo-tree.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
  },
  lazy = false,
  keys = {
    { "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
  },
  opts = {
    filesystem = {
      window = {
        mappings = {
          ["\\"] = "close_window",
        },
      },
      filtered_items = {
        visible = true, -- 当为 true 时，显示隐藏文件（但会变灰）
        -- hide_dotfiles = false, -- 这是关键！设置为 false 以显示点文件
        -- hide_gitignored = false, --设置为 false 以同时显示被 .gitignore 忽略的文件
        hide_hidden = false, -- 设置为 false 以显示所有隐藏文件（macOS/Linux 的 .file，Windows 的 hidden 属性文件）
        never_show = {
          -- ".DS_Store",
          -- "thumbs.db"
        },
      },
    },
  },
}
