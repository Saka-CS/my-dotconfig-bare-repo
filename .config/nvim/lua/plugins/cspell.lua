return {
  -- 1. Ensure the CSpell Language Server is installed via Mason
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "cspell-lsp")
    end,
  },

  -- 2. Configure the LSP Server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        cspell_ls = {
          -- This ensures the server starts for most programming files
          filetypes = {
            "javascript",
            "typescript",
            "lua",
            "python",
            "json",
            "markdown",
            "html",
            "css",
            "rust",
            "c",
            "cpp",
            "go",
            "yaml",
            "yaml.docker-compose",
            "yaml.gitlab",
            "yaml.helm-values",
          },
          settings = {
            cspell = {
              configFilePaths = { vim.fn.expand("~/.config/cspell/cspell.json") },
            },
          },
        },
      },
    },
  },
}
