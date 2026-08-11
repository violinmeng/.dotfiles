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
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Windows
-- Horizontal split
vim.keymap.set('n', '-', ':split<CR>', { desc = "Split window horizontally" })
-- Vertical split
vim.keymap.set('n', '|', ':vsplit<CR>', { desc = "Split window vertically" })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<M-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<M-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<M-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<M-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

vim.keymap.set('t', '<M-h>', '<C-\\><C-N><C-w>h', { desc = "Move focus to the left window" })
vim.keymap.set('t', '<M-j>', '<C-\\><C-N><C-w>j', { desc = "Move focus to the lower window" })
vim.keymap.set('t', '<M-k>', '<C-\\><C-N><C-w>k', { desc = "Move focus to the upper window" })
vim.keymap.set('t', '<M-l>', '<C-\\><C-N><C-w>l', { desc = "Move focus to the right window" })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- Jump to line start (including spaces)
vim.keymap.set("n", "gh", "0", { noremap = true, desc = "Jump to line start (including spaces)" })
vim.keymap.set("o", "gh", "0", { noremap = true, desc = "Jump to line start (including spaces)" })

-- Jump to line end
vim.keymap.set("n", "gl", "$", { noremap = true, desc = "Jump to line end" })
vim.keymap.set("o", "gl", "$", { noremap = true, desc = "Jump to line end" })

-- Jump to first non-whitespace character
vim.keymap.set("n", "gj", "^", { noremap = true, desc = "Jump to first non-whitespace character" })
vim.keymap.set("o", "gj", "^", { noremap = true, desc = "Jump to first non-whitespace character" })

-- Jump to matching bracket
vim.keymap.set('n', '5', '%', { noremap = true, desc = "Jump to matching bracket" })
vim.keymap.set('o', '5', '%', { noremap = true, desc = "Jump to matching bracket" })

-- Move selected line / block of text in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, desc = "Move line up" })

-- COMMAND MODE
-- vim.keymap.set('n', '<Tab>', '<C-C>:tabnext<CR>') -- CTRL-SHIFT-Tab 切换到上一个 Tab
-- vim.keymap.set('n', '<S-Tab>', '<C-C>:tabprevious<CR>')


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

-- NORMAL MODE
-- 将后退映射为 <Leader>b
vim.keymap.set('n', '<Leader>b', '<C-o>')
-- 将前进映射为 <Leader>f
vim.keymap.set('n', '<Leader>B', '<C-i>')
-- vim.keymap.set('n', '<Leader>e', ':NvimTreeToggle<CR>')
-- 映射 <Leader>f 为 *
vim.keymap.set('n', '<Leader>f', '*')
-- 映射 <Leader>F 为 #
vim.keymap.set('n', '<Leader>F', '#')

-- 普通模式下，映射 <Leader>p 为粘贴系统剪贴板内容
vim.keymap.set('n', '<Leader>p', '"+p')
vim.keymap.set('n', '<Leader>q', ':q<CR>')  -- 退出
vim.keymap.set('n', '<Leader>w', ':w<CR>')  -- 保存文件
vim.keymap.set('n', '<Leader>ts', ':split | terminal<CR>')  -- 分屏打开终端
vim.keymap.set('n', '<Leader>tv', ':vsplit | terminal<CR>')  -- 分屏打开终端
-- vim.keymap.set('n', '<Leader>tr', ':b term://<Tab><CR>')  -- 恢复终端

vim.keymap.set('n', '<M-Tab>', ':tabnext<CR>') -- CTRL-Tab 切换到下一个 Tab
vim.keymap.set('n', '<M-S-Tab>', ':tabprevious<CR>')

-- VISUAL 可视模式下，映射 <Leader>y 为复制到系统剪贴板
vim.keymap.set('v', '<Leader>y', '"+y')

-- INSERT MODE
vim.keymap.set('i', '<M-Tab>', '<C-\\><C-N>:tabnext<CR>') -- CTRL-Tab 切换到下一个 Tab
vim.keymap.set('i', '<M-S-Tab>', '<C-\\><C-N>:tabprevious<CR>')

-- TERMINAL MODE

-- vim.keymap.set('t', '<Leader>th', '<C-\\><C-N>:hide<CR>') -- 隐藏终端

-- COPY FROM https://github.com/adibhanna/nvim/tree/main
-- Learn and think why and how these works
local opts = { noremap = true, silent = true }
-- local map = vim.keymap.set

-- Keep cursor centered when scrolling
-- vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
-- vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)
--

-- Fast saving
-- vim.keymap.set("n", "<leader>w", ":write!<CR>", { silent = true, desc = "Save file" })
-- vim.keymap.set("n", "<leader>q", ":q!<CR>", opts)

-- Remap for dealing with visual line wraps
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })

-- better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- paste over currently selected text without yanking it
vim.keymap.set("v", "p", '"_dp')
vim.keymap.set("v", "P", '"_dP')

-- copy everything between { and } including the brackets
-- p puts text after the cursor,
-- P puts text before the cursor.
vim.keymap.set("n", "YY", "va{Vy", opts)

-- Move line on the screen rather than by line in the file
-- vim.keymap.set("n", "j", "gj", opts)
-- vim.keymap.set("n", "k", "gk", opts)

-- Exit on jj and jk
vim.keymap.set("i", "jj", "<ESC>", opts)
vim.keymap.set("i", "jk", "<ESC>", opts)

-- Move to start/end of line
vim.keymap.set({ "n", "x", "o" }, "H", "^", opts)
vim.keymap.set({ "n", "x", "o" }, "L", "g_", opts)

-- Navigate buffers
vim.keymap.set("n", "<Right>", ":bnext<CR>", opts)
vim.keymap.set("n", "<Left>", ":bprevious<CR>", opts)

-- Panes resizing
-- vim.keymap.set("n", "+", ":vertical resize +5<CR>")
-- vim.keymap.set("n", "_", ":vertical resize -5<CR>")
-- vim.keymap.set("n", "=", ":resize +5<CR>")
-- vim.keymap.set("n", "-", ":resize -5<CR>")

-- Map enter to ciw in normal mode
-- vim.keymap.set("n", "<CR>", "ciw", opts)  -- Commented out: This overwrites word on Enter - too disruptive
-- vim.keymap.set("n", "<BS>", "ci", opts)   -- Commented out: This changes text on Backspace - too disruptive

vim.keymap.set("n", "n", "nzzv", opts)
vim.keymap.set("n", "N", "Nzzv", opts)
vim.keymap.set("n", "*", "*zzv", opts)
vim.keymap.set("n", "#", "#zzv", opts)
vim.keymap.set("n", "g*", "g*zz", opts)
vim.keymap.set("n", "g#", "g#zz", opts)

-- map ; to resume last search
-- map("n", ";", "<cmd>Telescope resume<cr>", opts)

-- search current buffer
-- vim.keymap.set("n", "<C-s>", ":Telescope current_buffer_fuzzy_find<CR>", opts)

-- Split line with X
vim.keymap.set("n", "X", ":keeppatterns substitute/\\s*\\%#\\s*/\\r/e <bar> normal! ==^<cr>", { silent = true })

-- ctrl + x to cut full line
vim.keymap.set("n", "<C-x>", "dd", opts)

-- Select all
vim.keymap.set("n", "<C-a>", "ggVG", opts)

-- write file in current directory
-- :w %:h/<new-file-name>
vim.keymap.set("n", "<C-n>", ":w %:h/", opts)

-- delete forward
-- w{number}dw
-- delete backward
-- w{number}db
