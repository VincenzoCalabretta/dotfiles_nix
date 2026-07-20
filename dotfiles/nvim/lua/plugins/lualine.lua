local cached_result = ""
local refreshing = false

return {
	--  'nvim-lualine/lualine.nvim',
	--  dependencies = { 'nvim-tree/nvim-web-devicons' },
	--  config = function()
	--
	--    local function rust_component()
	--      if cached_result ~= "" then
	-- return cached_result
	--      end
	--
	--      if not refreshing then
	-- refreshing = true
	-- vim.system({ "/home/v/filastrocca/target/debug/filastrocca" }, { text = true }, function(obj)
	--   local output = obj.stdout and obj.stdout:gsub("%s+$", "") or ""
	--   cached_result = output
	--   refreshing = false
	--   vim.schedule(function()
	--     vim.cmd("redrawstatus")
	--   end)
	-- end)
	--      end
	--
	--      return "..."
	--    end
	--
	--    require('lualine').setup({
	--      options = {
	--        theme = 'gruvbox',
	--      },
	--      sections = {
	--        lualine_x = { rust_component },  -- add your custom component here
	--      },
	--    })
	--  end,
}



