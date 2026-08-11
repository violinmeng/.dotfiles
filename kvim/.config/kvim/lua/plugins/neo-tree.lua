require("neo-tree").setup({
  filesystem = {
    window = {
      mappings = {
        ["\\"] = "close_window",
      },
    },
    filtered_items = {
      visible = true,
      hide_hidden = false,
      never_show = {},
    },
  },
})

vim.keymap.set("n", "\\", "<cmd>Neotree reveal<CR>", {
  desc = "NeoTree reveal",
  silent = true,
})
