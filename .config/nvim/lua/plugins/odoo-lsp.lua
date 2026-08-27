return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local function get_odoo_root(bufnr, on_dir)
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        local path = (buf_name and buf_name ~= "") and buf_name or vim.uv.cwd()

        local root = vim.fs.root(path, {
          ".odoo_lsp.json",
          ".odoo-lsp.json",
          ".odoo_lsp",
          ".odoo-lsp",
          "odools.toml",
          "odoo.conf",
          "odoo-bin",
        })

        if not root then
          local manifest = vim.fs.root(path, { "__manifest__.py", "__openerp__.py" })
          if manifest then
            root = vim.fs.root(manifest, ".git") or manifest
          end
        end

        if root and on_dir then
          on_dir(root)
        end
      end

      opts.servers.odoo_lsp = {
        cmd = { "odoo-lsp" },
        filetypes = { "python", "xml", "javascript" },
        root_dir = get_odoo_root,
        single_file_support = false,
        on_attach = function(client, _)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
      }
    end,
  },
}
