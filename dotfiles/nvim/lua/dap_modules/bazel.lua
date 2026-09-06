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

-- `extra` is an optional table merged into the saved record (e.g. { host = "board_a" }
-- for remote targets, so launch_last() knows which host to redeploy to).
function M.save_last_target(target, lang, extra)
  local data = { target = target, lang = lang }
  if extra then
    for k, v in pairs(extra) do data[k] = v end
  end
  local file = io.open(M.last_target_file, "w")
  if file then
    file:write(vim.fn.json_encode(data))
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

-- ── direnv activation ────────────────────────────────────────────────────────
-- Bazel workspaces under dap_modules/examples/ (leetcode_debug, in particular)
-- rely on a project-local flake devShell (via direnv) to put `bazel`/`gcc`/
-- `gdb` on PATH. That only happens automatically if whatever shell launched
-- Neovim had already `cd`ed through the workspace with direnv's hook active.
-- These helpers let the plugin activate that env itself for every job it
-- spawns, regardless of how Neovim was started -- without silently bypassing
-- direnv's one-time-per-path `direnv allow` trust gate, which exists
-- specifically so a `.envrc` can't run arbitrary shell code unattended.

-- Inspects `direnv status --json` for `workspace`. Returns:
--   "ok"      - a .envrc exists there and direnv has approved it
--   "blocked" - a .envrc exists there but direnv hasn't approved it yet
--   "none"    - no direnv binary, or no .envrc found -- run unwrapped
function M.direnv_state(workspace)
  if vim.fn.executable("direnv") ~= 1 then
    return "none"
  end
  -- `direnv status` only ever looks at the process's actual cwd (a trailing
  -- path argument is silently ignored), so shell out with `cd` first.
  local out = vim.fn.system({ "bash", "-c", string.format("cd %s && direnv status --json", workspace) })
  if vim.v.shell_error ~= 0 then
    return "none"
  end
  local ok, decoded = pcall(vim.fn.json_decode, out)
  if not ok or not decoded or not decoded.state then
    return "none"
  end
  -- JSON `null` decodes to the vim.NIL sentinel, not Lua nil -- direnv
  -- reports foundRC as null when no .envrc exists anywhere above `workspace`.
  local found_rc = decoded.state.foundRC
  if found_rc == nil or found_rc == vim.NIL then
    return "none"
  end
  return found_rc.allowed == 0 and "ok" or "blocked"
end

-- M.direnv_state() plus a notify when it comes back "blocked", so the
-- failure is reported once, up front, instead of manifesting later as a
-- missing binary. Returns the state so callers can also pass it to
-- direnv_wrap() without querying direnv twice.
function M.direnv_check(workspace)
  local state = M.direnv_state(workspace)
  if state == "blocked" then
    vim.notify(
      ("bazel_picker: direnv hasn't approved %s/.envrc yet -- run `direnv allow` there, then retry."):format(workspace),
      vim.log.levels.ERROR
    )
  end
  return state
end

-- Wraps `cmd` (a jobstart-style argv table) with `direnv exec workspace` when
-- direnv has approved a .envrc there. `direnv exec` loads that workspace's
-- env without changing the process's cwd, so the caller's own `cd` inside
-- `cmd` still applies.
function M.direnv_wrap(cmd, workspace, direnv_state)
  if direnv_state ~= "ok" then
    return cmd
  end
  local wrapped = { "direnv", "exec", workspace }
  vim.list_extend(wrapped, cmd)
  return wrapped
end

-- ── Command building ─────────────────────────────────────────────────────────
-- Returns a table suitable for vim.fn.jobstart().
-- Wraps in `docker exec` when container_name is set; runs on host otherwise.

function M.build_command(bazel_config, target, container_name, bazel_bin, direnv_state)
  local workspace = vim.fn.getcwd()
  local bazel_cmd = string.format(
    "cd %s && %s run --config=%s %s",
    workspace,
    bazel_bin or "bazel",
    bazel_config,
    target
  )

  if container_name then
    return { "docker", "exec", "-i", container_name, "bash", "-c", bazel_cmd }
  else
    return M.direnv_wrap({ "bash", "-c", bazel_cmd }, workspace, direnv_state)
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

-- Start a background job and auto-connect DAP when ready_pattern appears.
-- Both stdout and stderr are monitored since some tools (e.g. debugpy) write
-- their ready message to stderr.
-- on_ready is a callback invoked (after a 1s delay) when the pattern is matched.
-- Exported so dap_modules/remote.lua can reuse the same ready-pattern watcher
-- for gdbserver started over SSH instead of locally/in a container.
function M.start_job(cmd, ready_pattern, label, on_ready)
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
M.printer_cmd = _printer_cmd  -- exported for dap_modules/remote.lua's custom gdb adapters

-- Shared setupCommands for every dynamic gdb attach (local Bazel launch,
-- dual-target attach, remote SSH deploy). `extra` commands are run first —
-- e.g. the dual-target canary or the remote launcher's `file <local-binary>`
-- (see remote.lua for why that one is required there but not here).
function M.gdb_setup_commands(workspace, bazel_cache, extra)
  local cmds = {}
  if extra then vim.list_extend(cmds, extra) end
  vim.list_extend(cmds, {
    { text = "-enable-pretty-printing",    ignoreFailures = false },
    { text = _printer_cmd,                 ignoreFailures = true },
    { text = "set print object on",        ignoreFailures = true },
    { text = "directory " .. workspace,    ignoreFailures = false },
    { text = "set debug-file-directory " .. bazel_cache, ignoreFailures = true },
  })
  return cmds
end

local function connect_gdb(target, port, workspace, bazel_cache)
  local dap = require("dap")
  dap.run({
    name          = "Attach to gdbserver (Bazel) – " .. target,
    type          = "gdb",
    request       = "attach",
    target        = "localhost:" .. port,
    cwd           = workspace,
    setupCommands = M.gdb_setup_commands(workspace, bazel_cache),
  })
end

function M.start_cpp(target)
  local cfg       = require("dap_modules.project").load()
  local port      = cfg.cpp.gdbserver_port
  local workspace = vim.fn.getcwd()

  -- Docker containers have their own env; direnv on the host is irrelevant.
  local direnv_state = cfg.cpp.container_name and "none" or M.direnv_check(workspace)
  if direnv_state == "blocked" then return end

  M.save_last_target(target, "cpp")
  M.kill_gdbserver()

  local cmd = M.build_command(cfg.cpp.bazel_config, target,
                              cfg.cpp.container_name, cfg.cpp.bazel_bin, direnv_state)

  print(string.format("Starting gdbserver for: %s (port %d)", target, port))

  M.gdbserver_job_id = M.start_job(
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
  local cfg       = require("dap_modules.project").load()
  local workspace = vim.fn.getcwd()

  local direnv_state = cfg.python.container_name and "none" or M.direnv_check(workspace)
  if direnv_state == "blocked" then return end

  M.save_last_target(target, "python")
  M.kill_gdbserver()

  local port          = cfg.python.debugpy_port
  local path_mappings = cfg.python.path_mappings
  local cmd           = M.build_command(
    cfg.python.bazel_config, target, cfg.python.container_name, cfg.python.bazel_bin, direnv_state
  )

  print(string.format("Starting debugpy for: %s (port %d)", target, port))

  M.gdbserver_job_id = M.start_job(cmd, "Listening on", "debugpy", function()
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
    print("No previous target found. Use <leader>bC/bp/bu/bH to select one first.")
    return
  end
  print(string.format("Relaunching last target (%s): %s", data.lang, data.target))
  if data.lang == "python" then
    M.start_python(data.target)
  elseif data.lang == "rust" then
    M.start_rust(data.target)
  elseif data.lang == "cpp_remote" or data.lang == "rust_remote" then
    local base_lang = (data.lang == "rust_remote") and "rust" or "cpp"
    require("dap_modules.remote").deploy_and_debug(base_lang, data.target, data.host)
  else
    M.start_cpp(data.target)
  end
end

-- Run one bazel query per rule kind and merge results into a single Telescope
-- picker. Using separate queries avoids Bazel's lack of regex alternation
-- support in kind() filters. Exported so dap_modules/remote.lua can offer the
-- same target picker for remote deploys.
function M.pick_targets(queries, prompt_title, on_select)
  local cfg       = require("dap_modules.project").load()
  local workspace = vim.fn.getcwd()

  local direnv_state = cfg.cpp.container_name and "none" or M.direnv_check(workspace)
  if direnv_state == "blocked" then return end

  local all_targets = {}
  local errors = {}
  local remaining = #queries

  for _, query_kind in ipairs(queries) do
    local bazel_query = string.format(
      "cd %s && bazel query 'kind(%s, //...)' --keep_going",
      workspace,
      query_kind
    )

    local cmd
    if cfg.cpp.container_name then
      cmd = { "docker", "exec", cfg.cpp.container_name, "bash", "-c", bazel_query }
    else
      cmd = M.direnv_wrap({ "bash", "-c", bazel_query }, workspace, direnv_state)
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
          -- A successful query still writes routine chatter to stderr (direnv's
          -- own "loading .envrc" lines, Bazel's "Loading: N packages loaded"),
          -- so only surface stderr when it actually explains an empty result.
          if #all_targets == 0 then
            if #errors > 0 then
              vim.notify(table.concat(errors, "\n"), vim.log.levels.ERROR, { title = "bazel query failed" })
            else
              vim.notify("No targets found", vim.log.levels.WARN, { title = "bazel query" })
            end
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
          if line and line ~= "" then table.insert(errors, line) end
        end
      end,
    })
  end
end

-- ── Telescope pickers ─────────────────────────────────────────────────────────

function M.launch_test()
  M.pick_targets({ "cc_binary", "cc_test" }, "Select C++ Target", M.start_cpp)
end

function M.launch_python()
  M.pick_targets({ "py_binary", "py_test" }, "Select Python Target", M.start_python)
end

function M.launch_rust()
  M.pick_targets({ "rust_binary", "rust_test" }, "Select Rust Target", M.start_rust)
end

function M.launch_rust_simple()
  vim.ui.input({ prompt = "Rust Bazel target: " }, function(target)
    if target and target ~= "" then M.start_rust(target) end
  end)
end

-- ── Dual-target attach (both gdbservers already running via tmux) ──────────
-- gdbserver is launched by an external tmux script, not by nvim. Just attach
-- to both ports.

function M.connect_dual()
  local dap       = require("dap")
  local workspace = vim.fn.getcwd()
  local cache     = vim.fn.expand("~/.cache/dev/bazel")

  local setup = M.gdb_setup_commands(workspace, cache, {
    { text = "set $nvim_dap_setup_ran = 1", ignoreFailures = false },
  })

  local second_config = {
    name          = "Secondary (:1235)",
    type          = "gdb_dual",
    request       = "attach",
    target        = "localhost:1235",
    cwd           = workspace,
    setupCommands = setup,
  }

  -- event_stopped fires the moment the first target's gdb attaches and pauses
  -- it. This is the earliest reliable post-configurationDone signal: by the
  -- time gdbserver sends "stopped", the full DAP handshake (initialize →
  -- configurationDone) is complete. event_continued is wrong here because the
  -- first target stays paused after attach (user hasn't resumed it), so it
  -- never fires. The fallback timer guards against edge cases where
  -- event_stopped is missed.
  local second_started = false
  local function start_second()
    if second_started then return end
    second_started = true
    dap.listeners.after.event_stopped["dual_connect_second"] = nil
    dap.run(second_config)
  end

  dap.listeners.after.event_stopped["dual_connect_second"] = start_second
  vim.defer_fn(start_second, 5000)

  dap.run({
    name          = "Primary (:1234)",
    type          = "gdb_dual",
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
  local cfg       = require("dap_modules.project").load()
  local workspace = vim.fn.getcwd()

  local direnv_state = cfg.rust.container_name and "none" or M.direnv_check(workspace)
  if direnv_state == "blocked" then return end

  M.save_last_target(target, "rust")
  M.kill_gdbserver()

  local port = cfg.rust.gdbserver_port
  local cmd  = M.build_command(cfg.rust.bazel_config, target, cfg.rust.container_name, cfg.rust.bazel_bin, direnv_state)

  print(string.format("Starting gdbserver for Rust: %s (port %d)", target, port))
  M.gdbserver_job_id = M.start_job(cmd, "Listening on port " .. port, "gdbserver", function()
    require("dap").continue()
  end)
end

return M
