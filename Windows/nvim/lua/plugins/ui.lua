return {
  {
    "romgrk/barbar.nvim",
    version = "^1.0.0",
    lazy = false,
    init = function()
      vim.g.barbar_auto_setup = false
    end,
    opts = {
      animation = true,
      auto_hide = 1,
      icons = {
        button = false,
        filetype = {
          enabled = false,
        },
      },
    },
    keys = {
      { "<A-,>", "<cmd>BufferPrevious<CR>", desc = "Previous buffer" },
      { "<A-.>", "<cmd>BufferNext<CR>", desc = "Next buffer" },
      { "<A-c>", "<cmd>BufferClose<CR>", desc = "Close buffer" },
      { "<A-p>", "<cmd>BufferPin<CR>", desc = "Pin buffer" },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        icons_enabled = false,
        theme = "tokyonight",
        component_separators = { left = "|", right = "|" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
  {
    "simeji/winresizer",
    init = function()
      vim.g.winresizer_start_key = "<Nop>"
      vim.g.winresizer_finish_with_escape = 1
    end,
    keys = {
      { "<leader>wr", "<cmd>WinResizerStartResize<CR>", desc = "Resize windows" },
    },
  },
  {
    "kevinhwang91/nvim-hlslens",
    opts = {
      calm_down = true,
      nearest_only = false,
    },
  },
  {
    "petertriho/nvim-scrollbar",
    lazy = false,
    opts = {},
  },
}

