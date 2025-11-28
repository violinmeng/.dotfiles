-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- Quick tab switcher: Move current line to a new tab
vim.keymap.set("n", "<leader><tab>", "mc80A <esc>080lDgelD`cP", { desc = "Move current line to a new tab" })

-- Terminal keymap to open a terminal at the bottom
vim.keymap.set("n", "<leader>st", function()
  vim.cmd.vnew()
  vim.cmd.term()
  vim.cmd.wincmd("J")
  vim.api.nvim_win_set_height(0, 5)
end)

-- 退出终端模式并进入普通模式 (ESC)
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- 【黄金搭档】退出终端模式后，立即关闭终端窗口 (ESC 然后关闭)
-- 这比先退出再手动 :q 快得多
vim.keymap.set("t", "<C-w>", "<C-\\><C-n><C-w>c", { desc = "Close terminal window" })

-- 【黄金搭档】退出终端模式后，切换到上一个窗口 (ESC 然后切换)
-- 例如，你从某个窗口 splits 了一个终端，用完想直接回去
vim.keymap.set("t", "<C-w>p", "<C-\\><C-n><C-w>p", { desc = "Switch to previous window" })

-- 用空格键来切换折叠/展开 (非常实用！)
-- vim.keymap.set("n", "<Space>", "za", { desc = "Toggle fold" })

-- 映射 zc/zo 到更方便的键，比如 leader 前缀
vim.keymap.set("n", "<leader>z", "zc", { desc = "Close fold" })
vim.keymap.set("n", "<leader>Z", "zo", { desc = "Open fold" })

vim.keymap.set("n", "<leader>zm", "zM", { desc = "Fold [M]ore (all)" })
vim.keymap.set("n", "<leader>zr", "zR", { desc = "Fold [R]educe (none)" })

-- 快速到行首（包括空格）
vim.keymap.set("n", "gh", "0", { noremap = true, desc = "到行首(含空格)" })
vim.keymap.set("o", "gh", "0", { noremap = true, desc = "到行首(含空格)" })

-- 快速到行尾
vim.keymap.set("n", "gl", "$", { noremap = true, desc = "到行尾" })
vim.keymap.set("o", "gl", "$", { noremap = true, desc = "到行尾" })

-- Leader + h 跳到第一个非空白字符
vim.keymap.set("n", "gj", "^", { noremap = true, desc = "到第一个非空白字符" })
vim.keymap.set("o", "gj", "^", { noremap = true, desc = "到第一个非空白字符" })
