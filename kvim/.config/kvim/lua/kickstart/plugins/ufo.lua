-- lazy.nvim 或 Packer 配置
return {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    config = function()
        vim.o.foldcolumn = '1' -- 显示折叠标记列
        vim.o.foldlevel = 99
        vim.o.foldlevelstart = 99
        vim.o.foldenable = true

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities.textDocument.foldingRange = {
            dynamicRegistration = false,
            lineFoldingOnly = true
        }
        local language_servers = vim.lsp.get_clients() -- or list servers manually like {'gopls', 'clangd'}
        for _, ls in ipairs(language_servers) do
            require('lspconfig')[ls].setup({
                capabilities = capabilities
                -- you can add other fields for setting up lsp server in this table
            })
        end
        require('ufo').setup()

        -- 启动 ufo
        -- require('ufo').setup({
        --     provider_selector = function(bufnr, filetype, buftype)
        --         -- 优先用 LSP，没支持的话使用 treesitter，否则回退缩进折叠
        --         return { 'lsp', 'treesitter' }
        --     end,
            -- 可选：美化折叠的标题
            -- fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
            --     local newVirtText = {}
            --     local suffix = ('  %d '):format(endLnum - lnum)
            --     local sufWidth = vim.fn.strdisplaywidth(suffix)
            --     local targetWidth = width - sufWidth
            --     local curWidth = 0
            --     for _, chunk in ipairs(virtText) do
            --         local chunkText, hlGroup = chunk[1], chunk[2]
            --         local chunkWidth = vim.fn.strdisplaywidth(chunkText)
            --         if targetWidth > curWidth + chunkWidth then
            --             table.insert(newVirtText, chunk)
            --             curWidth = curWidth + chunkWidth
            --         else
            --             chunkText = truncate(chunkText, targetWidth - curWidth)
            --             table.insert(newVirtText, { chunkText, hlGroup })
            --             break
            --         end
            --     end
            --     table.insert(newVirtText, { suffix, 'MoreMsg' })
            --     return newVirtText
            -- end,
        -- })

        -- require('ufo').setup({
        --   provider_selector = function(bufnr, filetype, buftype)
        --     -- return { 'lsp', 'treesitter', 'indent' }
        --      return {'treesitter', 'indent'}
        --   end
        -- })
    end
}
