return {
  'nvim-flutter/flutter-tools.nvim',
  lazy = false,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'stevearc/dressing.nvim'
  },
  opts = {
    decorations = {
      statusline = {
        -- set to true to be able use the 'flutter_tools_decorations.app_version' in your statusline
        -- this will show the current version of the flutter app from the pubspec.yaml file
        app_version = true,
        -- set to true to be able use the 'flutter_tools_decorations.device' in your statusline
        -- this will show the running device, or, while nothing is running in a Flutter project,
        -- the device `flutter run` would pick by default
        device = true,
        -- set to true to be able use the 'flutter_tools_decorations.project_config' in your statusline
        -- this will show the currently selected project configuration
        project_config = true,
      }
    },
  }
}
-- return {
--   "akinsho/flutter-tools.nvim",
--   dependencies = {
--     "nvim-lua/plenary.nvim",
--     "stevearc/dressing.nvim", -- Optional: UI enhancements
--   },
--   config = function()
--     require("flutter-tools").setup {
--       widget_guides = { enabled = true },
--       closing_tags = {
--         highlight = "Comment", -- highlight for closing tag
--         prefix = "// ",        -- character to use for close tag e.g. > //
--         enabled = true
--       },
--       dev_log = {
--         enabled = true,
--         open_cmd = "tabedit", -- or "vsplit"
--       },
--     }
--   end,
-- }
