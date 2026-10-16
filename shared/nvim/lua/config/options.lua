-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- for ufo.nvim fold settings
-- vim.o.fillchars = 'eob: ,fold: ,foldopen:,foldsep: ,foldinner: ,foldclose:'
vim.o.fillchars = 'eob: ,fold: ,foldopen:,foldsep: ,foldclose:'

vim.g.have_nerd_font = true                             -- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.loaded_netrw = 1                                  -- disable netrw
vim.g.loaded_netrwPlugin = 1                            -- disable netrw
vim.g.mapleader = " "                                   -- change leader to a space
vim.g.maplocalleader = " "                              -- change localleader to a space

vim.o.backup = false                                  -- creates a backup file
vim.o.breakindent = true                              -- wrap lines with indent
vim.o.cmdheight = 1                                   -- more space in the neovim command line for displaying messages
vim.opt.completeopt = { "menu", "menuone", "noselect" } -- mostly just for cmp
vim.o.conceallevel = 0                                -- so that `` is visible in markdown files
vim.o.confirm = true                                  -- confirm to save changes before exiting modified buffer
vim.o.cursorline = true                               -- highlight the current line
vim.o.expandtab = true                                -- convert tabs to spaces
vim.o.fileencoding = "utf-8"                          -- the encoding written to a file
vim.opt.fillchars = { eob = " " } -- change the character at the end of buffer
vim.o.guifont = "monospace:h17" -- the font used in graphical neovim applications
vim.o.hlsearch = true                                 -- highlight all matches on previous search pattern
vim.o.ignorecase = true                               -- ignore case in search patterns
vim.o.inccommand = "split" -- Preview substitutions live, as you type!
vim.o.incsearch = true                                -- make search act like search in modern browsers
vim.o.mouse = "a"                                     -- allow the mouse to be used in neovim
vim.o.number = true                                   -- set numbered lines
vim.o.numberwidth = 4                                 -- set number column width to 2 {default 4}
vim.o.pumheight = 10                                  -- pop up menu height
vim.o.relativenumber = true                           -- set relative numbered lines
vim.o.ruler = true              -- Don't show the ruler
vim.o.shiftwidth = 2                                  -- the number of spaces inserted for each indentation
vim.o.showcmd = false           -- Don't show the command in the last line
vim.o.showmode = false                                -- we don't need to see things like -- INSERT -- anymore
vim.o.showtabline = 0                                 -- always show tabs
vim.o.scrolloff = 8                                   -- Makes sure there are always eight lines of context
vim.o.sidescrolloff = 8                               -- Makes sure there are always eight lines of context
vim.o.signcolumn = "yes:1"                                                 --  show the sign column, otherwise it would shift the text each time
vim.o.smartcase = true                                -- smart case
vim.o.smartindent = true                              -- make indenting smarter again
vim.o.splitbelow = true                               -- force all horizontal splits to go below current window
vim.o.splitright = true                               -- force all vertical splits to go to the right of current window
vim.o.swapfile = false                                -- creates a swapfile
vim.o.termguicolors = true                            -- set term gui colors (most terminals support this)
vim.o.timeoutlen = 1000                               -- time to wait for a mapped sequence to complete (in milliseconds)
vim.o.title = true              -- set the title of window to the value of the titlestring
vim.o.undodir = vim.fn.stdpath("data") .. "/undo"     -- set an undo directory
vim.o.undofile = true                                 -- enable persistent undo
vim.o.updatetime = 100                                -- faster completion (4000ms default)
vim.o.winborder = "single"      -- https://neovim.io/doc/user/options.html#'winborder'
vim.o.wrap = false                                    -- display lines as one long line
vim.o.writebackup = false                             -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited


-- vim.opt.winborder = "rounded" -- solid

-- vim.opt.guicursor = ""                          -- set the cursor to be a vertical bar

-- vim.opt.cursorlineopt = "number"              -- set the cursorline
-- vim.opt.tabstop = 2                           -- insert 2 spaces for a tab
-- vim.opt.laststatus = 0 -- Always display the status line

vim.filetype.add({
    extension = {
        env = "dotenv",
    },
    filename = {
        [".env"] = "dotenv",
        ["env"] = "dotenv",
    },
    pattern = {
        ["[jt]sconfig.*.json"] = "jsonc",
        ["%.env%.[%w_.-]+"] = "dotenv",
    },
})
