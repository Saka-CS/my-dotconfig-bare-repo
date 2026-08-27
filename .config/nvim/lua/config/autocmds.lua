-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- SQL / Dadbod query buffer mappings
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "sql", "mysql", "plsql" },
  callback = function(args)
    local opts = { buffer = args.buf, silent = true }
    vim.keymap.set("v", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", vim.tbl_extend("force", opts, { desc = "Execute query selection" }))
    vim.keymap.set("n", "<leader>rq", "<Plug>(DBUI_ExecuteQuery)", vim.tbl_extend("force", opts, { desc = "Execute SQL buffer" }))
    vim.keymap.set("n", "<leader>rp", "vip<Plug>(DBUI_ExecuteQuery)", vim.tbl_extend("force", opts, { desc = "Execute SQL paragraph" }))
    vim.keymap.set("n", "<leader>sq", "<Plug>(DBUI_SaveQuery)", vim.tbl_extend("force", opts, { desc = "Save Query to DBUI" }))
  end,
})
