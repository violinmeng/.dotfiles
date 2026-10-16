local telescope = require("telescope")
local actions = require("telescope.actions")

telescope.setup({
  defaults = {
    path_display = { "truncate" },
    mappings = {
      i = {
        ["<Leader>t"] = actions.file_tab,
        ["<Leader>s"] = actions.file_vsplit,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
      },
      n = {
        ["<Leader>t"] = actions.file_tab,
        ["<Leader>s"] = actions.file_vsplit,
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
  },
})

telescope.load_extension("fzf")

vim.keymap.set("n", "<Leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Fuzzy find buffers" })
vim.keymap.set("n", "<Leader>fm", "<cmd>Telescope command_history<CR>", { desc = "Fuzzy find command history" })
vim.keymap.set("n", "<Leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Fuzzy find help tags" })
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Fuzzy find files in cwd" })
vim.keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Fuzzy find recent files" })
vim.keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<CR>", { desc = "Find string in cwd" })
vim.keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<CR>", { desc = "Find string under cursor in cwd" })
