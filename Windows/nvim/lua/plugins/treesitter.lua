return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      "mason-org/mason.nvim",
    },
    config = function()
      local loaded, treesitter = pcall(require, "nvim-treesitter")
      if not loaded or type(treesitter.install) ~= "function" then
        return
      end

      local parsers = {
        "c",
        "cpp",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "markdown",
        "markdown_inline",
      }

      treesitter.setup({})
      if vim.fn.executable("tree-sitter") ~= 1 then
        return
      end

      treesitter.install(parsers):wait(300000)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp", "lua", "vim", "vimdoc", "query", "markdown" },
        callback = function(event)
          pcall(vim.treesitter.start, event.buf)
        end,
      })
    end,
  },
}

