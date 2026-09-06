-- See `:help gitsigns` to understand what the configuration keys do
return {
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions: the <leader>g domain is Git-only and remains flat.
        -- visual mode
        map('v', '<leader>gs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'stage git hunk' })
        map('v', '<leader>gr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'reset git hunk' })
        -- normal mode
        map('n', '<leader>gs', gitsigns.stage_hunk, { desc = 'Git: stage hunk' })
        map('n', '<leader>gr', gitsigns.reset_hunk, { desc = 'Git: reset hunk' })
        map('n', '<leader>gS', gitsigns.stage_buffer, { desc = 'Git: stage buffer' })
        map('n', '<leader>gu', gitsigns.undo_stage_hunk, { desc = 'Git: undo stage hunk' })
        map('n', '<leader>gR', gitsigns.reset_buffer, { desc = 'Git: reset buffer' })
        map('n', '<leader>gp', gitsigns.preview_hunk, { desc = 'Git: preview hunk' })
        map('n', '<leader>gB', gitsigns.blame_line, { desc = 'Git: blame line' })
        map('n', '<leader>gi', gitsigns.diffthis, { desc = 'Git: diff against index' })
        map('n', '<leader>gH', function()
          gitsigns.diffthis '@'
        end, { desc = 'Git: diff against last commit' })
        -- Toggles
        map('n', '<leader>gt', gitsigns.toggle_current_line_blame, { desc = 'Git: toggle line blame' })
        map('n', '<leader>gT', gitsigns.toggle_deleted, { desc = 'Git: toggle deleted lines' })
      end,
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
