local npm_root = vim.fn.trim(vim.fn.system("npm root -g"))
local xml_plugin = npm_root .. "/@prettier/plugin-xml/src/plugin.js"

local function prettier_xml_args(ignore_preserve)
  local args = { "--plugin", xml_plugin, "--parser", "xml", "--stdin-filepath", "$FILENAME" }
  if ignore_preserve then
    vim.list_extend(args, { "--xml-whitespace-sensitivity", "ignore" })
  end
  return args
end

return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff" },
      javascript = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      json = { "prettierd", "prettier", stop_after_first = true },
      xml = { "prettier_xml" },
    },
    formatters = {
      prettier_xml = { command = "prettier", args = prettier_xml_args(false) },
      prettier_xml_force = { command = "prettier", args = prettier_xml_args(true) },
    },
  },
}
