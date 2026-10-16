local treesitter = require("nvim-treesitter")
local languages = {
  "bash", "c", "diff", "html", "lua", "luadoc", "swift",
  "markdown", "markdown_inline", "query", "vim", "vimdoc",
}

-- Keep managed parsers and queries ahead of legacy parser files on runtimepath.
treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
local installation = treesitter.install(languages)
if vim.env.DOTFILES_NVIM_INSTALL == "1" then
  assert(installation:wait(300000), "Treesitter parser installation failed")
end

local function attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang then return end
  if not vim.treesitter.get_parser(buf, lang, { error = false }) then
    if require("nvim-treesitter.parsers")[lang] then
      treesitter.install({ lang }):await(function(err, installed)
        if not err and installed then
          vim.schedule(function() attach(buf) end)
        end
      end)
    end
    return
  end
  vim.treesitter.start(buf, lang)
  if vim.bo[buf].filetype ~= "ruby" then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

-- Finish attaching buffers opened while first-run parser builds were in progress.
installation:await(function(err, installed)
  if err or not installed then return end
  vim.schedule(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then attach(buf) end
    end
  end)
end)

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("KvimTreesitter", { clear = true }),
  callback = function(event)
    attach(event.buf)
  end,
})

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v",
      ["@function.outer"] = "V",
      ["@class.outer"] = "<c-v>",
    },
    include_surrounding_whitespace = true,
  },
})

for key, capture in pairs({
  af = "@function.outer", ["if"] = "@function.inner",
  ac = "@class.outer", ic = "@class.inner", ["as"] = "@local.scope",
}) do
  vim.keymap.set({ "x", "o" }, key, function()
    require("nvim-treesitter-textobjects.select").select_textobject(
      capture, key == "as" and "locals" or "textobjects"
    )
  end, { desc = "Select " .. capture })
end
vim.keymap.set("n", "<leader>a", function()
  require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
end, { desc = "Swap next parameter" })
vim.keymap.set("n", "<leader>A", function()
  require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
end, { desc = "Swap previous parameter" })

return { languages = languages }
