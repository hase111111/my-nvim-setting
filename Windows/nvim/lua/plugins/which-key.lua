return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      icons = {
        mappings = false,
      },
      spec = {
        { "<leader>f", group = "find" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer local keymaps",
      },
    },
  },
}

