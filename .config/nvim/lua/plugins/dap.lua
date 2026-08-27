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
        local mason_direct = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
        if vim.fn.executable(mason_direct) == 1 then
          return mason_direct
        end

        local ok, registry = pcall(require, "mason-registry")
        if ok and registry.is_installed("debugpy") then
          local pkg = registry.get_package("debugpy")
          local mason_py = pkg:get_install_path() .. "/venv/bin/python"
          if vim.fn.executable(mason_py) == 1 then
            return mason_py
          end
        end

        local venv_py = vim.fn.getcwd() .. "/.venv/bin/python"
        if vim.fn.executable(venv_py) == 1 then
          return venv_py
        end
        return "python3"
      end

      -- 2. Resolve Python interpreter for target project runtime
      local function get_target_python()
        local vs_ok, vs = pcall(require, "venv-selector")
        if vs_ok then
          local vs_py = (vs.get_active_path and vs.get_active_path()) or (vs.python and vs.python())
          if vs_py and vim.fn.executable(vs_py) == 1 then
            return vs_py
          end
        end

        local venv_py = vim.fn.getcwd() .. "/.venv/bin/python"
        if vim.fn.executable(venv_py) == 1 then
          return venv_py
        end
        return vim.env.VIRTUAL_ENV and (vim.env.VIRTUAL_ENV .. "/bin/python") or "python3"
      end

      -- 3. Resolve odoo-bin executable path
      local function get_odoo_bin()
        local cwd = vim.fn.getcwd()
        local candidates = {
          cwd .. "/odoo-src/odoo-bin",
          cwd .. "/odoo-bin",
          cwd .. "/.venv/bin/odoo-bin",
          cwd .. "/.venv/bin/odoo",
        }
        for _, path in ipairs(candidates) do
          if vim.fn.filereadable(path) == 1 then
            return path
          end
        end
        return cwd .. "/odoo-src/odoo-bin"
      end

      -- Initialize adapter
      dap_python.setup(get_debugpy_host())
      dap_python.resolve_python = get_target_python
      dap_python.test_runner = "pytest"

      dap.configurations.python = dap.configurations.python or {}

      -- 4. Configuration: Launch Odoo 18 Server
      table.insert(dap.configurations.python, 1, {
        type = "python",
        request = "launch",
        name = "Odoo 18: Launch Server",
        program = get_odoo_bin,
        args = {
          "-c",
          vim.fn.getcwd() .. "/odoo.conf",
          "-d",
          "test_db",
          "--logfile=", -- Overrides odoo.conf logfile to stream output to DAP terminal
          "--dev=xml,qweb",
          "--workers=0",
          "--limit-time-real=0",
          "--limit-time-cpu=0",
        },
        pythonPath = get_target_python,
        cwd = vim.fn.getcwd,
        justMyCode = false,
        console = "integratedTerminal",
        subProcess = false,
        env = {
          PYTHONDONTWRITEBYTECODE = "1",
          PYTHONUNBUFFERED = "1",
          GEVENT_SUPPORT = "1",
        },
      })

      -- 5. Configuration: Launch Odoo 18 & Upgrade Module (-u)
      table.insert(dap.configurations.python, 2, {
        type = "python",
        request = "launch",
        name = "Odoo 18: Launch & Upgrade Module (-u)",
        program = get_odoo_bin,
        args = function()
          local mod = vim.fn.input("Module to update (e.g. saudi_local_content): ", "saudi_local_content")
          if not mod or vim.trim(mod) == "" then
            return dap.ABORT
          end
          return {
            "-c",
            vim.fn.getcwd() .. "/odoo.conf",
            "-d",
            "test_db",
            "-u",
            vim.trim(mod),
            "--logfile=",
            "--dev=xml,qweb",
            "--workers=0",
            "--limit-time-real=0",
            "--limit-time-cpu=0",
          }
        end,
        pythonPath = get_target_python,
        cwd = vim.fn.getcwd,
        justMyCode = false,
        console = "integratedTerminal",
        subProcess = false,
        env = {
          PYTHONDONTWRITEBYTECODE = "1",
          PYTHONUNBUFFERED = "1",
          GEVENT_SUPPORT = "1",
        },
      })

      -- 6. Configuration: Debug Specific Odoo Test Tag
      table.insert(dap.configurations.python, 3, {
        type = "python",
        request = "launch",
        name = "Odoo 18: Debug Test Tag",
        program = get_odoo_bin,
        args = function()
          local tag = vim.fn.input("Test Tag (e.g. /saudi_local_content or .test_score): ")
          if not tag or vim.trim(tag) == "" then
            return dap.ABORT
          end
          return {
            "-c",
            vim.fn.getcwd() .. "/odoo.conf",
            "-d",
            "test_db",
            "--test-enable",
            "--test-tags",
            vim.trim(tag),
            "--stop-after-init",
            "--logfile=",
            "--workers=0",
            "--limit-time-real=0",
            "--limit-time-cpu=0",
            "--log-level=test",
          }
        end,
        pythonPath = get_target_python,
        cwd = vim.fn.getcwd,
        justMyCode = false,
        console = "integratedTerminal",
        subProcess = false,
        env = {
          PYTHONDONTWRITEBYTECODE = "1",
          PYTHONUNBUFFERED = "1",
          GEVENT_SUPPORT = "1",
        },
      })

      -- 7. Configuration: Attach to Remote/Docker debugpy (Port 5678)
      table.insert(dap.configurations.python, 4, {
        type = "python",
        request = "attach",
        name = "Odoo 18: Attach (Port 5678)",
        connect = function()
          local host = vim.fn.input("Host [127.0.0.1]: ")
          host = host ~= "" and host or "127.0.0.1"
          local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
          return { host = host, port = port }
        end,
        pathMappings = function()
          local remote_root = vim.fn.input("Remote root inside container [/workspace]: ")
          remote_root = remote_root ~= "" and remote_root or "/workspace"
          return {
            {
              localRoot = vim.fn.getcwd(),
              remoteRoot = remote_root,
            },
          }
        end,
        justMyCode = false,
        cwd = vim.fn.getcwd,
      })
    end,
    keys = {
      {
        "<leader>dPt",
        function()
          require("dap-python").test_method()
        end,
        desc = "Debug Method (pytest-odoo)",
        ft = "python",
      },
      {
        "<leader>dPc",
        function()
          require("dap-python").test_class()
        end,
        desc = "Debug Class (pytest-odoo)",
        ft = "python",
      },
    },
  },
}
