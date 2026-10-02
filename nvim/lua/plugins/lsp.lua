local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      ["*"] = {
        capabilities = capabilities,
      },
      gopls = {
        init_options = {
          semanticTokens = true,
        },
      },
      vtsls = {
        settings = {
          typescript = {
            inlayHints = {
              variableTypes = { enabled = true },
            },
          },
        },
      },
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
