return {
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    ft = "python",
    config = function()
      local dap = require("dap")
      local dap_python = require("dap-python")

      -- 1. Resolve Python interpreter for debugpy adapter host
      local function get_debugpy_host()
        local mason_debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
        if vim.fn.executable(mason_debugpy) == 1 then
          return mason_debugpy
        end
        local venv_py = vim.fn.getcwd() .. "/.venv/bin/python"
        if vim.fn.executable(venv_py) == 1 then
          return venv_py
        end
        return "python3"
      end

      -- 2. Resolve Python interpreter for target project runtime
      local function get_target_python()
        local venv_py = vim.fn.getcwd() .. "/.venv/bin/python"
        if vim.fn.executable(venv_py) == 1 then
          return venv_py
        end
        return vim.env.VIRTUAL_ENV and (vim.env.VIRTUAL_ENV .. "/bin/python") or "python3"
      end

      -- Initialize adapter
      dap_python.setup(get_debugpy_host())
      dap_python.test_runner = "pytest"

      dap.configurations.python = dap.configurations.python or {}

      -- 3. Configuration: Launch Odoo 18 Server
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Odoo 18: Launch Server",
        program = "${workspaceFolder}/odoo-src/odoo-bin",
        args = {
          "-c",
          "${workspaceFolder}/odoo.conf",
          "-d",
          "test_db",
          "--dev=xml",
          "--workers=0",
          "--limit-time-real=0",
          "--limit-time-cpu=0",
        },
        pythonPath = get_target_python,
        cwd = "${workspaceFolder}",
        justMyCode = false, -- Critical: allows stepping into Odoo core ORM and custom addons
        console = "integratedTerminal",
        env = {
          PYTHONDONTWRITEBYTECODE = "1",
          PYTHONUNBUFFERED = "1", -- Prevents log delay in integrated terminal
        },
      })

      -- 4. Configuration: Debug Specific Odoo Test Tag
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Odoo 18: Debug Test Tag",
        program = "${workspaceFolder}/odoo-src/odoo-bin",
        args = function()
          local tag = vim.fn.input("Test Tag (e.g. /saudi_local_content): ")
          return {
            "-c",
            "${workspaceFolder}/odoo.conf",
            "-d",
            "test_db",
            "--test-enable",
            "--test-tags",
            tag,
            "--stop-after-init",
            "--workers=0",
            "--limit-time-real=0",
            "--limit-time-cpu=0",
            "--log-level=test",
          }
        end,
        pythonPath = get_target_python,
        cwd = "${workspaceFolder}",
        justMyCode = false,
        console = "integratedTerminal",
        env = {
          PYTHONDONTWRITEBYTECODE = "1",
          PYTHONUNBUFFERED = "1",
        },
      })
    end,
    keys = {
      {
        "<leader>dPt",
        function()
          require("dap-python").test_method()
        end,
        desc = "Debug Method",
        ft = "python",
      },
      {
        "<leader>dPc",
        function()
          require("dap-python").test_class()
        end,
        desc = "Debug Class",
        ft = "python",
      },
    },
  },
}
