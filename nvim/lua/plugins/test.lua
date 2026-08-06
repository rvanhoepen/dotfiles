local related_tests = require("util.related_tests")

local function clean_output_panel(results)
  local ok, neotest = pcall(require, "neotest")

  if not ok or not neotest.output_panel then
    return
  end

  local buffer_ok, output_buffer = pcall(neotest.output_panel.buffer)

  if not buffer_ok or not vim.api.nvim_buf_is_valid(output_buffer) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(output_buffer, 0, -1, false)
  local has_output = vim.iter(lines):any(function(line)
    return line:match("%S") ~= nil
  end)

  if not has_output and results then
    local fallback = {}

    for _, result in pairs(results) do
      if result.status == "failed" and result.output and vim.fn.filereadable(result.output) == 1 then
        local result_lines = vim.fn.readfile(result.output)

        if #result_lines > #fallback then
          fallback = result_lines
        end
      end
    end

    if #fallback > 0 then
      pcall(vim.api.nvim_set_option_value, "modifiable", true, { buf = output_buffer })
      pcall(vim.api.nvim_buf_set_lines, output_buffer, 0, -1, false, fallback)
      pcall(vim.api.nvim_set_option_value, "modifiable", false, { buf = output_buffer })
      lines = fallback
    end
  end

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

local function run_neotest_file(file)
  local neotest = require("neotest")
  local previous_window = vim.api.nvim_get_current_win()

  vim.notify("Running " .. vim.fn.fnamemodify(file, ":~:."), vim.log.levels.INFO)
  neotest.output_panel.clear()
  clean_output_panel()
  neotest.run.run(file)
  neotest.output_panel.open()

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
  local position = related_tests.resolve_position(file, vim.api.nvim_win_get_cursor(0)[1] - 1)

  if position then
    run_neotest_file(position)
    return
  end

  vim.notify("No related test file found", vim.log.levels.WARN)
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

      vitest.is_test_file = related_tests.is_vitest_file

      return {
        output = {
          open_on_run = false,
        },
        output_panel = {
          open = "botright split | resize 15",
        },
        consumers = {
          related_test_output_cleanup = function(client)
            client.listeners.results = function(_, results, partial)
              if not partial then
                vim.schedule(function()
                  clean_output_panel(results)
                end)
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
      {
        "<leader>tt",
        function()
          local neotest = require("neotest")
          neotest.run.run(vim.fn.expand("%"))
          neotest.output_panel.open()
        end,
        desc = "Run File (Neotest)",
      },
      {
        "<leader>tT",
        function()
          local neotest = require("neotest")
          neotest.run.run(vim.uv.cwd())
          neotest.output_panel.open()
        end,
        desc = "Run All Test Files (Neotest)",
      },
      {
        "<leader>tr",
        function()
          local neotest = require("neotest")
          neotest.run.run()
          neotest.output_panel.open()
        end,
        desc = "Run Nearest (Neotest)",
      },
      {
        "<leader>tl",
        function()
          local neotest = require("neotest")
          neotest.run.run_last()
          neotest.output_panel.open()
        end,
        desc = "Run Last (Neotest)",
      },
      { "<leader>tR", run_test_file_or_related, desc = "Run Related Test" },
      { "<leader>tG", related_tests.edit, desc = "Go to Related Test" },
    },
  },
}
