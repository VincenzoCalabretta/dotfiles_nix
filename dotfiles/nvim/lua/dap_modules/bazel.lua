-- ~/.config/nvim/lua/dap_modules/bazel.lua
-- Bazel + optional Docker integration for gdbserver (C++) and debugpy (Python).
-- Project-specific settings (container name, ports, bazel config flags) are
-- read from .nvim-dap.lua at launch time so changes take effect immediately
-- without restarting Neovim.

local M = {
  gdbserver_job_id = nil,
  gdbserver_timer  = nil,

  -- Persistent cache so the last-used target survives Neovim restarts.
  -- Stores both the target label and the language so we know how to relaunch.
  cache_dir        = vim.fn.stdpath("cache") .. "/nvim-dap-bazel",
  last_target_file = vim.fn.stdpath("cache") .. "/nvim-dap-bazel/last_target.json",
}

vim.fn.mkdir(M.cache_dir, "p")

-- ── Persistence ──────────────────────────────────────────────────────────────

function M.save_last_target(target, lang)
  local file = io.open(M.last_target_file, "w")
  if file then
    file:write(vim.fn.json_encode({ target = target, lang = lang }))
    file:close()
  end
end

function M.load_last_target()
  local file = io.open(M.last_target_file, "r")
  if file then
    local raw = file:read("*all")
    file:close()
    local ok, data = pcall(vim.fn.json_decode, raw)
    if ok and data then return data end
  end
  return nil
end

-- ── Command building ─────────────────────────────────────────────────────────
-- Returns a table suitable for vim.fn.jobstart().
-- Wraps in `docker exec` when container_name is set; runs on host otherwise.

function M.build_command(bazel_config, target, container_name, bazel_bin)
  local bazel_cmd = string.format(
    "cd %s && %s run --config=%s %s",
    vim.fn.getcwd(),
    bazel_bin or "bazel",
    bazel_config,
    target
  )

  if container_name then
    return { "docker", "exec", "-i", container_name, "bash", "-c", bazel_cmd }
  else
    return { "bash", "-c", bazel_cmd }
  end
end

-- ── Process management ───────────────────────────────────────────────────────

function M.kill_gdbserver()
  if M.gdbserver_job_id then
    vim.fn.jobstop(M.gdbserver_job_id)
    M.gdbserver_job_id = nil
    print("Killed gdbserver/debugpy process")
  end

  if M.gdbserver_timer then
    M.gdbserver_timer:stop()
    M.gdbserver_timer:close()
    M.gdbserver_timer = nil
  end
end

-- Poll localhost:PORT until connectable, then fire callback.
-- Avoids the hardcoded 1500ms delay in start_job().
local function wait_for_port(host, port, timeout_ms, on_ready)
  local deadline = vim.loop.now() + timeout_ms
  local timer    = vim.loop.new_timer()

  timer:start(0, 100, vim.schedule_wrap(function()  -- check every 100ms
    if vim.loop.now() > deadline then
      timer:stop()
      timer:close()
      vim.notify("Timed out waiting for port " .. port, vim.log.levels.ERROR)
      return
    end

    -- Attempt a non-blocking TCP connect
    local tcp = vim.loop.new_tcp()
    tcp:connect(host, port, function(err)
      tcp:close()
      if not err then
        timer:stop()
        timer:close()
        on_ready()   -- port is open, fire immediately
      end
      -- err means still not ready, loop continues
    end)
  end))

  return timer
end

-- Internal: start a background job and auto-connect DAP when ready_pattern appears.
-- Both stdout and stderr are monitored since some tools (e.g. debugpy) write
-- their ready message to stderr.
-- on_ready is a callback invoked (after a 1s delay) when the pattern is matched.
local function start_job(cmd, ready_pattern, label, on_ready)
  local triggered = false  -- fire on_ready exactly once

  local function handle_line(line)
    if line and line ~= "" then
      print(label .. ": " .. line)
    end
    if not triggered and line and line:match(ready_pattern) then
      triggered = true
      vim.defer_fn(on_ready, 1500)
    end
  end

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if not data then return end
      for _, line in ipairs(data) do handle_line(line) end
    end,
    on_stderr = function(_, data)
      if not data then return end
      for _, line in ipairs(data) do handle_line(line) end
    end,
    on_exit = function(_, exit_code)
      print(label .. " exited with code: " .. exit_code)
      M.gdbserver_job_id = nil
    end,
  })

  if job_id == 0 then
    print("Failed to start " .. label .. " (bad command?)")
    return nil
  elseif job_id == -1 then
    print("Invalid " .. label .. " command")
    return nil
  end
  return job_id
end

-- ── C++ launcher (gdbserver) ─────────────────────────────────────────────────
--
-- Load libstdc++ pretty-printers from the bundled copy in the nvim config.
-- The script checks bundled printers first, then system paths, so it works
-- on any machine the config is synced to without extra system packages.
local _printer_cmd = "source " .. vim.fn.stdpath('config') .. '/gdb/stdcxx_printers.py'

local function connect_gdb(target, port, workspace, bazel_cache)
  local dap = require("dap")
  dap.run({
    name    = "Attach to gdbserver (Bazel) – " .. target,
    type    = "gdb",
    request = "attach",
    target  = "localhost:" .. port,
    cwd     = workspace,
    setupCommands = {
      { text = "-enable-pretty-printing",    ignoreFailures = false },
      { text = _printer_cmd,                 ignoreFailures = true },
      { text = "set print object on",        ignoreFailures = true },
      { text = "directory " .. workspace,    ignoreFailures = false },
      { text = "set debug-file-directory " .. bazel_cache, ignoreFailures = true },
    },
  })
end

function M.start_cpp(target)
  local cfg       = require("dap_modules.project").load()
  local port      = cfg.cpp.gdbserver_port
  local workspace = vim.fn.getcwd()

  M.save_last_target(target, "cpp")
  M.kill_gdbserver()

  local cmd = M.build_command(cfg.cpp.bazel_config, target,
                              cfg.cpp.container_name, cfg.cpp.bazel_bin)

  print(string.format("Starting gdbserver for: %s (port %d)", target, port))

  M.gdbserver_job_id = start_job(
    cmd,
    "Listening on port " .. port,
    "gdbserver",
    function()
      connect_gdb(target, port, workspace, cfg.cpp.bazel_cache)
    end
  )
end

-- ── Python launcher (debugpy) ────────────────────────────────────────────────

function M.start_python(target)
  local cfg = require("dap_modules.project").load()
  M.save_last_target(target, "python")
  M.kill_gdbserver()

  local port          = cfg.python.debugpy_port
  local path_mappings = cfg.python.path_mappings
  local cmd           = M.build_command(
    cfg.python.bazel_config, target, cfg.python.container_name, cfg.python.bazel_bin
  )

  print(string.format("Starting debugpy for: %s (port %d)", target, port))

  M.gdbserver_job_id = start_job(cmd, "Listening on", "debugpy", function()
    print("Connecting DAP to debugpy on 127.0.0.1:" .. port)

    local dap          = require("dap")
    local adapter_type = "python_bazel_" .. port

    -- Use 127.0.0.1 explicitly instead of "localhost": on systems where
    -- /etc/hosts maps localhost to ::1 first, "localhost" resolves to IPv6
    -- while debugpy binds to 0.0.0.0 (IPv4 only), causing ECONNREFUSED.
    dap.adapters[adapter_type] = {
      type = "server",
      host = "127.0.0.1",
      port = port,
    }

    -- dap.run() takes an explicit config, bypassing dap.configurations
    -- entirely so there is no stale-config race with dap.continue().
    dap.run({
      name         = "Attach to debugpy (Bazel) – " .. target,
      type         = adapter_type,
      request      = "attach",
      connect      = { host = "127.0.0.1", port = port },
      pathMappings = path_mappings,
      justMyCode   = false,
    })
  end)
end

-- ── Public launchers ─────────────────────────────────────────────────────────

-- Re-launch the last used target using the correct language launcher
function M.launch_last()
  local data = M.load_last_target()
  if not data or not data.target or data.target == "" then
    print("No previous target found. Use <leader>dt or <leader>dp to select one first.")
    return
  end
  print(string.format("Relaunching last target (%s): %s", data.lang, data.target))
  if data.lang == "python" then
    M.start_python(data.target)
  elseif data.lang == "rust" then
    M.start_rust(data.target)
  else
    M.start_cpp(data.target)
  end
end

-- Internal: run one bazel query per rule kind and merge results into a single
-- Telescope picker. Using separate queries avoids Bazel's lack of regex
-- alternation support in kind() filters.
local function pick_bazel_targets_multi(queries, prompt_title, on_select)
  local cfg = require("dap_modules.project").load()
  local all_targets = {}
  local remaining = #queries

  for _, query_kind in ipairs(queries) do
    local bazel_query = string.format(
      "cd %s && bazel query 'kind(%s, //...)' --keep_going 2>/dev/null",
      vim.fn.getcwd(),
      query_kind
    )

    local cmd
    if cfg.cpp.container_name then
      cmd = string.format("docker exec %s bash -c \"%s\"", cfg.cpp.container_name, bazel_query)
    else
      cmd = "bash -c \"" .. bazel_query .. "\""
    end

    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              table.insert(all_targets, line)
            end
          end
        end
        remaining = remaining - 1
        -- Only open the picker once all queries have finished
        if remaining == 0 then
          if #all_targets == 0 then
            print("No targets found")
            return
          end

          local pickers      = require("telescope.pickers")
          local finders      = require("telescope.finders")
          local conf         = require("telescope.config").values
          local actions      = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          pickers.new({}, {
            prompt_title = prompt_title,
            finder       = finders.new_table({ results = all_targets }),
            sorter       = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, _)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then on_select(selection[1]) end
              end)
              return true
            end,
          }):find()
        end
      end,
      on_stderr = function(_, data)
        if not data then return end
        for _, line in ipairs(data) do
          if line and line ~= "" then print("Query error: " .. line) end
        end
      end,
    })
  end
end

-- ── Telescope pickers ─────────────────────────────────────────────────────────

function M.launch_test()
  pick_bazel_targets_multi({ "cc_binary", "cc_test" }, "Select C++ Target", M.start_cpp)
end

function M.launch_python()
  pick_bazel_targets_multi({ "py_binary", "py_test" }, "Select Python Target", M.start_python)
end

function M.launch_rust()
  pick_bazel_targets_multi({ "rust_binary", "rust_test" }, "Select Rust Target", M.start_rust)
end

function M.launch_rust_simple()
  vim.ui.input({ prompt = "Rust Bazel target: " }, function(target)
    if target and target ~= "" then M.start_rust(target) end
  end)
end

-- ── SIL attach (FSW + SIM already running via tmux) ─────────────────────────
-- gdbserver is launched by sil_tmux.sh, not by nvim. Just attach to both ports.

function M.connect_sil()
  local dap       = require("dap")
  local workspace = vim.fn.getcwd()
  local cache     = vim.fn.expand("~/.cache/dev/bazel")

  local setup = {
    { text = "set $nvim_dap_setup_ran = 1", ignoreFailures = false },
    { text = "-enable-pretty-printing",     ignoreFailures = false },
    { text = _printer_cmd,                  ignoreFailures = true },
    { text = "set print object on",         ignoreFailures = true },
    { text = "directory " .. workspace,    ignoreFailures = false },
    { text = "set debug-file-directory " .. cache, ignoreFailures = true },
  }

  local sim_config = {
    name          = "SIM (SIL :1235)",
    type          = "gdb_sil",
    request       = "attach",
    target        = "localhost:1235",
    cwd           = workspace,
    setupCommands = setup,
  }

  -- event_stopped fires the moment FSW's gdb attaches and pauses the target.
  -- This is the earliest reliable post-configurationDone signal: by the time
  -- gdbserver sends "stopped", the full DAP handshake (initialize →
  -- configurationDone) is complete. event_continued is wrong here because
  -- FSW stays paused after attach (user hasn't resumed it), so it never fires.
  -- The fallback timer guards against edge cases where event_stopped is missed.
  local sim_started = false
  local function start_sim()
    if sim_started then return end
    sim_started = true
    dap.listeners.after.event_stopped["sil_connect_sim"] = nil
    dap.run(sim_config)
  end

  dap.listeners.after.event_stopped["sil_connect_sim"] = start_sim
  vim.defer_fn(start_sim, 5000)

  dap.run({
    name          = "FSW (SIL :1234)",
    type          = "gdb_sil",
    request       = "attach",
    target        = "localhost:1234",
    cwd           = workspace,
    setupCommands = setup,
  })
end

-- ── Simple manual-input fallbacks ────────────────────────────────────────────

function M.launch_test_simple()
  vim.ui.input({ prompt = "C++ Bazel target: " }, function(target)
    if target and target ~= "" then M.start_cpp(target) end
  end)
end

function M.launch_python_simple()
  vim.ui.input({ prompt = "Python Bazel target: " }, function(target)
    if target and target ~= "" then M.start_python(target) end
  end)
end

function M.start_rust(target)
  local cfg = require("dap_modules.project").load()
  M.save_last_target(target, "rust")
  M.kill_gdbserver()

  local port = cfg.rust.gdbserver_port
  local cmd  = M.build_command(cfg.rust.bazel_config, target, cfg.rust.container_name, cfg.rust.bazel_bin)

  print(string.format("Starting gdbserver for Rust: %s (port %d)", target, port))
  M.gdbserver_job_id = start_job(cmd, "Listening on port " .. port, "gdbserver", function()
    require("dap").continue()
  end)
end

return M
