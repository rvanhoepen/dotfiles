local function normalize_path(file_path)
  return file_path:gsub("\\", "/")
end

local function is_vitest_file(file_path)
  local path = normalize_path(file_path)

  if path:match("/e2e/") or path:match("/componentTests/") then
    return false
  end

  return path:match("%.test%.js$") ~= nil
    or path:match("%.test%.jsx$") ~= nil
    or path:match("%.test%.ts$") ~= nil
    or path:match("%.test%.tsx$") ~= nil
    or path:match("%.spec%.js$") ~= nil
    or path:match("%.spec%.jsx$") ~= nil
    or path:match("%.spec%.ts$") ~= nil
    or path:match("%.spec%.tsx$") ~= nil
end

local function is_elixir_test_file(file_path)
  return normalize_path(file_path):match("_test%.exs$") ~= nil
end

local function is_pest_file(file_path)
  return normalize_path(file_path):match("/tests/.+Test%.php$") ~= nil
end

local function is_go_test_file(file_path)
  return normalize_path(file_path):match("_test%.go$") ~= nil
end

local function is_test_file(file_path)
  return is_vitest_file(file_path) or is_elixir_test_file(file_path) or is_pest_file(file_path) or is_go_test_file(file_path)
end

local function file_exists(file_path)
  return (vim.uv or vim.loop).fs_stat(file_path) ~= nil
end

local function template_path_for_test_file(file_path)
  local config_dir = vim.fn.stdpath("config")
  local path = normalize_path(file_path)

  if path:match("_test%.exs$") then
    return config_dir .. "/test-templates/elixir.exs"
  end

  if path:match("Test%.php$") then
    return config_dir .. "/test-templates/pest.php"
  end

  local extension = path:match("%.([^.]+)$")

  if extension and is_vitest_file(path) then
    return config_dir .. "/test-templates/vitest." .. extension
  end

  return nil
end

local function describe_name_for_source(source_file)
  local path = normalize_path(source_file)
  local relative_path = path:match("/src/(.+)$") or vim.fn.fnamemodify(path, ":t")

  return relative_path:gsub("/", " > ")
end

local function write_test_template(file_path, source_file)
  if file_exists(file_path) then
    return
  end

  local template_path = template_path_for_test_file(file_path)

  if not template_path or not file_exists(template_path) then
    return
  end

  local lines = vim.fn.readfile(template_path)
  local describe_name = describe_name_for_source(source_file)

  if vim.tbl_isempty(lines) then
    return
  end

  for index, line in ipairs(lines) do
    lines[index] = line:gsub("{{describe}}", describe_name)
  end

  vim.fn.writefile(lines, file_path)
end

local function vitest_candidates(source_file)
  local path = normalize_path(source_file)
  local root, relative_path, source_extension = path:match("^(.-)/src/(.+)%.([^/.]+)$")

  if not root or not relative_path then
    return {}
  end

  local candidates = {}
  local extensions_by_source = {
    js = { "js" },
    jsx = { "jsx" },
    ts = { "ts" },
    tsx = { "tsx" },
  }
  local extensions = extensions_by_source[source_extension] or { source_extension }

  for _, directory in ipairs({ "src", "tests" }) do
    for _, suffix in ipairs({ "test", "spec" }) do
      for _, extension in ipairs(extensions) do
        table.insert(candidates, string.format("%s/%s/%s.%s.%s", root, directory, relative_path, suffix, extension))
      end
    end
  end

  return candidates
end

local function elixir_candidates(source_file)
  local path = normalize_path(source_file)
  local root, relative_path = path:match("^(.-)/lib/(.+)%.ex$")

  if not root or not relative_path then
    return {}
  end

  local candidates = { string.format("%s/test/%s_test.exs", root, relative_path) }
  local stripped_relative_path = relative_path:match("^[^/]+/(.+)$")

  if stripped_relative_path then
    table.insert(candidates, string.format("%s/test/%s_test.exs", root, stripped_relative_path))
  end

  return candidates
end

local function pest_candidates(source_file)
  local path = normalize_path(source_file)
  local app_root, app_relative_path = path:match("^(.-)/app/(.+)%.php$")
  local src_root, src_relative_path = path:match("^(.-)/src/(.+)%.php$")

  if app_root and app_relative_path then
    return {
      string.format("%s/tests/Feature/%sTest.php", app_root, app_relative_path),
      string.format("%s/tests/Unit/%sTest.php", app_root, app_relative_path),
      string.format("%s/tests/%sTest.php", app_root, app_relative_path),
    }
  end

  if src_root and src_relative_path then
    return {
      string.format("%s/tests/%sTest.php", src_root, src_relative_path),
      string.format("%s/tests/Unit/%sTest.php", src_root, src_relative_path),
      string.format("%s/tests/Feature/%sTest.php", src_root, src_relative_path),
    }
  end

  return {}
end

local function go_candidates(source_file)
  local path = normalize_path(source_file)
  local directory, name = path:match("^(.+)/([^/]+)%.go$")

  if not directory or not name or name:match("_test$") then
    return {}
  end

  return {
    string.format("%s/%s_test.go", directory, name),
    string.format("%s/tests/%s_test.go", directory, name),
  }
end

local function related_test_candidates(source_file)
  local candidates = {}

  vim.list_extend(candidates, vitest_candidates(source_file))
  vim.list_extend(candidates, elixir_candidates(source_file))
  vim.list_extend(candidates, pest_candidates(source_file))
  vim.list_extend(candidates, go_candidates(source_file))

  return candidates
end

local function related_test_file(source_file)
  for _, candidate in ipairs(related_test_candidates(source_file)) do
    if file_exists(candidate) then
      return candidate
    end
  end

  return nil
end

local function clean_output_panel()
  local ok, neotest = pcall(require, "neotest")

  if not ok or not neotest.output_panel then
    return
  end

  local buffer_ok, output_buffer = pcall(neotest.output_panel.buffer)

  if not buffer_ok or not vim.api.nvim_buf_is_valid(output_buffer) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(output_buffer, 0, -1, false)
  local last_line = #lines

  while last_line > 1 and lines[last_line]:match("^%s*$") do
    last_line = last_line - 1
  end

  if last_line < #lines then
    pcall(vim.api.nvim_set_option_value, "modifiable", true, { buf = output_buffer })
    pcall(vim.api.nvim_buf_set_lines, output_buffer, last_line, -1, false, {})
    pcall(vim.api.nvim_set_option_value, "modifiable", false, { buf = output_buffer })
  end

  for _, window in ipairs(vim.fn.win_findbuf(output_buffer)) do
    if vim.api.nvim_win_is_valid(window) then
      pcall(vim.api.nvim_win_set_cursor, window, { math.max(last_line, 1), 0 })
      pcall(vim.api.nvim_win_call, window, function()
        vim.cmd("normal! zb")
      end)
    end
  end
end

local function schedule_output_panel_cleanup()
  for _, delay in ipairs({ 50, 250, 750 }) do
    vim.defer_fn(clean_output_panel, delay)
  end
end

local function run_neotest_file(file)
  local neotest = require("neotest")
  local previous_window = vim.api.nvim_get_current_win()

  vim.notify("Running " .. vim.fn.fnamemodify(file, ":~:."), vim.log.levels.INFO)
  neotest.output_panel.clear()
  clean_output_panel()
  neotest.run.run(file)
  neotest.output_panel.open()
  schedule_output_panel_cleanup()

  local output_buffer = neotest.output_panel.buffer()
  local output_windows = vim.fn.win_findbuf(output_buffer)

  if output_windows[1] then
    vim.api.nvim_set_current_win(output_windows[1])
    vim.keymap.set("n", "q", function()
      neotest.output_panel.close()

      if vim.api.nvim_win_is_valid(previous_window) then
        vim.api.nvim_set_current_win(previous_window)
      end
    end, { buffer = output_buffer, nowait = true })
  end
end

local function run_test_file_or_related()
  local file = vim.fn.expand("%:p")

  if is_test_file(file) then
    run_neotest_file(file)
    return
  end

  local test_file = related_test_file(file)

  if test_file then
    run_neotest_file(test_file)
    return
  end

  vim.notify("No related test file found", vim.log.levels.WARN)
end

local function edit_related_test_file()
  local file = vim.fn.expand("%:p")

  if is_test_file(file) then
    vim.cmd.edit(vim.fn.fnameescape(file))
    return
  end

  local test_file = related_test_file(file)

  if test_file then
    vim.cmd.edit(vim.fn.fnameescape(test_file))
    return
  end

  local candidates = related_test_candidates(file)

  if vim.tbl_isempty(candidates) then
    vim.notify("No related test file found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(candidates, { prompt = "Create related test file:" }, function(choice)
    if not choice then
      return
    end

    vim.fn.mkdir(vim.fn.fnamemodify(choice, ":h"), "p")
    write_test_template(choice, file)
    vim.cmd.edit(vim.fn.fnameescape(choice))
  end)
end

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "marilari88/neotest-vitest",
      "V13Axel/neotest-pest",
      "jfpedroza/neotest-elixir",
      "fredrikaverpil/neotest-golang",
    },
    opts = function()
      local vitest = require("neotest-vitest")({
        filter_dir = function(name)
          return not vim.tbl_contains({ "node_modules", "e2e", "componentTests", "dist", "coverage" }, name)
        end,
      })

      vitest.is_test_file = is_vitest_file

      return {
        output = {
          open_on_run = false,
        },
        output_panel = {
          open = "botright split | resize 15",
        },
        consumers = {
          related_test_output_cleanup = function(client)
            client.listeners.results = function(_, _, partial)
              if not partial then
                schedule_output_panel_cleanup()
              end
            end
          end,
        },
        adapters = {
          require("neotest-pest")({
            pest_cmd = "vendor/bin/pest",
          }),
          require("neotest-elixir")({
            mix_task = "test",
          }),
          require("neotest-golang")({}),
          vitest,
        },
      }
    end,
    keys = {
      { "<leader>tR", run_test_file_or_related, desc = "Run Related Test" },
      { "<leader>tG", edit_related_test_file, desc = "Go to Related Test" },
    },
  },
}
