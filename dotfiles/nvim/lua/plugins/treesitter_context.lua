return {
  {
    'nvim-treesitter/nvim-treesitter-context',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      max_lines      = 4,
      trim_scope     = 'outer',
      mode           = 'cursor',
      separator      = nil,
    },
    keys = {
      {
        '[C',
        function() require('treesitter-context').go_to_context(vim.v.count1) end,
        mode = 'n',
        desc = 'Jump to outer context',
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
