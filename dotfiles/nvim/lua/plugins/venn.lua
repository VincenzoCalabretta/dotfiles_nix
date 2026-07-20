return {
  {
    "jbyuki/venn.nvim",
    keys = {
      { "<leader>v", desc = "Toggle Venn diagram mode" },
    },
    config = function()
      -- Toggle venn.nvim keymappings
      function _G.Toggle_venn()
        local venn_enabled = vim.inspect(vim.b.venn_enabled)
        if venn_enabled == "nil" then
          vim.b.venn_enabled = true
          vim.cmd [[setlocal ve=all]]

          -- Draw a line on HJKL keystrokes
          vim.api.nvim_buf_set_keymap(0, "n", "J", "<C-v>j:VBox<CR>", { noremap = true })
          vim.api.nvim_buf_set_keymap(0, "n", "K", "<C-v>k:VBox<CR>", { noremap = true })
          vim.api.nvim_buf_set_keymap(0, "n", "L", "<C-v>l:VBox<CR>", { noremap = true })
          vim.api.nvim_buf_set_keymap(0, "n", "H", "<C-v>h:VBox<CR>", { noremap = true })

          -- Draw a box by pressing "f" with visual selection
          vim.api.nvim_buf_set_keymap(0, "v", "f", ":VBox<CR>", { noremap = true })

          vim.notify("Venn mode enabled", vim.log.levels.INFO)
        else
          vim.cmd [[setlocal ve=]]

          -- Remove keymappings
          vim.api.nvim_buf_del_keymap(0, "n", "J")
          vim.api.nvim_buf_del_keymap(0, "n", "K")
          vim.api.nvim_buf_del_keymap(0, "n", "L")
          vim.api.nvim_buf_del_keymap(0, "n", "H")
          vim.api.nvim_buf_del_keymap(0, "v", "f")

          vim.b.venn_enabled = nil
          vim.notify("Venn mode disabled", vim.log.levels.INFO)
        end
      end

      -- Toggle keymappings for venn using <leader>v
      vim.api.nvim_set_keymap('n', '<leader>v', ":lua Toggle_venn()<CR>", { noremap = true, silent = true })
    end,
  }
}
