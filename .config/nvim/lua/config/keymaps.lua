-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  if vim.bo.filetype == "xml" then
    require("conform").format({
      formatters = { "prettier_xml_force" },
      lsp_format = "never",
      timeout_ms = 3000,
    })
  else
    LazyVim.format({ force = true }) -- unchanged for all other filetypes
  end
end, { desc = "Format" })
