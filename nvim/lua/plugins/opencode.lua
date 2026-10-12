local opencode_cmd = "opencode"

local terminal_opts = {
  win = {
    position = "right",
    enter = false,
  },
}

return {
  {
    "nickjvandyke/opencode.nvim",
    -- Use main branch for OpenCode v2
    dependencies = {
      {
        "folke/snacks.nvim",
        optional = true,
        opts = {
          input = {},
          picker = {
            actions = {
              opencode_send = function(picker)
                local items = vim.tbl_map(function(item)
                  return item.file
                      and require("opencode").format({
                        path = item.file,
                        from = item.pos,
                        to = item.end_pos,
                      })
                    or item.text
                end, picker:selected({ fallback = true }))

                require("opencode").prompt(table.concat(items, ", ") .. " ")
              end,
            },
            win = {
              input = {
                keys = {
                  ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
                },
              },
            },
          },
        },
      },
    },

    init = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        server = {
          start = function()
            require("snacks.terminal").open(opencode_cmd, terminal_opts)
          end,
        },
      }

      vim.o.autoread = true

      vim.keymap.set("n", "+", "<C-a>", {
        desc = "Increment under cursor",
        noremap = true,
      })

      vim.keymap.set("n", "-", "<C-x>", {
        desc = "Decrement under cursor",
        noremap = true,
      })
    end,

    keys = {
      {
        "<C-a>",
        function()
          require("opencode").ask("@this: ")
        end,
        mode = { "n", "x" },
        desc = "Ask OpenCode",
      },
      {
        "<C-x>",
        function()
          require("opencode").select()
        end,
        mode = { "n", "x" },
        desc = "Execute OpenCode action",
      },
      {
        "<C-.>",
        function()
          require("snacks.terminal").toggle(opencode_cmd, terminal_opts)
        end,
        mode = { "n", "t" },
        desc = "Toggle OpenCode",
      },
      {
        "go",
        function()
          return require("opencode").operator("@this ")
        end,
        mode = { "n", "x" },
        expr = true,
        desc = "Add range to OpenCode",
      },
      {
        "goo",
        function()
          return require("opencode").operator("@this ") .. "_"
        end,
        expr = true,
        desc = "Add line to OpenCode",
      },
      {
        "<S-C-u>",
        function()
          require("opencode").command("session.half.page.up")
        end,
        desc = "Scroll OpenCode up",
      },
      {
        "<S-C-d>",
        function()
          require("opencode").command("session.half.page.down")
        end,
        desc = "Scroll OpenCode down",
      },
    },
  },
}
