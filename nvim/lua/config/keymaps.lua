-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function send_to_claude()
  local s, e = vim.fn.line("v"), vim.fn.line(".")
  if s > e then
    s, e = e, s
  end
  local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
  local file = vim.fn.expand("%:.")
  local text = string.format("%s:%d-%d\n```\n%s\n```\n", file, s, e, table.concat(lines, "\n"))

  vim.fn.system({ "tmux", "load-buffer", "-b", "claude", "-" }, text)
  vim.fn.system({ "tmux", "paste-buffer", "-p", "-d", "-b", "claude", "-t", "{down-of}" })
  vim.fn.system({ "tmux", "select-pane", "-t", "{down-of}" }) -- Delete to stay in Neovim.

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end

vim.keymap.set("v", "<leader>as", send_to_claude, { desc = "Send selection to Claude" })
