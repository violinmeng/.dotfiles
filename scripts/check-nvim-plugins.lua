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
    local parsers = require("plugins.treesitter").languages
    for _, parser in ipairs(parsers) do
      assert(vim.treesitter.language.add(parser), "Missing parser: " .. parser)
    end
    print("Verified " .. #parsers .. " Treesitter parsers")
    -- Loading parser libraries alone misses query/directive API incompatibility.
    -- Parse injected languages and exercise the real highlighter on redraw.
    local samples = {
      markdown = { "# Test", "", "```lua", "local x = 1", "print(x)", "```",
        "", "```sh", "echo hello", "```", "", "Some **bold** and `inline` text." },
      html = { '<script type="module">const x = 1;</script>', '<div class="test">hello</div>' },
      lua = { "---@param value string", "local function greet(value)", "  return value", "end" },
      swift = { "func greet(name: String) -> String {", '  return "Hello, \\(name)"', "}" },
    }
    for language, lines in pairs(samples) do
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].filetype = language
      local parser = assert(vim.treesitter.get_parser(buf, language))
      parser:parse(true)
      if language == "markdown" then
        assert(parser:children().lua, "Markdown Lua injection was not parsed")
        assert(parser:children().bash, "Markdown shell injection was not parsed")
      end
      vim.treesitter.start(buf, language)
      vim.cmd.redraw()
      assert(vim.v.errmsg == "", vim.v.errmsg)
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    assert(vim.fn.maparg("af", "o") ~= "", "Function text object is missing")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "local function greet(first, second)", "  return first .. second", "end",
    })
    vim.bo[buf].filetype = "lua"
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
    assert(vim.api.nvim_get_mode().mode == "V", "Function text object did not select lines")
    vim.cmd.normal({ vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bang = true })
    vim.api.nvim_win_set_cursor(0, { 1, 22 })
    require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
    vim.api.nvim_feedkeys("", "x", false)
    assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "local function greet(second, first)",
      "Unexpected parameter swap result: " .. vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
    vim.api.nvim_buf_delete(buf, { force = true })
    print("Verified Markdown injections and HTML/Lua/Swift highlighting")
    print("Verified function text-object selection and parameter swapping")
  end
  print("Verified " .. #plugins .. " plugins and Telescope native fzf for " .. vim.env.NVIM_APPNAME)
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
