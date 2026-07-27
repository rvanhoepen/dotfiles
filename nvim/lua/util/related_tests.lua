local M = {}

local function normalize_path(file_path)
  return file_path:gsub("\\", "/")
end

function M.is_vitest_file(file_path)
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

local function is_test_file(file_path)
  local path = normalize_path(file_path)

  return M.is_vitest_file(path)
    or path:match("_test%.exs$") ~= nil
    or path:match("/tests/.+Test%.php$") ~= nil
    or path:match("_test%.go$") ~= nil
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

  if extension and M.is_vitest_file(path) then
    return config_dir .. "/test-templates/vitest." .. extension
  end
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

  if vim.tbl_isempty(lines) then
    return
  end

  local describe_name = describe_name_for_source(source_file)
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

local function candidates(source_file)
  local paths = {}

  vim.list_extend(paths, vitest_candidates(source_file))
  vim.list_extend(paths, elixir_candidates(source_file))
  vim.list_extend(paths, pest_candidates(source_file))
  vim.list_extend(paths, go_candidates(source_file))

  return paths
end

local function find(source_file)
  for _, candidate in ipairs(candidates(source_file)) do
    if file_exists(candidate) then
      return candidate
    end
  end
end

function M.resolve(file_path)
  return is_test_file(file_path) and file_path or find(file_path)
end

function M.edit()
  local file = vim.fn.expand("%:p")
  local test_file = M.resolve(file)

  if test_file then
    vim.cmd.edit(vim.fn.fnameescape(test_file))
    return
  end

  local choices = candidates(file)

  if vim.tbl_isempty(choices) then
    vim.notify("No related test file found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(choices, { prompt = "Create related test file:" }, function(choice)
    if not choice then
      return
    end

    vim.fn.mkdir(vim.fn.fnamemodify(choice, ":h"), "p")
    write_test_template(choice, file)
    vim.cmd.edit(vim.fn.fnameescape(choice))
  end)
end

return M
