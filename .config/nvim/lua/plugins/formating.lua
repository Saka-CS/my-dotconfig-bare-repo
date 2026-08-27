return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      -- 1. Python: Fast AST fix + formatting
      opts.formatters_by_ft.python = { "ruff_fix", "ruff_format" }

      -- 2. XML: Try prettier first (if plugin available), fallback to xmlformatter (Mason)
      opts.formatters_by_ft.xml = { "prettier", "xmlformatter", stop_after_first = true }

      -- 3. Web & Config files
      opts.formatters_by_ft.javascript = { "prettier" }
      opts.formatters_by_ft.javascriptreact = { "prettier" }
      opts.formatters_by_ft.typescript = { "prettier" }
      opts.formatters_by_ft.typescriptreact = { "prettier" }
      opts.formatters_by_ft.json = { "prettier" }
      opts.formatters_by_ft.jsonc = { "prettier" }
      opts.formatters_by_ft.yaml = { "prettier" }
      opts.formatters_by_ft.css = { "prettier" }
      opts.formatters_by_ft.scss = { "prettier" }

      -- Helper to find @prettier/plugin-xml in local project node_modules or Mason
      local function get_prettier_xml_plugin(bufnr)
        local buf_path = vim.api.nvim_buf_get_name(bufnr or 0)
        local search_dir = (buf_path and buf_path ~= "") and vim.fs.dirname(buf_path) or vim.fn.getcwd()

        -- 1. Check local project node_modules
        local local_plugin = vim.fs.find({ "node_modules/@prettier/plugin-xml" }, {
          path = search_dir,
          upward = true,
        })[1]
        if local_plugin and (vim.fn.isdirectory(local_plugin) == 1 or vim.fn.filereadable(local_plugin .. "/src/plugin.js") == 1) then
          return local_plugin
        end

        -- 2. Check Mason installation
        local mason_prettier_pkg = vim.fn.stdpath("data") .. "/mason/packages/prettier"
        local mason_xml_plugin = mason_prettier_pkg .. "/node_modules/@prettier/plugin-xml"
        if vim.fn.isdirectory(mason_xml_plugin) == 1 or vim.fn.filereadable(mason_xml_plugin .. "/src/plugin.js") == 1 then
          return mason_xml_plugin
        end

        return nil
      end

      -- Context-aware Prettier configuration (avoids polluting JSON/YAML)
      opts.formatters.prettier = {
        condition = function(self, ctx)
          local ft = vim.bo[ctx.buf].filetype
          if ft == "xml" then
            return get_prettier_xml_plugin(ctx.buf) ~= nil
          end
          return true
        end,
        prepend_args = function(self, ctx)
          local args = {}
          local ft = vim.bo[ctx.buf].filetype

          if ft == "xml" then
            table.insert(args, "--tab-width")
            table.insert(args, "4")
            table.insert(args, "--xml-whitespace-sensitivity")
            table.insert(args, "preserve")
            table.insert(args, "--bracket-same-line")

            local plugin_path = get_prettier_xml_plugin(ctx.buf)
            if plugin_path then
              table.insert(args, "--plugin")
              table.insert(args, plugin_path)
            end
          elseif ft == "javascript" or ft == "javascriptreact" then
            table.insert(args, "--tab-width")
            table.insert(args, "4")
          end

          return args
        end,
      }

      -- Configure fallback xmlformatter (installed via Mason) for Odoo 4-space indent
      opts.formatters.xmlformatter = {
        prepend_args = { "--indent", "4", "--eof-newline" },
      }
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "ruff", "prettier", "xmlformatter" })
    end,
  },
}
