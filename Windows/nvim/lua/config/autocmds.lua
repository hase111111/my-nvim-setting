local group = vim.api.nvim_create_augroup("user_config", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Highlight copied text",
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  desc = "Configure LSP keymaps",
  callback = function(event)
    local opts = { buffer = event.buf }
    local map = vim.keymap.set

    map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
    map("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
    map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "List references" }))
    map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Show symbol information" }))
    map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
    map("n", "<leader>d", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Show diagnostic" }))
    map("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, vim.tbl_extend("force", opts, { desc = "Previous diagnostic" }))
    map("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))
  end,
})

