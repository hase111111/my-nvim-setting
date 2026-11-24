local function gcc_query_drivers()
  local drivers = {}

  for _, executable in ipairs({ "gcc", "g++" }) do
    local path = vim.fn.exepath(executable)
    if path ~= "" then
      table.insert(drivers, (path:gsub("\\", "/")))
    end
  end

  return drivers
end

return {
  {
    "mason-org/mason.nvim",
    lazy = false,
    opts = {
      PATH = "append",
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "saghen/blink.cmp",
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      automatic_enable = { "clangd" },
    },
    config = function(_, opts)
      local cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--completion-style=detailed",
        "--header-insertion=iwyu",
      }

      local drivers = gcc_query_drivers()
      if #drivers > 0 then
        table.insert(cmd, "--query-driver=" .. table.concat(drivers, ","))
      end

      vim.lsp.config("clangd", {
        cmd = cmd,
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      require("mason-lspconfig").setup(opts)
    end,
  },
}

