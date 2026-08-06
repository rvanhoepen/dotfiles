return {
  {
    "vuki656/package-info.nvim",
    lazy = false,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      autostart = true,
    },
    keys = {
      { "<leader>np", "<cmd>PackageInfoToggle<cr>", desc = "Toggle Package Versions" },
      { "<leader>nu", "<cmd>PackageInfoUpdate<cr>", desc = "Update Package" },
    },
  },
}
