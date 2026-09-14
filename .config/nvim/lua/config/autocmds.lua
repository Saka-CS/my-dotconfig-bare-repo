-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup('lsp_attach_disable_ruff_hover', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client == nil then
      return
    end
    if client.name == 'ruff' then
      -- Disable hover in favor of Pyright
      client.server_capabilities.hoverProvider = false
    end
  end,
  desc = 'LSP: Disable hover capability from Ruff',
})

-- Auto-open PDFs externally instead of showing binary + broken gx
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("pdf_external_open", { clear = true }),
  pattern = { "*.pdf", "*.PDF" },
  callback = function(args)
    -- Escape hatch: PDF_EDIT=1 nvim file.pdf to inspect binary
    if vim.env.PDF_EDIT == "1" then
      return
    end

    local path = vim.fn.fnamemodify(args.file, ":p")

    if path == "" or vim.fn.filereadable(path) == 0 then
      vim.schedule(function()
        vim.notify("PDF not readable: " .. args.file, vim.log.levels.ERROR)
        pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
      end)
      return
    end

    -- Non-blocking external open (Evince per your mimeapps.list)
    local ok, err = pcall(vim.ui.open, path)
    if not ok then
      vim.fn.jobstart({ "xdg-open", path }, { detach = true })
      vim.schedule(function()
        vim.notify("vim.ui.open failed, tried xdg-open: " .. tostring(err), vim.log.levels.WARN)
      end)
    else
      vim.schedule(function()
        vim.notify("Opened PDF externally:\n" .. path, vim.log.levels.INFO)
      end)
    end

    -- Prevent binary buffer; schedule so BufReadCmd can finish
    vim.schedule(function()
      pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
    end)
  end,
  desc = "Open PDFs in Evince/xdg-open instead of buffer",
})
