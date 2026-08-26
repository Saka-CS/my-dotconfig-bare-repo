return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      typos_lsp = {
        -- typos-lsp reports at Hint severity by default; Warning gives a
        -- more visible yellow undercurl
        init_options = { diagnosticSeverity = "Warning" },
        on_attach = function(client)
          local ns = vim.lsp.diagnostic.get_namespace(client.id)
          vim.diagnostic.config({
            virtual_text = false, -- no ● text at end of line
            signs = false, -- no gutter sign
            underline = true, -- keep the word underline
          }, ns)
        end,
      },
    },
  },
}
