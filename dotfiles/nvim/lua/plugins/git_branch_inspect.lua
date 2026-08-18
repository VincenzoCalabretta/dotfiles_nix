-- Neovim configuration for inspecting files from different Git branches
-- Save this as ~/.config/nvim/lua/git-branch-inspect.lua
-- Then require it from your init.lua with: require('git-branch-inspect')

return {
  -- Git integration
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
    end,
  },

  -- Diffview for comparing branches
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('diffview').setup({
        enhanced_diff_hl = true,
        view = {
          merge_tool = {
            layout = "diff3_mixed",
          },
        },
      })
    end,
  },

  -- Telescope for fuzzy finding
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },

  -- Git signs for current buffer
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end,
  },

  -- Custom configuration for branch inspection
  {
    'nvim-telescope/telescope.nvim',
    keys = {
      { '<leader>gb', desc = '[G]it [B]rowse files from branch' },
      { '<leader>gd', desc = '[G]it [D]iff current file with branch' },
      { '<leader>gg', '<cmd>Neogit<cr>', desc = '[G]it Neo[g]it' },
      { '<leader>gC', '<cmd>DiffviewClose<cr>', desc = '[G]it diffview [C]lose' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it file [H]istory' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it repo [H]istory' },
    },
    config = function()
      -- Helper function to get Git root directory
      local function get_git_root()
        local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
        if vim.v.shell_error ~= 0 then
          vim.notify('Not in a git repository', vim.log.levels.ERROR)
          return nil
        end
        return git_root
      end

      -- Function to show file from specific branch in a split
      local function show_file_from_branch(branch, filepath)
        local git_root = get_git_root()
        if not git_root then return end

        -- Get relative path if absolute path provided
        local rel_path = filepath
        if filepath:sub(1, 1) == '/' then
          rel_path = filepath:gsub('^' .. git_root .. '/', '')
        end

        -- Create temporary file name
        local temp_file = vim.fn.tempname()
        
        -- Get file content from branch
        local cmd = string.format('git show %s:%s > %s', branch, rel_path, temp_file)
        local result = vim.fn.system(cmd)
        
        if vim.v.shell_error ~= 0 then
          vim.notify('Failed to get file from branch: ' .. result, vim.log.levels.ERROR)
          return
        end

        -- Open in vertical split
        vim.cmd('vsplit ' .. temp_file)
        
        -- Set buffer options
        vim.bo.buftype = 'nofile'
        vim.bo.bufhidden = 'wipe'
        vim.bo.swapfile = false
        vim.bo.readonly = true
        vim.bo.modifiable = false
        
        -- Set buffer name to show branch and file
        vim.api.nvim_buf_set_name(0, string.format('[%s] %s', branch, rel_path))
        
        -- Detect filetype for syntax highlighting
        local ft = vim.filetype.match({ filename = rel_path })
        if ft then
          vim.bo.filetype = ft
        end
      end

      -- Function to compare current file with version from another branch
      local function diff_file_with_branch(branch, filepath)
        local git_root = get_git_root()
        if not git_root then return end

        filepath = filepath or vim.api.nvim_buf_get_name(0)
        local rel_path = filepath:gsub('^' .. git_root .. '/', '')

        -- Use diffview to compare
        vim.cmd(string.format('DiffviewOpen %s -- %s', branch, rel_path))
      end

      -- Telescope picker to browse files from a specific branch
      local function browse_branch_files(branch)
        local git_root = get_git_root()
        if not git_root then return end

        -- Get list of files in the branch
        local cmd = string.format('git ls-tree -r --name-only %s', branch)
        local files = vim.fn.systemlist(cmd)
        
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
          finder = finders.new_table({
            results = files,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              show_file_from_branch(branch, selection[1])
            end)
            
            -- Add mapping to diff instead
            map('i', '<C-d>', function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              diff_file_with_branch(branch, git_root .. '/' .. selection[1])
            end)
            
            return true
          end,
        }):find()
      end

      -- Telescope picker to select a branch first
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
          finder = finders.new_table({
            results = branches,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              browse_branch_files(selection[1])
            end)
            return true
          end,
        }):find()
      end

      -- Quick diff current file with same file in another branch
      local function quick_diff_current_file()
        local current_file = vim.api.nvim_buf_get_name(0)
        local git_root = get_git_root()
        
        if not git_root or current_file == '' then
          vim.notify('Not in a git-tracked file', vim.log.levels.WARN)
          return
        end

        local branches = vim.fn.systemlist('git branch --all --format="%(refname:short)"')
        
        local pickers = require('telescope.pickers')
        local finders = require('telescope.finders')
        local conf = require('telescope.config').values
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')

        pickers.new({}, {
          prompt_title = 'Compare current file with branch',
          finder = finders.new_table({
            results = branches,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              diff_file_with_branch(selection[1], current_file)
            end)
            
            -- Add mapping to just view the file instead
            map('i', '<C-v>', function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              local rel_path = current_file:gsub('^' .. git_root .. '/', '')
              show_file_from_branch(selection[1], rel_path)
            end)
            
            return true
          end,
        }):find()
      end

      -- Set up keymaps
      vim.keymap.set('n', '<leader>gb', select_branch_then_browse, 
        { desc = '[G]it [B]rowse files from branch' })
      vim.keymap.set('n', '<leader>gd', quick_diff_current_file, 
        { desc = '[G]it [D]iff current file with branch' })
    end,
  },
}
