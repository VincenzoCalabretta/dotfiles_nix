-- Tests for dap_modules/ui.lua: the lazy.nvim plugin specs it returns are
-- plain data (no side effects at require time), so we can assert on their
-- shape directly -- catches accidental typos/structure breaks that would
-- otherwise only surface once lazy.nvim tries to load the plugin for real.

local ui = require("dap_modules.ui")

describe("dap_modules.ui", function()
  it("returns exactly two lazy.nvim plugin specs", function()
    assert.equals(2, #ui)
  end)

  describe("nvim-dap-view spec", function()
    local spec = ui[1]

    it("targets igorlfs/nvim-dap-view and is lazy", function()
      assert.equals("igorlfs/nvim-dap-view", spec[1])
      assert.is_true(spec.lazy)
    end)

    it("shows the winbar with the documented section order", function()
      assert.is_true(spec.opts.winbar.show)
      assert.same(
        { "scopes", "breakpoints", "watches", "exceptions", "threads", "repl" },
        spec.opts.winbar.sections
      )
    end)

    it("splits the debug view on the right at half width", function()
      assert.equals(0.5, spec.opts.windows.size)
      assert.equals("right", spec.opts.windows.position)
    end)
  end)

  describe("telescope-dap spec", function()
    local spec = ui[2]

    it("targets nvim-telescope/telescope-dap.nvim and depends on telescope.nvim", function()
      assert.equals("nvim-telescope/telescope-dap.nvim", spec[1])
      assert.same({ "nvim-telescope/telescope.nvim" }, spec.dependencies)
    end)

    it("does not own leader mappings", function()
      assert.is_nil(spec.keys)
    end)
  end)
end)
