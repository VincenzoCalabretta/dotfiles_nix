-- Tests for lua/bazel_picker.lua: the standalone build/run/test/debug picker
-- wired in via plugins/telescope.lua (see dap_modules/README.md's
-- architecture diagram -- it's a sibling of dap_modules, not part of it, but
-- still part of "the custom dap plugin setup").
--
-- Not covered here (needs a real `bazel`/`docker` and a workspace):
-- get_bazel_targets/get_bazel_configs/execute_recent_targets/
-- pick_bazel_target_and_action and friends -- these shell out via io.popen
-- or jobstart. What's covered is the recent-targets bookkeeping (dedup,
-- front-insert, cap at 3) and the auto-rebuild autocmd toggle, which is
-- deterministic in-memory state.

local bp = require("bazel_picker")

describe("bazel_picker", function()
  describe("get_target_key()", function()
    it("joins target/config/action with a pipe", function()
      assert.equals("//foo:bar|opt|run", bp.get_target_key("//foo:bar", "opt", "run"))
    end)

    it("defaults a nil config to \"default\"", function()
      assert.equals("//foo:bar|default|build", bp.get_target_key("//foo:bar", nil, "build"))
    end)
  end)

  describe("add_to_recent()", function()
    local saved_recent

    before_each(function()
      saved_recent = bp.recent_targets
      bp.recent_targets = {}
    end)

    after_each(function()
      bp.recent_targets = saved_recent
    end)

    it("inserts new entries at the front", function()
      bp.add_to_recent("//a", "default", "build")
      bp.add_to_recent("//b", "default", "build")
      assert.equals("//b", bp.recent_targets[1].target)
      assert.equals("//a", bp.recent_targets[2].target)
    end)

    it("de-duplicates the same target+config+action instead of stacking it", function()
      bp.add_to_recent("//a", "opt", "run")
      bp.add_to_recent("//b", "default", "build")
      bp.add_to_recent("//a", "opt", "run")
      assert.equals(2, #bp.recent_targets)
      assert.equals("//a", bp.recent_targets[1].target)
      assert.equals("//b", bp.recent_targets[2].target)
    end)

    it("keeps only the 3 most recent entries", function()
      bp.add_to_recent("//a", "default", "build")
      bp.add_to_recent("//b", "default", "build")
      bp.add_to_recent("//c", "default", "build")
      bp.add_to_recent("//d", "default", "build")

      assert.equals(3, #bp.recent_targets)
      assert.equals("//d", bp.recent_targets[1].target)
      assert.equals("//c", bp.recent_targets[2].target)
      assert.equals("//b", bp.recent_targets[3].target)
      for _, entry in ipairs(bp.recent_targets) do
        assert.are_not.equal("//a", entry.target)
      end
    end)
  end)

  describe("clear_recent_targets()", function()
    it("empties recent_targets and target_buffers", function()
      bp.recent_targets = { { target = "//a" } }
      bp.target_buffers = { ["x"] = { buffer_ids = {} } }

      bp.clear_recent_targets()

      assert.equals(0, #bp.recent_targets)
      assert.equals(0, vim.tbl_count(bp.target_buffers))
    end)
  end)

  describe("auto-rebuild toggling", function()
    after_each(function()
      -- Guard against a failed assertion leaving the BufWritePost autocmd
      -- (and the real `docker exec bazel ...` it would trigger) registered
      -- for the rest of the test process.
      if bp.auto_rebuild_enabled then bp.disable_auto_rebuild() end
    end)

    it("toggles the flag and registers/clears the BufWritePost autocmd", function()
      assert.is_false(bp.auto_rebuild_enabled)

      bp.toggle_auto_rebuild()
      assert.is_true(bp.auto_rebuild_enabled)
      assert.is_number(bp.watch_autocmd_id)

      bp.toggle_auto_rebuild()
      assert.is_false(bp.auto_rebuild_enabled)
      assert.is_nil(bp.watch_autocmd_id)
    end)
  end)
end)
