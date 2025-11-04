

-- plugins/telescope.lua:
return {
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
	-- tag = '0.1.8',
	-- or, branch = '0.1.x',
    dependencies = {
		'nvim-lua/plenary.nvim',
		{'nvim-telescope/telescope-fzf-native.nvim', build = "make" },
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local telescope = require('telescope')
		local actions = require("telescope.actions")
		telescope.setup {
			defaults = {
    			path_display = { "truncate "},
				-- Default configuration for telescope goes here:
				-- config_key = value,
				mappings = {
					i = {
						["<Leader>t"] = actions.file_tab,  -- Leader + t 在新标签页中打开
						["<Leader>s"] = actions.file_vsplit,  -- Leader + t 在新标签页中打开
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
					n = {
						["<Leader>t"] = actions.file_tab,  -- Leader + t 在新标签页中打开
						["<Leader>s"] = actions.file_vsplit,  -- Leader + t 在新标签页中打开
					}
				}
			},
			pickers = {
				-- Default configuration for builtin pickers goes here:
				-- picker_name = {
				--   picker_config_key = value,
				--   ...
				-- }
				-- Now the picker_config_key will be applied every time you call this
				-- builtin picker
			},
			extensions = {
					fzf = {
						fuzzy = true,  -- 启用模糊匹配
						override_generic_sorter = true,  -- 覆盖默认排序器
						override_file_sorter = true,     -- 覆盖文件排序器
						case_mode = "smart_case",        -- 智能大小写匹配
					},
				-- Your extension configuration goes here:
				-- extension_name = {
				--   extension_config_key = value,
				-- }
				-- please take a look at the readme of the extension you want to configure
			}
		}
		telescope.load_extension("fzf")

		local keymap = vim.keymap
		keymap.set("n", "<Leader>fb", ":Telescope buffers<CR>", { desc = "Fuzzy find buffers" })
		keymap.set("n", "<Leader>fm", ":Telescope command_history<CR>", { desc = "Fuzzy find command history" })
		keymap.set("n", "<Leader>fh", ":Telescope help_tags<CR>", { desc = "Fuzzy find help tags" })
		keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<CR>", {desc = "Fuzz find files in cwd" })
		keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Fuzzy find recent files" })
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<CR>", { desc = "Find string in cwd" })
		keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<CR>", { desc = "Find string under cursor in cwd" })
	end,

}
-- End of telescope.lua