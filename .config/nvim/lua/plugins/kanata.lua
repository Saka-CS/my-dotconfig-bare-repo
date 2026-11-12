-- Kanata config support: kanata-ls (lint + format + navigation) and treesitter.
-- The LSP is built from https://github.com/rszyma/vscode-kanata (kanata-ls/).

-- Upstream tree-sitter-kanata query bug: predicates are evaluated in very-magic
-- mode, where a bare `@` is invalid ("E866: Misplaced @"). Escape it as \@ and
-- explicitly select very-magic mode so the alias pattern still matches.
local function patch_kanata_highlight_query()
  local files = vim.treesitter.query.get_files("kanata", "highlights")
  if not files or #files == 0 then
    return
  end
  local chunks = {}
  for _, file in ipairs(files) do
    local ok, lines = pcall(vim.fn.readfile, file)
    if ok then
      chunks[#chunks + 1] = table.concat(lines, "\n")
    end
  end
  local patched = table.concat(chunks, "\n"):gsub('"@%.%+"', '"\\\\v\\\\@.+"')
  pcall(vim.treesitter.query.set, "kanata", "highlights", patched)
end

patch_kanata_highlight_query()

vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").kanata = {
      install_info = {
        url = "https://github.com/postsolar/tree-sitter-kanata",
        branch = "master",
        queries = "queries",
      },
    }
    patch_kanata_highlight_query()
  end,
})

-- LazyVim/conform only format on save when an external formatter is configured
-- for the filetype, so wire the LSP formatter for kanata up directly.
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.kbd",
  callback = function(args)
    if #vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" }) == 0 then
      return
    end
    vim.lsp.buf.format({ bufnr = args.buf, async = false, timeout_ms = 3000 })
  end,
  desc = "Format Kanata config with kanata-ls",
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        kanata_ls = {
          cmd = { vim.fn.expand("~/.local/bin/kanata-ls") },
          filetypes = { "kanata" },
          root_markers = { "config.kbd", "kanata.kbd", ".git" },
          -- kanata-ls deserializes init_options into a struct with no defaults:
          -- every field below is required, and envVariables must be an object.
          init_options = {
            includesAndWorkspaces = "single",
            mainConfigFile = "config.kbd",
            localKeysVariant = "deflocalkeys-linux",
            format = {
              enable = true,
              useDefsrcLayoutOnDeflayers = true,
            },
            envVariables = vim.empty_dict(),
            dimInactiveConfigItems = true,
          },
        },
      },
    },
  },
}
