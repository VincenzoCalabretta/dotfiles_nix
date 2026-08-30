-- Tests for dap_modules/remote.lua: the pure SSH/rsync/bazel command
-- builders, adapter-type naming, host selection, and the deploy_and_debug()
-- config guard clause.
--
-- Not covered here (needs a real `bazel`/`ssh`/`rsync` and a reachable
-- target): M.locate_artifact / M.deploy / M.start_gdbserver end to end.
-- Those are exercised against a real board — see the README's
-- "Remote deployment over SSH" section.

local remote = require("dap_modules.remote")

local function enter_temp_cwd()
  local original_cwd = vim.fn.getcwd()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  return function()
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    vim.fn.delete(dir, "rf")
  end
end

describe("dap_modules.remote", function()
  describe("sanitize()", function()
    it("collapses runs of non-alphanumeric characters into a single underscore", function()
      assert.equals("_foo_bar_baz", remote.sanitize("//foo:bar-baz"))
      assert.equals("apps_web_controller", remote.sanitize("apps.web/controller"))
    end)
  end)

  describe("bazel_build_cmd() / bazel_cquery_cmd()", function()
    it("builds a plain (no `bazel run`) build command", function()
      assert.same({ "bazel", "build", "--config=remote-arm64", "//foo:bar" },
        remote.bazel_build_cmd("remote-arm64", "//foo:bar"))
    end)

    it("builds a cquery asking for the first output file's path", function()
      local cmd = remote.bazel_cquery_cmd("remote-arm64", "//foo:bar")
      assert.same({
        "bazel", "cquery", "--config=remote-arm64", "//foo:bar",
        "--output=starlark", "--starlark:expr=target.files.to_list()[0].path",
      }, cmd)
    end)
  end)

  describe("ssh_prefix() / mkdir_cmd()", function()
    it("is just ssh when no ssh_opts are configured", function()
      assert.same({ "ssh" }, remote.ssh_prefix({ host = "user@host" }))
    end)

    it("splices in ssh_opts before the host", function()
      local host_cfg = { host = "user@host", ssh_opts = { "-i", "~/.ssh/id_board" } }
      assert.same({ "ssh", "-i", "~/.ssh/id_board" }, remote.ssh_prefix(host_cfg))
      assert.same(
        { "ssh", "-i", "~/.ssh/id_board", "user@host", "mkdir -p /srv/deploy/foo" },
        remote.mkdir_cmd(host_cfg, "/srv/deploy/foo")
      )
    end)
  end)

  describe("rsync_cmd()", function()
    local host_cfg = { host = "user@host" }

    it("syncs just the binary when there are no runfiles", function()
      local cmd = remote.rsync_cmd({ path = "/local/bin/app" }, host_cfg, "/srv/deploy/app")
      assert.same(
        { "rsync", "-az", "--delete", "-L", "/local/bin/app", "user@host:/srv/deploy/app/" },
        cmd
      )
    end)

    it("also syncs the runfiles directory when present", function()
      local cmd = remote.rsync_cmd(
        { path = "/local/bin/app", runfiles = "/local/bin/app.runfiles" },
        host_cfg, "/srv/deploy/app"
      )
      assert.same({
        "rsync", "-az", "--delete", "-L",
        "/local/bin/app", "/local/bin/app.runfiles",
        "user@host:/srv/deploy/app/",
      }, cmd)
    end)

    it("passes ssh_opts through via -e", function()
      local cmd = remote.rsync_cmd(
        { path = "/local/bin/app" },
        { host = "user@host", ssh_opts = { "-i", "~/.ssh/id_board" } },
        "/srv/deploy/app"
      )
      assert.same({
        "rsync", "-az", "--delete", "-L",
        "-e", "ssh -i ~/.ssh/id_board",
        "/local/bin/app", "user@host:/srv/deploy/app/",
      }, cmd)
    end)
  end)

  describe("gdbserver_remote_cmd() / gdbserver_ssh_cmd()", function()
    local cfg = { gdbserver_bin = "gdbserver", port = 1234 }

    it("pkills any stale process, then cds and starts gdbserver on the deployed binary", function()
      local remote_cmd = remote.gdbserver_remote_cmd(cfg, "app", "/srv/deploy/app")
      assert.equals(
        "pkill -f 'app' 2>/dev/null; cd /srv/deploy/app && gdbserver 127.0.0.1:1234 ./app",
        remote_cmd
      )
    end)

    it("wraps the remote command in an ssh -L tunnel to the same port", function()
      local host_cfg = { host = "user@host" }
      local cmd = remote.gdbserver_ssh_cmd(cfg, host_cfg, "app", "/srv/deploy/app")
      assert.same({
        "ssh", "-L", "1234:127.0.0.1:1234", "user@host",
        remote.gdbserver_remote_cmd(cfg, "app", "/srv/deploy/app"),
      }, cmd)
    end)

    it("splices ssh_opts in before the host on the tunnel command too", function()
      local host_cfg = { host = "user@host", ssh_opts = { "-i", "~/.ssh/id_board" } }
      local cmd = remote.gdbserver_ssh_cmd(cfg, host_cfg, "app", "/srv/deploy/app")
      assert.same(
        { "ssh", "-L", "1234:127.0.0.1:1234", "-i", "~/.ssh/id_board", "user@host" },
        { cmd[1], cmd[2], cmd[3], cmd[4], cmd[5], cmd[6] }
      )
    end)
  end)

  describe("adapter_type_for()", function()
    it("reuses the default \"gdb\" adapter for the default binary", function()
      assert.equals("gdb", remote.adapter_type_for("gdb"))
    end)

    it("derives a deterministic, sanitized adapter name for a cross gdb", function()
      assert.equals("gdb_remote_gdb_multiarch", remote.adapter_type_for("gdb-multiarch"))
    end)
  end)

  describe("pick_host()", function()
    it("errors and does not invoke the callback when no hosts are configured", function()
      local notified = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level) table.insert(notified, { msg = msg, level = level }) end

      local called = false
      remote.pick_host({ hosts = {} }, function() called = true end)

      vim.notify = orig_notify
      assert.is_false(called)
      assert.is_true(#notified > 0)
      assert.equals(vim.log.levels.ERROR, notified[1].level)
    end)

    it("auto-selects the only configured host without prompting", function()
      local picked
      remote.pick_host({ hosts = { only_one = { host = "user@host" } } }, function(h) picked = h end)
      assert.equals("only_one", picked)
    end)

    it("prompts via vim.ui.select when more than one host is configured", function()
      local orig_select = vim.ui.select
      local prompted_with
      vim.ui.select = function(items, _, on_choice)
        prompted_with = items
        on_choice(items[1])
      end

      local picked
      remote.pick_host({ hosts = { board_a = {}, board_b = {} } }, function(h) picked = h end)

      vim.ui.select = orig_select
      assert.same({ "board_a", "board_b" }, prompted_with)
      assert.equals("board_a", picked)
    end)
  end)

  describe("deploy_and_debug()", function()
    it("refuses to run and notifies when remote.bazel_config is unset", function()
      local cleanup = enter_temp_cwd()  -- ensures no stray .nvim-dap.lua applies

      local notified = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level) table.insert(notified, { msg = msg, level = level }) end

      local orig_locate = remote.locate_artifact
      local locate_called = false
      remote.locate_artifact = function() locate_called = true end

      remote.deploy_and_debug("cpp", "//foo:bar")

      vim.notify = orig_notify
      remote.locate_artifact = orig_locate
      cleanup()

      assert.is_false(locate_called, "the pipeline must not proceed without a bazel_config")
      assert.is_true(#notified > 0)
      assert.matches("cpp%.remote%.bazel_config is not set", notified[1].msg)
      assert.equals(vim.log.levels.ERROR, notified[1].level)
    end)
  end)
end)
