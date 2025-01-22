
-- NORMAL MODE
vim.keymap.set('n', '0', '$')
vim.keymap.set('n', '1', '^')
vim.keymap.set('n', '2', '0')
vim.keymap.set('n', '5', '%')
-- 将后退映射为 <Leader>b
vim.keymap.set('n', '<Leader>b', '<C-o>')
-- 将前进映射为 <Leader>f
vim.keymap.set('n', '<Leader>B', '<C-i>')
vim.keymap.set('n', '<Leader>e', ':NvimTreeToggle<CR>')
-- 映射 <Leader>f 为 *
vim.keymap.set('n', '<Leader>f', '*')
-- 映射 <Leader>F 为 #
vim.keymap.set('n', '<Leader>F', '#')
-- 查找缓冲区
vim.keymap.set("n", "<Leader>fb", ":Telescope buffers<CR>")
-- 查找命令历史
vim.keymap.set("n", "<Leader>fc", ":Telescope command_history<CR>")
-- 查找文件
vim.keymap.set("n", "<Leader>ff", ":Telescope find_files<CR>")
-- 查找文本
vim.keymap.set("n", "<Leader>fg", ":Telescope live_grep<CR>")
-- 查找帮助
vim.keymap.set("n", "<Leader>fh", ":Telescope help_tags<CR>")
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


