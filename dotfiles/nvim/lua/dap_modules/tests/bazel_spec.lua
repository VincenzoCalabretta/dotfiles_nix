-- Tests for dap_modules/bazel.lua: pure command builders, last-target
-- persistence, and the start_job() ready-pattern watcher.
--
-- Not covered here (needs Telescope + a real `bazel` binary/workspace):
-- M.pick_targets / M.launch_test / M.launch_python / M.launch_rust and the
-- Bazel-invoking launchers (M.start_cpp / M.start_python / M.start_rust).
-- Those are integration surfaces, exercised by hand against a real project.

local bazel = require("dap_modules.bazel")

describe("dap_modules.bazel", function()
  describe("build_command()", function()
    it("runs on the host when container_name is nil", function()
      local cmd = bazel.build_command("gdbnf", "//foo:bar", nil, nil)
      assert.equals("bash", cmd[1])
      assert.equals("-c", cmd[2])
      assert.matches("bazel run %-%-config=gdbnf //foo:bar$", cmd[3])
    end)

    it("respects a custom bazel_bin", function()
      local cmd = bazel.build_command("gdbnf", "//foo:bar", nil, "bazelisk")
      assert.matches("bazelisk run %-%-config=gdbnf //foo:bar$", cmd[3])
    end)

    it("wraps the command in `docker exec` when container_name is set", function()
      local cmd = bazel.build_command("debugpy", "//foo:bar", "dev", "bazel")
      assert.same({ "docker", "exec", "-i", "dev", "bash", "-c" }, { cmd[1], cmd[2], cmd[3], cmd[4], cmd[5], cmd[6] })
      assert.matches("bazel run %-%-config=debugpy //foo:bar$", cmd[7])
    end)
  end)

  describe("gdb_setup_commands()", function()
    it("returns the pretty-printer/source/debug-dir commands in order", function()
      local cmds = bazel.gdb_setup_commands("/work", "/cache")
      assert.equals(5, #cmds)
      assert.equals("-enable-pretty-printing", cmds[1].text)
      assert.equals(false, cmds[1].ignoreFailures)
      assert.matches("stdcxx_printers%.py$", cmds[2].text)
      assert.equals("set print object on", cmds[3].text)
      assert.equals("directory /work", cmds[4].text)
      assert.equals("set debug-file-directory /cache", cmds[5].text)
    end)

    it("prepends `extra` commands ahead of the shared ones", function()
      local canary = { text = "set $nvim_dap_setup_ran = 1", ignoreFailures = false }
      local cmds = bazel.gdb_setup_commands("/work", "/cache", { canary })
      assert.equals(6, #cmds)
      assert.same(canary, cmds[1])
      assert.equals("-enable-pretty-printing", cmds[2].text)
    end)
  end)

  describe("printer_cmd", function()
    it("is exported and points at the bundled stdcxx printers", function()
      assert.is_string(bazel.printer_cmd)
      assert.matches("stdcxx_printers%.py$", bazel.printer_cmd)
    end)
  end)

  describe("save_last_target() / load_last_target()", function()
    local original_file

    before_each(function()
      original_file = bazel.last_target_file
      -- Redirect to a scratch file so the test never touches the real
      -- ~/.cache/nvim/nvim-dap-bazel/last_target.json used by the plugin.
      bazel.last_target_file = vim.fn.tempname()
    end)

    after_each(function()
      vim.fn.delete(bazel.last_target_file)
      bazel.last_target_file = original_file
    end)

    it("round-trips target and lang", function()
      bazel.save_last_target("//foo:bar", "cpp")
      local data = bazel.load_last_target()
      assert.equals("//foo:bar", data.target)
      assert.equals("cpp", data.lang)
    end)

    it("merges the optional `extra` table (e.g. the remote host)", function()
      bazel.save_last_target("//foo:bar", "cpp_remote", { host = "board_a" })
      local data = bazel.load_last_target()
      assert.equals("//foo:bar", data.target)
      assert.equals("cpp_remote", data.lang)
      assert.equals("board_a", data.host)
    end)

    it("returns nil when no file has been written yet", function()
      vim.fn.delete(bazel.last_target_file)
      assert.is_nil(bazel.load_last_target())
    end)
  end)

  describe("start_job()", function()
    it("fires on_ready ~1.5s after the ready pattern appears, then clears the job id on exit", function()
      local ready = false
      bazel.gdbserver_job_id = bazel.start_job(
        { "bash", "-c", "echo 'Listening on port 9999'" },
        "Listening on port 9999",
        "test-job",
        function() ready = true end
      )

      assert.is_number(bazel.gdbserver_job_id)
      assert.is_true(vim.wait(3000, function() return ready end, 50), "on_ready was not called in time")
      assert.is_true(vim.wait(1000, function() return bazel.gdbserver_job_id == nil end, 50),
        "job id was not cleared after the process exited")
    end)

    it("never fires on_ready when the pattern never appears", function()
      local ready = false
      bazel.start_job(
        { "bash", "-c", "echo 'nothing interesting here'" },
        "Listening on port 9999",
        "test-job-2",
        function() ready = true end
      )
      vim.wait(500)
      assert.is_false(ready)
    end)
  end)
end)
