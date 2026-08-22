local function compiler_explorer_url()
	if vim.env.COMPILER_EXPLORER_URL then
		return vim.env.COMPILER_EXPLORER_URL
	end

	local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
	local path = config_home .. "/compiler-explorer-nvim/url"
	if vim.fn.filereadable(path) == 1 then
		return vim.trim(vim.fn.readfile(path)[1] or "")
	end
end

return {
	{
		"krady21/compiler-explorer.nvim",
		cond = function()
			return compiler_explorer_url() ~= nil
		end,
		cmd = {
			"CECompile",
			"CECompileLive",
			"CEFormat",
			"CEAddLibrary",
			"CELoadExample",
			"CEOpenWebsite",
			"CEDeleteCache",
		},
		keys = {
			{
				"<leader>ce",
				"<cmd>CECompile<cr>",
				mode = "n",
				desc = "Compiler Explorer: compile buffer",
			},
			{
				"<leader>ce",
				":<C-u>'<,'>CECompile<cr>",
				mode = "x",
				desc = "Compiler Explorer: compile selection",
			},
		},
		config = function()
			require("compiler-explorer").setup({
				url = assert(compiler_explorer_url()),
				infer_lang = true,
				line_match = {
					highlight = true,
					jump = false,
				},
				open_qflist = true,
				split = "vsplit",
			})
		end,
	},
}
