return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "mfussenegger/nvim-dap",
      "mfussenegger/nvim-dap-python",
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      local function get_python_path(root)
        local vs_ok, vs = pcall(require, "venv-selector")
        if vs_ok then
          local vs_py = (vs.python and vs.python()) or (vs.get_active_path and vs.get_active_path())
          if vs_py and vim.fn.executable(vs_py) == 1 then
            return vs_py
          end
        end

        local project_root = root or (vim.uv and vim.uv.cwd() or vim.fn.getcwd())
        local root_venv = project_root .. "/.venv/bin/python"
        if vim.fn.executable(root_venv) == 1 then
          return root_venv
        end

        if vim.env.VIRTUAL_ENV and vim.fn.executable(vim.env.VIRTUAL_ENV .. "/bin/python") == 1 then
          return vim.env.VIRTUAL_ENV .. "/bin/python"
        end

        return "python3"
      end

      opts.adapters["neotest-python"] = {
        runner = "pytest",
        python = get_python_path,
        args = { "-s", "--tb=short" },
        dap = {
          justMyCode = false,
          console = "integratedTerminal",
          env = {
            PYTHONDONTWRITEBYTECODE = "1",
            PYTHONUNBUFFERED = "1",
            GEVENT_SUPPORT = "True",
          },
        },
      }

      opts.status = { virtual_text = true, signs = true }
      opts.output = { open_on_run = false, enter = false }
      opts.summary = {
        open = "botright vsplit | vertical resize 45",
        follow = true,
        expand_errors = true,
      }
      opts.floating = { border = "rounded", max_height = 0.85, max_width = 0.85 }
    end,
    keys = {
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run Nearest Test (Cursor)" },
      { "<leader>tt", function() require("neotest").run.run(vim.api.nvim_buf_get_name(0)) end, desc = "Run File Tests" },
      { "<leader>tT", function() require("neotest").run.run(vim.uv and vim.uv.cwd() or vim.fn.getcwd()) end, desc = "Run All Test Files" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run Last Test" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Test Summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Test Output Window" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Test Output Panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop Test Run" },
      { "<leader>tw", function() require("neotest").watch.toggle(vim.api.nvim_buf_get_name(0)) end, desc = "Toggle Test Watch" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest Test (DAP)" },
      { "<leader>tD", function() require("neotest").run.run({ vim.api.nvim_buf_get_name(0), strategy = "dap" }) end, desc = "Debug Current File (DAP)" },
    },
  },
}
