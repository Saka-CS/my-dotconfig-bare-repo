-- return {
--   "neovim/nvim-lspconfig",
--   opts = {
--     servers = {
--       ['*'] = {
--         keys = {
--           -- Add or change a keymap
--           { "K", vim.lsp.buf.hover, desc = "Hover" },
--           -- Disable a keymap
--           { "gd", false },
--           -- Capability-based keymap (only set if server supports it)
--           { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", has = "codeAction" },
--         },
--       },
--     },
--   },
-- }
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      ruff = {
        -- cmd_env = { RUFF_TRACE = "messages" },
        init_options = {
          settings = {
            -- General & Logging
            -- logLevel = "info",
            -- showSyntaxErrors = true,
            -- configurationPreference = "editorFirst",
            -- lineLength = 88,

            -- Code Actions
            -- fixAll = true,
            -- organizeImports = true,
            -- codeAction = {
            --   disableRuleComment = { enable = true },
            --   fixViolation = { enable = true },
            -- },

            -- Linter Settings
            -- lint = {
            --   enable = true,
            --   preview = false,
            --   -- select = { "E", "F", "I", "UP", "B" },
            --   -- ignore = { "E501" },
            -- },

            -- Formatter Settings
            -- format = {
            --   preview = false,
            -- },
          },
        },
      },

      pyright = {
        settings = {
          pyright = {
            -- Let Ruff handle import sorting
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              ignore = { "*" }
            },
          },
        },
      },

      lua_ls = {
        settings = {
        --   Lua = {
        --     workspace = { checkThirdParty = false },
        --     telemetry = { enable = false },
        --   },
        -- },
      },
    },

    -- 4. Server Setup Hooks & Capability Tweaks
    -- setup = {
    --   ruff = function()
    --     -- Disable hover provider in Ruff so Pyright's richer docstrings/signatures take precedence
    --     LazyVim.lsp.on_attach(function(client, _)
    --       if client.name == "ruff" then
    --         client.server_capabilities.hoverProvider = false
    --       end
    --     end)
    --   end,
    },
  },
}
