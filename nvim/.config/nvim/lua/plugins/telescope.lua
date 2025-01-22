
return	{
	"nvim-telescope/telescope-fzf-native.nvim",
	dependencies = { "nvim-telescope/telescope.nvim" },  -- 依赖 Telescope
	build = "make",  -- 编译原生扩展
	config = function()
		local actions = require('telescope.actions')
		require("telescope").setup({
			defaults = {
				file_ignore_patterns = { "node_modules", ".git" },
				mappings = {
					i = {
						["<Leader>t"] = actions.file_tab,  -- Leader + t 在新标签页中打开
						["<Leader>s"] = actions.file_vsplit,  -- Leader + t 在新标签页中打开
					},
					n = {
						["<Leader>t"] = actions.file_tab,  -- Leader + t 在新标签页中打开
						["<Leader>s"] = actions.file_vsplit,  -- Leader + t 在新标签页中打开
					},
				},
			},
			extensions = {
				fzf = {
					fuzzy = true,  -- 启用模糊匹配
					override_generic_sorter = true,  -- 覆盖默认排序器
					override_file_sorter = true,     -- 覆盖文件排序器
					case_mode = "smart_case",        -- 智能大小写匹配
				},
			},
		})
		-- 加载 fzf 扩展
		require("telescope").load_extension("fzf")
	end
}
