return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    lazy = false,
    opts = {
      size = 15,
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      close_on_exit = true,
      on_open = function(terminal)
        vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], {
          buffer = terminal.bufnr,
          desc = "Leave terminal mode",
        })
      end,
    },
    keys = {
      { "<leader>t", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
    },
  },
}

