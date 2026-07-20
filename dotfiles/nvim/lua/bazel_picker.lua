-- Bazel target picker using Telescope with auto-rebuild on file changes
-- Add this to your Neovim config (e.g., ~/.config/nvim/lua/bazel-picker.lua)


-- TODO: remove additional targets, add secondary picker for configuration and
-- add a sane default so that you may potentially just double tap for the default
-- TODO: when rerunning a target you should check if there is a buffer with the
-- appropriate name and then clearing and writing in that buffer
-- TODO: add a <leader>bl to edit the latest runtime logs from the latest bazel target
-- that has been executed. For example
-- /Users/vincenzo/.cache/dev/bazel/53cee22ebd2ed064cbfe40eff718d5a9/execroot/_main/bazel-out/aarch64-fastbuild/testlogs/fsw/components/gnc/thruster_dispatcher/thruster_dispatcher_test/test.log
-- the current command logs are not usefule
-- TODO: the fact that the output of an execution is in terminal mode, makes
-- it very difficult to copy paths.
-- TODO: if a file is opened in a path that has "autocode" and ".cache/dev/bazel"
-- then format automatically the file

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local M = {}

-- Store last 3 executed targets with their configs and action types
M.recent_targets = {}
M.auto_rebuild_enabled = false
M.watch_autocmd_id = nil

-- Store job buffers and log files for each target
M.target_buffers = {}  -- Maps target_key -> {buffer_ids = {}, log_files = {}}

-- Generate a unique key for a target+config+action combination
local function get_target_key(target, config, action_type)
  return string.format("%s|%s|%s", target, config or "default", action_type)
end

-- Function to add target to recent history
local function add_to_recent(target, config, action_type)
  local entry = {
    target = target,
    config = config,
    action_type = action_type,
    timestamp = os.time()
  }
  
  -- Remove duplicates (same target + config + action)
  for i = #M.recent_targets, 1, -1 do
    local recent = M.recent_targets[i]
    if recent.target == target and 
       recent.config == config and 
       recent.action_type == action_type then
      table.remove(M.recent_targets, i)
    end
  end
  
  -- Add to front
  table.insert(M.recent_targets, 1, entry)
  
  -- Keep only last 3
  while #M.recent_targets > 3 do
    table.remove(M.recent_targets)
  end
end

-- Get Bazel log file location
local function get_bazel_log_path()
  -- Try to get bazel output base
  local handle = io.popen("bazel info output_base 2>/dev/null")
  if not handle then
    return nil
  end
  local output_base = handle:read("*l")
  handle:close()
  
  if output_base and output_base ~= "" then
    return output_base .. "/command.log"
  end
  return nil
end

-- Create a terminal buffer for running commands
local function create_terminal_buffer(cmd, target_key)
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_name(buf, "Bazel: " .. target_key)
  
  -- Store buffer reference
  if not M.target_buffers[target_key] then
    M.target_buffers[target_key] = {buffer_ids = {}, log_files = {}}
  end
  table.insert(M.target_buffers[target_key].buffer_ids, buf)
  
  return buf
end

-- Prefix Bazel commands to run inside the dev container
local function bazel_in_container(cmd)
  -- Change this line if you use podman or docker compose
  return string.format("docker exec dev %s", cmd)
end

-- Function to execute recent targets
local function execute_recent_targets()
  if #M.recent_targets == 0 then
    vim.notify("No recent Bazel targets to rebuild", vim.log.levels.WARN)
    return
  end
  
  vim.notify(string.format("🔄 Rebuilding %d recent target(s)...", #M.recent_targets), vim.log.levels.INFO)
  
  for i, entry in ipairs(M.recent_targets) do
    local config_flag = ""
    if entry.config and entry.config ~= "default" then
      config_flag = "--config=" .. entry.config
    end
    
    local cmd = bazel_in_container("bazel " .. entry.action_type .. " " .. config_flag .. " " .. entry.target)
    local target_key = get_target_key(entry.target, entry.config, entry.action_type)
    
    vim.notify(string.format("[%d/%d] %s", i, #M.recent_targets, cmd), vim.log.levels.INFO)
    
    -- Create buffer for output
    local buf = create_terminal_buffer(cmd, target_key)
    local output_lines = {}
    
    -- Execute in background with jobstart
    vim.fn.jobstart(cmd, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify(string.format("✅ [%d/%d] Success: %s", i, #M.recent_targets, entry.target), vim.log.levels.INFO)
        else
          vim.notify(string.format("❌ [%d/%d] Failed: %s (exit code: %d)", i, #M.recent_targets, entry.target, exit_code), vim.log.levels.ERROR)
          
          -- Store log file reference on failure
          local log_path = get_bazel_log_path()
          if log_path then
            if not M.target_buffers[target_key] then
              M.target_buffers[target_key] = {buffer_ids = {}, log_files = {}}
            end
            table.insert(M.target_buffers[target_key].log_files, log_path)
          end
        end
        
        -- Write final output to buffer
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
          end
        end)
      end,
      on_stdout = function(_, data)
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(output_lines, line)
          end
        end
      end,
      on_stderr = function(_, data)
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(output_lines, "[ERROR] " .. line)
          end
        end
      end,
    })
  end
end

-- Telescope picker for recent targets history
function M.pick_recent_targets()
  if #M.recent_targets == 0 then
    vim.notify("No recent Bazel targets", vim.log.levels.WARN)
    return
  end
  
  local entries = {}
  for i, entry in ipairs(M.recent_targets) do
    local config_str = entry.config == "default" and "" or " @" .. entry.config
    local timestamp = os.date("%Y-%m-%d %H:%M:%S", entry.timestamp)
    local display = string.format("[%d] %s%s [%s] - %s", 
      i, entry.target, config_str, entry.action_type, timestamp)
    
    table.insert(entries, {
      display = display,
      target = entry.target,
      config = entry.config,
      action_type = entry.action_type,
      timestamp = entry.timestamp,
      ordinal = display,
      target_key = get_target_key(entry.target, entry.config, entry.action_type)
    })
  end
  
  pickers.new({}, {
    prompt_title = "Recent Bazel Targets",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return entry
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: re-run the target
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          local config_flag = ""
          if selection.config and selection.config ~= "default" then
            config_flag = "--config=" .. selection.config
          end
          
          local cmd = bazel_in_container("bazel " .. selection.action_type .. " " .. config_flag .. " " .. selection.target)
          vim.notify("Re-running: " .. cmd, vim.log.levels.INFO)
          vim.cmd("terminal " .. cmd)
        end
      end)
      
      -- <C-o> to open output buffers
      map("i", "<C-o>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          M.show_target_buffers(selection.target_key)
        end
      end)
      
      -- <C-l> to open log files
      map("i", "<C-l>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          M.show_target_logs(selection.target_key)
        end
      end)
      
      map("n", "<C-o>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          M.show_target_buffers(selection.target_key)
        end
      end)
      
      map("n", "<C-l>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          M.show_target_logs(selection.target_key)
        end
      end)
      
      return true
    end,
  }):find()
end

-- Show all buffers for a target
function M.show_target_buffers(target_key)
  local target_info = M.target_buffers[target_key]
  
  if not target_info or #target_info.buffer_ids == 0 then
    vim.notify("No output buffers for this target", vim.log.levels.WARN)
    return
  end
  
  local valid_buffers = {}
  for _, buf_id in ipairs(target_info.buffer_ids) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      table.insert(valid_buffers, buf_id)
    end
  end
  
  if #valid_buffers == 0 then
    vim.notify("No valid output buffers found", vim.log.levels.WARN)
    return
  end
  
  -- Show in a new split
  vim.cmd("vsplit")
  vim.api.nvim_set_current_buf(valid_buffers[#valid_buffers])
end

-- Show log files for a target
function M.show_target_logs(target_key)
  local target_info = M.target_buffers[target_key]
  
  if not target_info or #target_info.log_files == 0 then
    -- Try to get the current log file
    local log_path = get_bazel_log_path()
    if log_path then
      vim.cmd("vsplit " .. vim.fn.fnameescape(log_path))
      vim.cmd("normal! G")  -- Jump to end of file
    else
      vim.notify("No log files available for this target", vim.log.levels.WARN)
    end
    return
  end
  
  -- If there's only one log file, open it directly
  if #target_info.log_files == 1 then
    vim.cmd("vsplit " .. vim.fn.fnameescape(target_info.log_files[1]))
    vim.cmd("normal! G")
    return
  end
  
  -- Multiple log files - show picker
  pickers.new({}, {
    prompt_title = "Select Log File",
    finder = finders.new_table({
      results = target_info.log_files,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          vim.cmd("vsplit " .. vim.fn.fnameescape(selection.value))
          vim.cmd("normal! G")
        end
      end)
      
      return true
    end,
  }):find()
end

-- Enable auto-rebuild on file changes
function M.enable_auto_rebuild()
  if M.auto_rebuild_enabled then
    vim.notify("Auto-rebuild already enabled", vim.log.levels.INFO)
    return
  end
  
  M.auto_rebuild_enabled = true
  
  -- Create autocommand for file changes
  M.watch_autocmd_id = vim.api.nvim_create_autocmd({"BufWritePost"}, {
    pattern = "*",
    callback = function()
      if M.auto_rebuild_enabled and #M.recent_targets > 0 then
        execute_recent_targets()
      end
    end,
  })
  
  vim.notify("🔥 Auto-rebuild enabled (triggers on file save)", vim.log.levels.INFO)
end

-- Disable auto-rebuild
function M.disable_auto_rebuild()
  if not M.auto_rebuild_enabled then
    vim.notify("Auto-rebuild already disabled", vim.log.levels.INFO)
    return
  end
  
  M.auto_rebuild_enabled = false
  
  if M.watch_autocmd_id then
    vim.api.nvim_del_autocmd(M.watch_autocmd_id)
    M.watch_autocmd_id = nil
  end
  
  vim.notify("🛑 Auto-rebuild disabled", vim.log.levels.INFO)
end

-- Toggle auto-rebuild
function M.toggle_auto_rebuild()
  if M.auto_rebuild_enabled then
    M.disable_auto_rebuild()
  else
    M.enable_auto_rebuild()
  end
end

-- Show recent targets (legacy - now prefer pick_recent_targets)
function M.show_recent_targets()
  M.pick_recent_targets()
end

-- Clear recent targets
function M.clear_recent_targets()
  M.recent_targets = {}
  M.target_buffers = {}
  vim.notify("Cleared recent Bazel targets and buffers", vim.log.levels.INFO)
end

-- Function to get all Bazel targets with their rule types
local function get_bazel_targets()
  local handle = io.popen(bazel_in_container("bazel query --output=label_kind //... 2>/dev/null"))
  if not handle then
    vim.notify("Failed to run bazel query", vim.log.levels.ERROR)
    return {}
  end
  
  local result = handle:read("*a")
  handle:close()
  
  local targets = {}
  for line in result:gmatch("[^\r\n]+") do
    local rule_type, target = line:match("^(%S+)%s+rule%s+(.+)$")
    if rule_type and target then
      table.insert(targets, {
        target = target,
        rule_type = rule_type,
      })
    end
  end
  
  return targets
end

-- Function to get Bazel configs from .bazelrc files
local function get_bazel_configs()
  local configs = { "default" }
  local config_set = {}
  
  local bazelrc_files = {
    ".bazelrc",
    vim.fn.expand("~/.bazelrc"),
  }
  
  for _, bazelrc_path in ipairs(bazelrc_files) do
    local file = io.open(bazelrc_path, "r")
    if file then
      for line in file:lines() do
        local config_name = line:match("^%s*%w+:([%w_-]+)%s+%-%-")
        if config_name and not config_set[config_name] then
          config_set[config_name] = true
          table.insert(configs, config_name)
        end
      end
      file:close()
    end
  end
  
  return configs
end

-- Generate all combinations of targets and configs
local function get_target_config_combinations()
  local targets = get_bazel_targets()
  local configs = get_bazel_configs()
  local combinations = {}
  
  for _, target_info in ipairs(targets) do
    local target = target_info.target
    local rule_type = target_info.rule_type
    
    for _, config in ipairs(configs) do
      local display
      if config == "default" then
        display = string.format("%s [%s]", target, rule_type)
      else
        display = string.format("%s @ %s [%s]", target, config, rule_type)
      end
      
      table.insert(combinations, {
        display = display,
        target = target,
        config = config,
        rule_type = rule_type,
      })
    end
  end
  
  return combinations
end

-- Main function to show Bazel target+config picker
function M.pick_bazel_target_and_action(action_type)
  action_type = action_type or "run"
  
  local combinations = get_target_config_combinations()
  
  local entries = {}
  for _, combo in ipairs(combinations) do
    table.insert(entries, combo.display)
  end
  
  pickers.new({}, {
    prompt_title = "Select Target & Config to " .. action_type,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        local combo
        for _, c in ipairs(combinations) do
          if c.display == entry then
            combo = c
            break
          end
        end
        
        return {
          value = combo,
          display = entry,
          ordinal = entry,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection and selection.value then
          local combo = selection.value
          local target = combo.target
          local config = combo.config
          
          -- Store selected target
          vim.g.bazel_target = target
          vim.g.bazel_config = config
          
          -- Add to recent targets
          add_to_recent(target, config, action_type)
          
          local config_flag = ""
          if config ~= "default" then
            config_flag = "--config=" .. config
          end
          
          -- Execute the action
          if action_type == "debug" then
            M.execute_debug(target, config_flag)
          else
            -- TODO: improvement, throw a notification when the command execution terminates
            -- colorize the output
            local cmd = bazel_in_container("bazel " .. action_type .. " " .. config_flag .. " " .. target)
            vim.notify("Running: " .. cmd, vim.log.levels.INFO)
            vim.cmd("terminal " .. cmd)
          end
        end
      end)
      
      return true
    end,
  }):find()
end

-- Execute debug with auto-attach
function M.execute_debug(target, config_flag)
  local dap = require('dap')
  
  vim.notify('🚀 Starting Bazel: ' .. target, vim.log.levels.INFO)
  
  local cmd = bazel_in_container('bazel run ' .. config_flag .. ' ' .. target)
  local job_id = vim.fn.jobstart(
    cmd,
    {
      on_stdout = function(_, data)
        for _, line in ipairs(data) do
          if line ~= '' then
            print(line)
          end
        end
      end,
      on_stderr = function(_, data)
        for _, line in ipairs(data) do
          if line ~= '' then
            print(line)
          end
        end
      end,
    }
  )
  
  local function is_port_open(port)
    local handle = io.popen('ss -tuln | grep :' .. port)
    local result = handle:read('*a')
    handle:close()
    return result ~= ''
  end
  
  local max_attempts = 30
  local attempt = 0
  
  local timer = vim.loop.new_timer()
  timer:start(1000, 1000, vim.schedule_wrap(function()
    attempt = attempt + 1
    
    if is_port_open(5678) then
      timer:stop()
      vim.notify('🐛 Debugpy ready! Attaching...', vim.log.levels.INFO)
      
      vim.defer_fn(function()
        dap.run({
          type = 'python',
          request = 'attach',
          name = 'Attach to Bazel',
          connect = {
            host = '127.0.0.1',
            port = 5678,
          },
        })
      end, 500)
      
    elseif attempt >= max_attempts then
      timer:stop()
      vim.notify('❌ Timeout waiting for debugpy', vim.log.levels.ERROR)
    else
      vim.notify(string.format('⏳ Waiting for debugpy... (%d/%d)', attempt, max_attempts), vim.log.levels.INFO)
    end
  end))
end

-- Convenience functions for each action type
function M.pick_and_build()
  M.pick_bazel_target_and_action("build")
end

function M.pick_and_test()
  M.pick_bazel_target_and_action("test")
end

function M.pick_and_run()
  M.pick_bazel_target_and_action("run")
end

function M.pick_and_debug()
  M.pick_bazel_target_and_action("debug")
end

-- Quick actions on already selected target (legacy support)
function M.build_selected_target()
  if not vim.g.bazel_target then
    vim.notify("No Bazel target selected", vim.log.levels.WARN)
    return
  end
  
  local config_flag = ""
  if vim.g.bazel_config and vim.g.bazel_config ~= "default" then
    config_flag = "--config=" .. vim.g.bazel_config
  end
  
  vim.cmd("terminal bazel build " .. config_flag .. " " .. vim.g.bazel_target)
end

function M.test_selected_target()
  if not vim.g.bazel_target then
    vim.notify("No Bazel target selected", vim.log.levels.WARN)
    return
  end
  
  local config_flag = ""
  if vim.g.bazel_config and vim.g.bazel_config ~= "default" then
    config_flag = "--config=" .. vim.g.bazel_config
  end
  
  vim.cmd("terminal bazel test " .. config_flag .. " " .. vim.g.bazel_target)
end

function M.run_selected_target()
  if not vim.g.bazel_target then
    vim.notify("No Bazel target selected", vim.log.levels.WARN)
    return
  end
  
  local config_flag = ""
  if vim.g.bazel_config and vim.g.bazel_config ~= "default" then
    config_flag = "--config=" .. vim.g.bazel_config
  end
  
  vim.cmd("terminal bazel run " .. config_flag .. " " .. vim.g.bazel_target)
end

-- Setup keymaps
function M.setup(opts)
  opts = opts or {}
  
  -- Default keymaps with proper merging
  local default_keymaps = {
    build = "<leader>bb",
    test = "<leader>bt",
    run = "<leader>br",
    debug = "<leader>bd",
    toggle_auto_rebuild = "<leader>ba",
    show_recent = "<leader>bh",
    clear_recent = "<leader>bc",
  }
  
  local keymaps = vim.tbl_extend("force", default_keymaps, opts.keymaps or {})
  
  -- Set keymaps if they are not empty strings or nil
  if keymaps.build and keymaps.build ~= "" then
    vim.keymap.set("n", keymaps.build, M.pick_and_build, { desc = "Bazel: Pick target & build" })
  end
  
  if keymaps.test and keymaps.test ~= "" then
    vim.keymap.set("n", keymaps.test, M.pick_and_test, { desc = "Bazel: Pick target & test" })
  end
  
  if keymaps.run and keymaps.run ~= "" then
    vim.keymap.set("n", keymaps.run, M.pick_and_run, { desc = "Bazel: Pick target & run" })
  end
  
  if keymaps.debug and keymaps.debug ~= "" then
    vim.keymap.set("n", keymaps.debug, M.pick_and_debug, { desc = "Bazel: Pick target & debug" })
  end
  
  if keymaps.toggle_auto_rebuild and keymaps.toggle_auto_rebuild ~= "" then
    vim.keymap.set("n", keymaps.toggle_auto_rebuild, M.toggle_auto_rebuild, { desc = "Bazel: Toggle auto-rebuild" })
  end
  
  if keymaps.show_recent and keymaps.show_recent ~= "" then
    vim.keymap.set("n", keymaps.show_recent, M.pick_recent_targets, { desc = "Bazel: Show recent targets" })
  end
  
  if keymaps.clear_recent and keymaps.clear_recent ~= "" then
    vim.keymap.set("n", keymaps.clear_recent, M.clear_recent_targets, { desc = "Bazel: Clear recent targets" })
  end
  
  -- Create user commands
  vim.api.nvim_create_user_command("BazelBuild", M.pick_and_build, {})
  vim.api.nvim_create_user_command("BazelTest", M.pick_and_test, {})
  vim.api.nvim_create_user_command("BazelRun", M.pick_and_run, {})
  vim.api.nvim_create_user_command("BazelDebug", M.pick_and_debug, {})
  vim.api.nvim_create_user_command("BazelAutoRebuildEnable", M.enable_auto_rebuild, {})
  vim.api.nvim_create_user_command("BazelAutoRebuildDisable", M.disable_auto_rebuild, {})
  vim.api.nvim_create_user_command("BazelAutoRebuildToggle", M.toggle_auto_rebuild, {})
  vim.api.nvim_create_user_command("BazelShowRecent", M.pick_recent_targets, {})
  vim.api.nvim_create_user_command("BazelClearRecent", M.clear_recent_targets, {})
  vim.api.nvim_create_user_command("BazelRebuildRecent", execute_recent_targets, {})
end

return M
