local conform = require("conform")

conform.setup({
  notify_on_error = false,
  format_on_save = function(bufnr)
    local disabled = { c = true, cpp = true }
    if disabled[vim.bo[bufnr].filetype] then
      return nil
    end

    return {
      timeout_ms = 500,
      lsp_format = "fallback",
    }
  end,
  formatters = {},
  formatters_by_ft = {
    lua = { "stylua" },
    swift = vim.fn.executable("swiftformat") == 1 and { "swiftformat" } or {},
  },
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
  conform.format({ async = true, lsp_format = "fallback" })
end, { desc = "[F]ormat buffer" })
