-- Run after the real profile's init.lua. Startup errors must fail installation.
local ok, err = pcall(function()
  assert(vim.v.errmsg == "", vim.v.errmsg)
  local plugins = vim.pack.get()
  assert(#plugins > 0, "No plugins were installed by this profile")
  for _, plugin in ipairs(plugins) do
    assert(vim.fn.isdirectory(plugin.path) == 1, "Missing plugin: " .. plugin.spec.name)
  end
  local fzf = vim.pack.get({ "telescope-fzf-native.nvim" })[1]
  assert(fzf and vim.fn.filereadable(fzf.path .. "/build/libfzf.so") == 1,
    "Telescope's native fzf build is missing")
  require("telescope").load_extension("fzf")
  assert(require("fzf_lib"), "Native fzf library did not load")
  if vim.env.NVIM_APPNAME == "kvim" then
    local parsers = require("nvim-treesitter.configs").get_ensure_installed_parsers()
    for _, parser in ipairs(parsers) do
      assert(vim.treesitter.language.add(parser), "Missing parser: " .. parser)
    end
    print("Verified " .. #parsers .. " Treesitter parsers")
  end
  print("Verified " .. #plugins .. " plugins and Telescope native fzf for " .. vim.env.NVIM_APPNAME)
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
