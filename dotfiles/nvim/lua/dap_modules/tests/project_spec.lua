-- Tests for dap_modules/project.lua: default shape and .nvim-dap.lua merging.
-- Run via tests/run_tests.sh (plenary busted-style harness).

local project = require("dap_modules.project")

-- Creates an empty temp dir, chdirs into it, and returns a cleanup function
-- that restores the original cwd and removes the temp dir.
local function enter_temp_cwd()
  local original_cwd = vim.fn.getcwd()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  return dir, function()
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    vim.fn.delete(dir, "rf")
  end
end

local function write_file(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

describe("dap_modules.project", function()
  describe("defaults", function()
    it("gives cpp and rust a remote sub-table with the documented shape", function()
      for _, lang in ipairs({ "cpp", "rust" }) do
        local remote = project.defaults[lang].remote
        assert.is_table(remote)
        assert.equals("/tmp/nvim-dap-deploy", remote.workdir)
        assert.equals("gdb", remote.gdb_bin)
        assert.equals("gdbserver", remote.gdbserver_bin)
        assert.equals(1234, remote.port)
        assert.is_table(remote.hosts)
        assert.equals(0, vim.tbl_count(remote.hosts))
        assert.is_nil(remote.bazel_config)
      end
    end)

    it("gives cpp and rust their own remote table instances", function()
      -- Regression guard: both langs must get independent copies from
      -- remote_defaults(), not the same shared table.
      assert.are_not.equal(project.defaults.cpp.remote, project.defaults.rust.remote)
    end)
  end)

  describe("load()", function()
    it("returns a fresh copy of the defaults when no .nvim-dap.lua exists", function()
      local _, cleanup = enter_temp_cwd()
      local cfg = project.load()

      assert.equals("gdbnf", cfg.cpp.bazel_config)
      assert.equals(1234, cfg.cpp.remote.port)

      -- Mutating the returned config must not leak into the module's
      -- defaults table (vim.tbl_deep_extend("force", {}, defaults) must
      -- produce an independent deep copy).
      cfg.cpp.remote.port = 9999
      assert.equals(1234, project.defaults.cpp.remote.port)

      cleanup()
    end)

    it("deep-merges a project's .nvim-dap.lua over the defaults", function()
      local dir, cleanup = enter_temp_cwd()
      write_file(dir .. "/.nvim-dap.lua", [[
        return {
          cpp = {
            remote = {
              bazel_config = "remote-arm64",
              hosts = {
                board_a = { host = "user@board-a.local" },
              },
            },
          },
        }
      ]])

      local cfg = project.load()

      -- Overridden values win.
      assert.equals("remote-arm64", cfg.cpp.remote.bazel_config)
      assert.equals("user@board-a.local", cfg.cpp.remote.hosts.board_a.host)

      -- Everything the project file didn't touch still falls back to
      -- the defaults (this is the point of vim.tbl_deep_extend merging
      -- rather than a shallow override).
      assert.equals("/tmp/nvim-dap-deploy", cfg.cpp.remote.workdir)
      assert.equals("gdb", cfg.cpp.remote.gdb_bin)
      assert.equals(1234, cfg.cpp.remote.port)
      assert.equals("gdbnf", cfg.cpp.bazel_config)

      cleanup()
    end)

    it("falls back to defaults and does not raise when .nvim-dap.lua is malformed", function()
      local dir, cleanup = enter_temp_cwd()
      write_file(dir .. "/.nvim-dap.lua", "this is not valid lua (")

      local notified = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level) table.insert(notified, { msg = msg, level = level }) end

      local ok, cfg = pcall(project.load)

      vim.notify = orig_notify
      cleanup()

      assert.is_true(ok, "project.load() must not raise on a malformed .nvim-dap.lua")
      assert.equals("gdbnf", cfg.cpp.bazel_config)
      assert.is_true(#notified > 0)
      assert.equals(vim.log.levels.ERROR, notified[1].level)
    end)
  end)
end)
