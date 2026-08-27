return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = {
      history = true,
      delete_check_events = "TextChanged",
      region_check_events = "CursorMoved,InsertEnter",
      update_events = "TextChanged,InsertLeave",
      enable_autosnippets = false,
    },
    config = function(_, opts)
      local luasnip = require("luasnip")
      luasnip.config.set_config(opts)

      -- Load friendly-snippets & community vscode-format snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      -- Filetype aliases (allow JS snippets in TS / JSX files)
      luasnip.filetype_extend("javascriptreact", { "javascript" })
      luasnip.filetype_extend("typescript", { "javascript" })
      luasnip.filetype_extend("typescriptreact", { "javascript" })

      -- Load custom user snippets from ~/.config/nvim/snippets/
      local custom_snippets_path = vim.fn.stdpath("config") .. "/snippets"
      if vim.fn.isdirectory(custom_snippets_path) == 1 then
        require("luasnip.loaders.from_vscode").lazy_load({
          paths = { custom_snippets_path },
        })
      end

      -- User command to hot-reload custom snippets without restarting Neovim
      vim.api.nvim_create_user_command("LuaSnipReload", function()
        luasnip.cleanup()
        require("luasnip.loaders.from_vscode").lazy_load()
        require("luasnip.loaders.from_vscode").load({ paths = { custom_snippets_path } })
        vim.notify("LuaSnip snippets reloaded!", vim.log.levels.INFO, { title = "LuaSnip" })
      end, { desc = "Clean and reload all snippets" })
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      snippets = {
        preset = "luasnip",
      },
    },
  },
}
