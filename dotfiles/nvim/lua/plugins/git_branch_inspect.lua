local function get_git_root()
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return nil
  end
  return git_root
end

local function show_file_from_branch(branch, filepath)
  local git_root = get_git_root()
  if not git_root then return end

  local rel_path = filepath
  if filepath:sub(1, 1) == '/' then
    rel_path = filepath:gsub('^' .. git_root .. '/', '')
  end

  local temp_file = vim.fn.tempname()
  local result = vim.fn.system(string.format('git show %s:%s > %s', branch, rel_path, temp_file))
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to get file from branch: ' .. result, vim.log.levels.ERROR)
    return
  end

  vim.cmd('vsplit ' .. temp_file)
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.swapfile = false
  vim.bo.readonly = true
  vim.bo.modifiable = false
  vim.api.nvim_buf_set_name(0, string.format('[%s] %s', branch, rel_path))

  local filetype = vim.filetype.match({ filename = rel_path })
  if filetype then vim.bo.filetype = filetype end
end

local function diff_file_with_branch(branch, filepath)
  local git_root = get_git_root()
  if not git_root then return end

  filepath = filepath or vim.api.nvim_buf_get_name(0)
  local rel_path = filepath:gsub('^' .. git_root .. '/', '')
  vim.cmd(string.format('DiffviewOpen %s -- %s', branch, rel_path))
end

local function browse_branch_files(branch)
  local git_root = get_git_root()
  if not git_root then return end

  local files = vim.fn.systemlist(string.format('git ls-tree -r --name-only %s', branch))
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to list files in branch', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Files in branch: ' .. branch,
    finder = finders.new_table({ results = files }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        show_file_from_branch(branch, action_state.get_selected_entry()[1])
      end)
      map('i', '<C-d>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        diff_file_with_branch(branch, git_root .. '/' .. selection[1])
      end)
      return true
    end,
  }):find()
end

local function select_branch_then_browse()
  local branches = vim.fn.systemlist('git branch --all --format="%(refname:short)"')
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to get branches', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Select Branch',
    finder = finders.new_table({ results = branches }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        browse_branch_files(action_state.get_selected_entry()[1])
      end)
      return true
    end,
  }):find()
end

local function quick_diff_current_file()
  local current_file = vim.api.nvim_buf_get_name(0)
  local git_root = get_git_root()
  if not git_root or current_file == '' then
    vim.notify('Not in a git-tracked file', vim.log.levels.WARN)
    return
  end

  local branches = vim.fn.systemlist('git branch --all --format="%(refname:short)"')
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to get branches', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Compare current file with branch',
    finder = finders.new_table({ results = branches }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        diff_file_with_branch(action_state.get_selected_entry()[1], current_file)
      end)
      map('i', '<C-v>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        show_file_from_branch(selection[1], current_file)
      end)
      return true
    end,
  }):find()
end

return {
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('neogit').setup({
        integrations = {
          telescope = true,
          diffview = true,
        },
      })

      vim.keymap.set('n', '<leader>gg', '<cmd>Neogit<cr>', { desc = 'Git: status' })
      vim.keymap.set('n', '<leader>gb', select_branch_then_browse, { desc = 'Git: browse branch files' })
      vim.keymap.set('n', '<leader>gd', quick_diff_current_file, { desc = 'Git: diff file against branch' })
    end,
  },
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('diffview').setup({
        enhanced_diff_hl = true,
        view = { merge_tool = { layout = 'diff3_mixed' } },
      })
    end,
    keys = {
      { '<leader>gC', '<cmd>DiffviewClose<cr>', desc = 'Git: close Diffview' },
      { '<leader>gD', '<cmd>DiffviewOpen<cr>', desc = 'Git: open Diffview' },
      { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = 'Git: file history' },
      { '<leader>gF', '<cmd>DiffviewFileHistory<cr>', desc = 'Git: repository history' },
    },
  },
}
