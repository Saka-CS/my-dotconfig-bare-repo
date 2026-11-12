-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.opt.relativenumber = true
vim.g.autoformat = true

-- Kanata keyboard config files
vim.filetype.add({ extension = { kbd = "kanata" } })

-- vim.g.trouble_lualine = true
-- vim.opt.tabstop = 2
