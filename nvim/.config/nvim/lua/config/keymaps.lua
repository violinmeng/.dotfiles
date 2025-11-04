
-- NORMAL MODE
vim.keymap.set('n', '0', '$')
vim.keymap.set('n', '1', '^')
vim.keymap.set('n', '2', '0')
vim.keymap.set('n', '5', '%')
-- 映射 - 为水平分割窗口
vim.keymap.set('n', '-', ':split<CR>')
-- 映射 | 为垂直分割窗口
vim.keymap.set('n', '|', ':vsplit<CR>')
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

-- 窗口切换快捷键
vim.keymap.set('n', '<M-j>', '<C-W>j')  -- 切换到下方窗口
vim.keymap.set('n', '<M-k>', '<C-W>k')  -- 切换到上方窗口
vim.keymap.set('n', '<M-h>', '<C-W>h')  -- 切换到左侧窗口
vim.keymap.set('n', '<M-l>', '<C-W>l')  -- 切换到右侧窗口

vim.keymap.set('n', '<M-Tab>', ':tabnext<CR>') -- CTRL-Tab 切换到下一个 Tab
vim.keymap.set('n', '<M-S-Tab>', ':tabprevious<CR>')

-- VISUAL 可视模式下，映射 <Leader>y 为复制到系统剪贴板
vim.keymap.set('v', '0', '$')
vim.keymap.set('v', '1', '^')
vim.keymap.set('v', '2', '0')
vim.keymap.set('v', '5', '%')
vim.keymap.set('v', '<Leader>y', '"+y')

-- INSERT MODE
vim.keymap.set('i', '<M-Tab>', '<C-\\><C-N>:tabnext<CR>') -- CTRL-Tab 切换到下一个 Tab
vim.keymap.set('i', '<M-S-Tab>', '<C-\\><C-N>:tabprevious<CR>')

-- COMMAND MODE
-- vim.keymap.set('c', '<Tab>', '<C-C>:tabnext<CR>') -- CTRL-SHIFT-Tab 切换到上一个 Tab
-- vim.keymap.set('c', '<S-Tab>', '<C-C>:tabprevious<CR>')

-- TERMINAL MODE

-- vim.keymap.set('t', '<Leader>th', '<C-\\><C-N>:hide<CR>') -- 隐藏终端
vim.keymap.set('t', '<M-h>', '<C-\\><C-N><C-w>h')
vim.keymap.set('t', '<M-j>', '<C-\\><C-N><C-w>j')
vim.keymap.set('t', '<M-k>', '<C-\\><C-N><C-w>k')
vim.keymap.set('t', '<M-l>', '<C-\\><C-N><C-w>l')


-- COPY FROM https://github.com/adibhanna/nvim/tree/main
-- Learn and think why and how these works
local opts = { noremap = true, silent = true }
-- local map = vim.keymap.set

-- Keep cursor centered when scrolling
-- vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
-- vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)
--
-- Move selected line / block of text in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", opts)

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
vim.keymap.set("n", "+", ":vertical resize +5<CR>")
vim.keymap.set("n", "_", ":vertical resize -5<CR>")
vim.keymap.set("n", "=", ":resize +5<CR>")
vim.keymap.set("n", "-", ":resize -5<CR>")

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

vim.keymap.set("n", "<C-P>", ':lua require("config.utils").toggle_go_test()<CR>', opts)

-- Get highlighted line numbers in visual mode
vim.keymap.set("v", "<leader>ln", ':lua require("config.utils").get_highlighted_line_numbers()<CR>', opts)

vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", opts)