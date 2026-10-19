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
  local hipatterns = require("mini.hipatterns")
  assert(vim.o.termguicolors, "Hex colors require true color")
  assert(hipatterns.config.highlighters.hex_color, "Hex color highlighter is not configured")
  local color_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(color_buf)
  vim.api.nvim_buf_set_lines(color_buf, 0, -1, false, {
    'local colors = { "#FF8800", "#abcdef", "#nothex" }',
  })
  -- BufEnter enables the module on the next event-loop turn.
  assert(vim.wait(2000, function()
    return #hipatterns.get_matches(color_buf, { "hex_color" }) == 2
  end), "Hex colors were not highlighted in a normal buffer")
  local matches = hipatterns.get_matches(color_buf, { "hex_color" })
  assert(vim.api.nvim_get_hl(0, { name = matches[1].hl_group }).bg == 0xff8800,
    "Hex highlight does not match its color")
  vim.api.nvim_buf_set_lines(color_buf, 0, -1, false, { 'local color = "#00FF00"' })
  hipatterns.update(color_buf)
  assert(vim.wait(2000, function()
    local updated = hipatterns.get_matches(color_buf, { "hex_color" })
    return #updated == 1 and vim.api.nvim_get_hl(0, { name = updated[1].hl_group }).bg == 0x00ff00
  end), "Hex highlighting did not update after editing")
  vim.api.nvim_buf_delete(color_buf, { force = true })
  assert(vim.v.errmsg == "", vim.v.errmsg)
  print("Verified mini.hipatterns hex colors and updates")
  print("Verified " .. #plugins .. " plugins and Telescope native fzf for Kvim")
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
