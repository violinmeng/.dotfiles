
return {
	'akinsho/bufferline.nvim',
	version = "*",
	dependencies = 'nvim-tree/nvim-web-devicons',
	config = function ()
		require("bufferline").setup{
			options = {
				mode = "tabs",  -- 显示 Tabs 而不是 Buffers
			},
		}
	end
}
