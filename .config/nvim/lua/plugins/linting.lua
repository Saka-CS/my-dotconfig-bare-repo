return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.python = { "pylint" }
      opts.linters_by_ft.xml = { "xmllint" }

      -- Performance: Run heavy AST linters on save and read (avoids lag on typing events like InsertLeave)
      opts.events = { "BufWritePost", "BufReadPost" }

      local function get_pylint_bin(buf_path)
        local path = (buf_path and buf_path ~= "") and vim.fs.dirname(buf_path) or vim.fn.getcwd()

        local venv_pylint = vim.fs.find({ ".venv/bin/pylint", "venv/bin/pylint" }, {
          upward = true,
          path = path,
        })[1]
        if venv_pylint and vim.fn.executable(venv_pylint) == 1 then
          return venv_pylint
        end

        local venv_env = os.getenv("VIRTUAL_ENV")
        if venv_env then
          local p = venv_env .. "/bin/pylint"
          if vim.fn.executable(p) == 1 then
            return p
          end
        end

        return vim.fn.executable("pylint") == 1 and "pylint" or nil
      end

      opts.linters = opts.linters or {}

      -- 1. Define custom xmllint with warning vs error parsing
      opts.linters.xmllint = {
        name = "xmllint",
        cmd = "xmllint",
        stdin = true,
        stream = "stderr",
        ignore_exitcode = true,
        args = { "--noout", "-" },
        condition = function()
          return vim.fn.executable("xmllint") == 1
        end,
        parser = function(output, bufnr)
          if not output or output == "" then
            return {}
          end
          local diagnostics = {}
          local pattern = "^[^:]+:(%d+):%s*(.-)%s*:%s*(.*)$"
          for line in output:gmatch("[^\r\n]+") do
            local lnum, err_type, message = line:match(pattern)
            if lnum and message then
              local is_warn = err_type and err_type:lower():find("warning") ~= nil
              table.insert(diagnostics, {
                bufnr = bufnr,
                lnum = math.max(0, tonumber(lnum) - 1),
                col = 0,
                severity = is_warn and vim.diagnostic.severity.WARN or vim.diagnostic.severity.ERROR,
                message = vim.trim(message),
                source = "xmllint",
              })
            end
          end
          return diagnostics
        end,
      }

      -- 2. Configure pylint for Odoo AST linting on saved files
      opts.linters.pylint = {
        cmd = function()
          local buf_name = vim.api.nvim_buf_get_name(0)
          return get_pylint_bin(buf_name) or "pylint"
        end,

        -- Run directly against saved file on disk so Pylint resolves module hierarchy
        stdin = false,

        -- args must be an array of strings or functions returning strings in nvim-lint
        args = {
          "-f",
          "json",
          "-d",
          "manifest-required-author,manifest-required-key",
          function()
            local buf_name = vim.api.nvim_buf_get_name(0)
            local path = (buf_name ~= "") and vim.fs.dirname(buf_name) or vim.fn.getcwd()
            local rcfile = vim.fs.find({ ".pylintrc", "pylintrc" }, {
              upward = true,
              path = path,
            })[1]
            return rcfile and ("--rcfile=" .. rcfile) or "--score=no"
          end,
        },

        condition = function(ctx)
          if not ctx.filename or ctx.filename == "" then
            return false
          end
          local has_config = vim.fs.find({ ".pylintrc", ".odoo_lsp.json", "odoo.conf", "pyproject.toml" }, {
            path = vim.fs.dirname(ctx.filename),
            upward = true,
          })[1] ~= nil
          return has_config and get_pylint_bin(ctx.filename) ~= nil
        end,
      }
    end,
  },
}
