return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        xml = { "xmlformatter" },
        python = { "ruff_fix", "ruff_format" },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "xmlformatter" },
    },
  },
}
