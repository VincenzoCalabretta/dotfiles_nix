-- git_branch_inspect.lua already owns <leader>gc/gh/gH/gd for diffview.
-- This file only loads the plugin and adds the one missing key: full diff open.
return {
  {
    'sindrets/diffview.nvim',
    cmd  = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    keys = {
      { '<leader>gD', '<cmd>DiffviewOpen<cr>', desc = 'Diffview: open full diff view' },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
