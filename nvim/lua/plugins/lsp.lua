return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      intelephense = {
        filetypes = { "php", "blade" },
        settings = {
          intelephense = {
            includeLanguages = {
              blade = "php", -- This tells Intelephense to treat blade as php
            },
          },
        },
      },
      phpactor = {
        filetypes = { "php", "blade" },
      },
    },
  },
}
