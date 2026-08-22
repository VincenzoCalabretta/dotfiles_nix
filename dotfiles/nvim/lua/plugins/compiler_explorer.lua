return {
	{
		"krady21/compiler-explorer.nvim",
		cond = function()
			return vim.env.COMPILER_EXPLORER_URL ~= nil
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
				url = assert(vim.env.COMPILER_EXPLORER_URL),
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
