-- ~/.config/nvim/lua/dap_modules/remote.lua
-- Cross-compiled Bazel targets deployed to a remote device over SSH and
-- debugged via gdbserver, with the debug port tunneled back over SSH.
--
-- Pipeline for a single launch (see M.deploy_and_debug):
--   1. bazel build --config=<cross-config> <target>           (locate_artifact)
--   2. bazel cquery ... --output=starlark  →  local output path
--   3. rsync the binary (+ its .runfiles tree, dereferenced) to the target  (deploy)
--   4. one `ssh -L port:127.0.0.1:port host 'gdbserver ...'` job that both
--      forwards the port AND runs the remote process                       (start_gdbserver)
--   5. dap.run() attaches local gdb to localhost:<port>                    (attach)
--
-- Why step 5 needs an explicit `file <local-binary>` setupCommand, unlike
-- bazel.lua's local/devcontainer launchers: GDB normally discovers the
-- executable by asking gdbserver for the path it was launched with
-- (qXfer:exec-file:read) and then opening *that same path* locally. In the
-- local and devcontainer cases that path happens to already exist on the
-- host (same machine, or an identically-mounted volume). On a genuinely
-- separate remote host that path never exists locally, so GDB has to be
-- told explicitly which local file carries the matching debug info — the
-- one this module just built and copied over.
--
-- Only one remote session is expected to be active at a time (by design —
-- see the README), so this module reuses bazel.lua's single job-id slot
-- (M.gdbserver_job_id) for cleanup via the existing <M-t> / VimLeavePre
-- hooks instead of tracking its own.
--
-- The command-builder functions below (bazel_build_cmd, mkdir_cmd,
-- rsync_cmd, ...) are pure — they only assemble argv tables/strings, no I/O
-- — specifically so tests/remote_spec.lua can assert on their shape without
-- needing real bazel/ssh/rsync binaries or network access.

local M = {}

local bazel = require("dap_modules.bazel")

-- Turn a Bazel target label (or anything else) into a filesystem-safe
-- component, used for the target's own subdirectory under `workdir`.
function M.sanitize(s)
  return (s:gsub("[^%w]+", "_"))
end

-- ── Job helper ───────────────────────────────────────────────────────────────
-- Unlike bazel.start_job() (which watches a long-running process for a ready
-- line), the build/query/rsync steps here must run to completion before the
-- next step starts. `opts` is forwarded to jobstart (e.g. { cwd = workspace }).
local function run_to_completion(cmd, opts, label, on_done)
  local out = {}
  local function collect(_, data)
    if not data then return end
    for _, line in ipairs(data) do
      if line ~= "" then
        table.insert(out, line)
        print(label .. ": " .. line)
      end
    end
  end

  vim.fn.jobstart(cmd, vim.tbl_extend("force", opts or {}, {
    on_stdout = collect,
    on_stderr = collect,
    on_exit   = function(_, code) on_done(code == 0, out) end,
  }))
end

-- ── Pure command builders ─────────────────────────────────────────────────────

function M.bazel_build_cmd(bazel_config, target)
  return { "bazel", "build", "--config=" .. bazel_config, target }
end

function M.bazel_cquery_cmd(bazel_config, target)
  return {
    "bazel", "cquery", "--config=" .. bazel_config, target,
    "--output=starlark", "--starlark:expr=target.files.to_list()[0].path",
  }
end

function M.ssh_prefix(host_cfg)
  local prefix = { "ssh" }
  if host_cfg.ssh_opts then vim.list_extend(prefix, host_cfg.ssh_opts) end
  return prefix
end

function M.mkdir_cmd(host_cfg, remote_workdir)
  local cmd = M.ssh_prefix(host_cfg)
  vim.list_extend(cmd, { host_cfg.host, "mkdir -p " .. remote_workdir })
  return cmd
end

-- `-L` dereferences the runfiles symlink farm (Bazel runfiles are usually
-- symlinks back into the execroot, meaningless on the target) into real
-- files. `--delete` is safe because remote_workdir is scoped to one target
-- (see M.sanitize() and M.deploy_and_debug()), never a directory shared
-- across targets.
function M.rsync_cmd(artifact, host_cfg, remote_workdir)
  local cmd = { "rsync", "-az", "--delete", "-L" }
  if host_cfg.ssh_opts and #host_cfg.ssh_opts > 0 then
    vim.list_extend(cmd, { "-e", "ssh " .. table.concat(host_cfg.ssh_opts, " ") })
  end
  table.insert(cmd, artifact.path)
  if artifact.runfiles then table.insert(cmd, artifact.runfiles) end
  table.insert(cmd, host_cfg.host .. ":" .. remote_workdir .. "/")
  return cmd
end

-- The remote shell command run over SSH. The leading `pkill` is defensive:
-- it clears out a gdbserver an earlier, uncleanly-terminated nvim session
-- may have left bound to the port.
function M.gdbserver_remote_cmd(cfg, remote_bin_name, remote_workdir)
  return string.format(
    "pkill -f '%s' 2>/dev/null; cd %s && %s 127.0.0.1:%d ./%s",
    remote_bin_name, remote_workdir, cfg.gdbserver_bin or "gdbserver", cfg.port, remote_bin_name
  )
end

-- A single ssh invocation both forwards the port (-L) and runs the remote
-- command, so killing this one job (bazel.kill_gdbserver(), already wired to
-- <M-t> / VimLeavePre) tears down the tunnel and the remote process together.
function M.gdbserver_ssh_cmd(cfg, host_cfg, remote_bin_name, remote_workdir)
  local cmd = { "ssh", "-L", string.format("%d:127.0.0.1:%d", cfg.port, cfg.port) }
  if host_cfg.ssh_opts then vim.list_extend(cmd, host_cfg.ssh_opts) end
  vim.list_extend(cmd, { host_cfg.host, M.gdbserver_remote_cmd(cfg, remote_bin_name, remote_workdir) })
  return cmd
end

-- dap adapter type to use for a given local gdb binary: reuses the "gdb"
-- adapter already set up in config.lua for the default, otherwise a
-- deterministic per-binary name for a custom cross/multiarch adapter.
function M.adapter_type_for(gdb_bin)
  if gdb_bin == "gdb" then return "gdb" end
  return "gdb_remote_" .. M.sanitize(gdb_bin)
end

-- ── 1-2. Build + locate the artifact ─────────────────────────────────────────
-- Uses `bazel build` (never `bazel run`: the host can't execute a foreign-arch
-- binary) then `bazel cquery` to get the exact output path — more robust than
-- reconstructing the bazel-bin layout by hand. Returns
-- { path = <local abs path>, runfiles = <local abs path or nil> } via on_done,
-- or nil on failure.
function M.locate_artifact(workspace, bazel_config, target, on_done)
  vim.notify(string.format("[Remote] bazel build --config=%s %s", bazel_config, target), vim.log.levels.INFO)

  run_to_completion(
    M.bazel_build_cmd(bazel_config, target),
    { cwd = workspace }, "bazel build",
    function(ok)
      if not ok then
        vim.notify("[Remote] Build failed: " .. target, vim.log.levels.ERROR)
        on_done(nil)
        return
      end

      run_to_completion(
        M.bazel_cquery_cmd(bazel_config, target),
        { cwd = workspace }, "bazel cquery",
        function(qok, lines)
          if not qok or #lines == 0 then
            vim.notify("[Remote] Could not resolve build artifact for " .. target, vim.log.levels.ERROR)
            on_done(nil)
            return
          end

          -- The path cquery prints is workspace-relative. Some Bazel
          -- versions print extra analysis-phase lines first, so take the
          -- last non-empty line rather than lines[1].
          local rel      = lines[#lines]
          local path     = workspace .. "/" .. rel
          local runfiles = path .. ".runfiles"

          on_done({
            path     = path,
            runfiles = vim.fn.isdirectory(runfiles) == 1 and runfiles or nil,
          })
        end
      )
    end
  )
end

-- ── 3. Deploy ─────────────────────────────────────────────────────────────────
function M.deploy(artifact, host_cfg, remote_workdir, on_done)
  run_to_completion(M.mkdir_cmd(host_cfg, remote_workdir), {}, "ssh mkdir", function(ok)
    if not ok then
      vim.notify("[Remote] Could not create " .. remote_workdir .. " on " .. host_cfg.host, vim.log.levels.ERROR)
      on_done(false)
      return
    end

    vim.notify("[Remote] rsync -> " .. host_cfg.host .. ":" .. remote_workdir, vim.log.levels.INFO)
    run_to_completion(M.rsync_cmd(artifact, host_cfg, remote_workdir), {}, "rsync", function(rok)
      if not rok then
        vim.notify("[Remote] rsync to " .. host_cfg.host .. " failed", vim.log.levels.ERROR)
      end
      on_done(rok)
    end)
  end)
end

-- ── 4. Start gdbserver + tunnel ──────────────────────────────────────────────
function M.start_gdbserver(cfg, host_cfg, remote_bin_name, remote_workdir, on_ready)
  bazel.kill_gdbserver()
  vim.notify(
    string.format("[Remote] Starting gdbserver on %s (port %d)...", host_cfg.host, cfg.port),
    vim.log.levels.INFO
  )

  bazel.gdbserver_job_id = bazel.start_job(
    M.gdbserver_ssh_cmd(cfg, host_cfg, remote_bin_name, remote_workdir),
    "Listening on port " .. cfg.port,
    "gdbserver@" .. host_cfg.host,
    on_ready
  )
end

-- ── 5. Attach ─────────────────────────────────────────────────────────────────

-- Registers (once) a custom adapter for a non-default gdb_bin, and returns
-- the adapter type to pass to dap.run().
local function ensure_adapter(gdb_bin)
  local dap           = require("dap")
  local adapter_type  = M.adapter_type_for(gdb_bin)
  if adapter_type ~= "gdb" and not dap.adapters[adapter_type] then
    dap.adapters[adapter_type] = {
      type    = "executable",
      command = gdb_bin,
      args    = { "-iex", bazel.printer_cmd, "-i", "dap" },
    }
  end
  return adapter_type
end

function M.attach(lang_cfg, cfg, artifact_path)
  local dap       = require("dap")
  local workspace = vim.fn.getcwd()
  local cache     = lang_cfg.bazel_cache or vim.fn.expand("~/.cache/dev/bazel")
  local adapter   = ensure_adapter(cfg.gdb_bin or "gdb")

  local setup = bazel.gdb_setup_commands(workspace, cache, {
    { text = "file " .. artifact_path, ignoreFailures = false },
  })

  dap.run({
    name          = "Remote gdbserver (" .. artifact_path .. ")",
    type          = adapter,
    request       = "attach",
    target        = "localhost:" .. cfg.port,
    cwd           = workspace,
    setupCommands = setup,
  })
end

-- ── Host selection ────────────────────────────────────────────────────────────

function M.pick_host(cfg, on_selected)
  local names = vim.tbl_keys(cfg.hosts or {})
  if #names == 0 then
    vim.notify(
      "[Remote] No hosts configured — add entries under <lang>.remote.hosts in .nvim-dap.lua",
      vim.log.levels.ERROR
    )
    return
  end
  table.sort(names)
  if #names == 1 then
    on_selected(names[1])
    return
  end
  vim.ui.select(names, { prompt = "Remote host: " }, function(choice)
    if choice then on_selected(choice) end
  end)
end

-- ── Public entry points ───────────────────────────────────────────────────────

-- lang: "cpp" or "rust". host_name is optional — when omitted, and more than
-- one host is configured, M.pick_host() prompts for one.
function M.deploy_and_debug(lang, target, host_name)
  local project  = require("dap_modules.project").load()
  local lang_cfg = project[lang]
  local cfg      = lang_cfg and lang_cfg.remote

  if not cfg or not cfg.bazel_config then
    vim.notify(
      string.format(
        "[Remote] %s.remote.bazel_config is not set in .nvim-dap.lua — see dap_modules/README.md#remote-deployment-over-ssh",
        lang
      ),
      vim.log.levels.ERROR
    )
    return
  end

  local function proceed(host_key)
    local host_cfg = cfg.hosts[host_key]
    if not host_cfg or not host_cfg.host then
      vim.notify("[Remote] Unknown or misconfigured host: " .. tostring(host_key), vim.log.levels.ERROR)
      return
    end

    bazel.save_last_target(target, lang .. "_remote", { host = host_key })

    local workspace = vim.fn.getcwd()
    M.locate_artifact(workspace, cfg.bazel_config, target, function(artifact)
      if not artifact then return end

      local remote_bin_name = vim.fn.fnamemodify(artifact.path, ":t")
      local remote_workdir  = (cfg.workdir or "/tmp/nvim-dap-deploy") .. "/" .. M.sanitize(target)

      M.deploy(artifact, host_cfg, remote_workdir, function(ok)
        if not ok then return end

        M.start_gdbserver(cfg, host_cfg, remote_bin_name, remote_workdir, function()
          M.attach(lang_cfg, cfg, artifact.path)
        end)
      end)
    end)
  end

  if host_name then
    proceed(host_name)
  else
    M.pick_host(cfg, proceed)
  end
end

-- Telescope picker over Bazel targets, then deploy_and_debug(). Mirrors
-- bazel.lua's launch_test()/launch_rust() but for the remote pipeline.
function M.launch(lang)
  lang = lang or "cpp"
  local queries = (lang == "rust") and { "rust_binary", "rust_test" } or { "cc_binary", "cc_test" }
  local title   = "Select Remote " .. lang .. " Target"
  bazel.pick_targets(queries, title, function(target)
    M.deploy_and_debug(lang, target)
  end)
end

return M
