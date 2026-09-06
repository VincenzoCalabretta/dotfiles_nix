-- A real-tab correction drill for nvim_game.
--
-- The tab uses ordinary Neovim windows and buffers.  The answer is installed
-- as a buffer-local mapping on the fixture buffer, so pressing it exercises
-- Neovim's real mapping machinery while the resulting action stays isolated
-- from the user's files, Git index, debugger, and external tools.

local examples = require("nvim_game.examples")

local M = {}
local NS = vim.api.nvim_create_namespace("nvim_game_practice")
local P = nil

M.observe_ms = 3000

local function setup_hl()
	local groups = {
		NvimGameExampleTitle = { fg = "#FFD700", bold = true },
		NvimGameExampleKey = { fg = "#FFAA33", bold = true },
		NvimGameExampleText = { fg = "#B8C0D9" },
		NvimGameExampleCode = { fg = "#9CDCFE" },
		NvimGameExampleCursor = { fg = "#44FF88", bold = true },
		NvimGameExampleOk = { fg = "#44FF88", bold = true },
		NvimGameExampleMuted = { fg = "#777788", italic = true },
	}
	for name, value in pairs(groups) do
		vim.api.nvim_set_hl(0, name, value)
	end
end

local function set_lines(buf, lines, modifiable)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = modifiable == true
end

local function scratch_buffer(lines, filetype, modifiable)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = filetype or "text"
	set_lines(buf, lines, modifiable)
	return buf
end

local function info_lines()
	local example = P.example
	local lines = {
		"⌨  CORRECTION DRILL",
		"",
		"You answered: " .. (P.wrong_answer ~= "" and P.wrong_answer or "(empty)"),
		"Correct key: " .. example.key,
		"",
		"Goal: " .. example.description,
		"Context: " .. example.title,
		"Mode: " .. example.mode,
		"",
		"The source window is an editable fixture in this tab.",
		"Press the displayed key there to run its isolated drill.",
		"",
		"<C-c> abandons this game session.",
	}
	if P.completed then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "✓ Key executed in the correction tab"
		lines[#lines + 1] = P.outcome
		lines[#lines + 1] = string.format("Observe the result — returning in %.1f seconds…", P.observe_ms / 1000)
	end
	return lines
end

local function render_info()
	if not (P and vim.api.nvim_buf_is_valid(P.info_buf)) then
		return
	end
	set_lines(P.info_buf, info_lines(), false)
	vim.api.nvim_buf_clear_namespace(P.info_buf, NS, 0, -1)
	vim.api.nvim_buf_add_highlight(P.info_buf, NS, "NvimGameExampleTitle", 0, 0, -1)
	vim.api.nvim_buf_add_highlight(P.info_buf, NS, "NvimGameExampleKey", 3, 0, -1)
	if P.completed then
		local first_result_line = #info_lines() - 3
		vim.api.nvim_buf_add_highlight(P.info_buf, NS, "NvimGameExampleOk", first_result_line, 0, -1)
		vim.api.nvim_buf_add_highlight(P.info_buf, NS, "NvimGameExampleOk", first_result_line + 1, 0, -1)
		vim.api.nvim_buf_add_highlight(P.info_buf, NS, "NvimGameExampleMuted", first_result_line + 2, 0, -1)
	end
end

local function abort()
	if not P then
		return
	end
	local on_abort = P.on_abort
	M.close()
	if on_abort then
		on_abort()
	end
end

local function add_abort_mapping(buf)
	vim.keymap.set("n", "<C-c>", abort, { buffer = buf, nowait = true, silent = true, desc = "KeyGame: abandon drill" })
end

local function open_result(title, lines, filetype)
	if not (P.source_win and vim.api.nvim_win_is_valid(P.source_win)) then
		return
	end
	vim.api.nvim_set_current_win(P.source_win)
	vim.cmd("vsplit")
	P.result_win = vim.api.nvim_get_current_win()
	P.result_buf = scratch_buffer(vim.list_extend({ title, string.rep("─", 48), "" }, lines), filetype, true)
	vim.api.nvim_win_set_buf(P.result_win, P.result_buf)
	vim.wo[P.result_win].number = false
	vim.wo[P.result_win].relativenumber = false
	vim.wo[P.result_win].signcolumn = "no"
	add_abort_mapping(P.result_buf)
end

local function apply_effect()
	local example = P.example
	local action = example.action
	local source_line = math.min(example.cursor, #example.lines)

	if action == "move" then
		local destination = source_line == #example.lines and 1 or source_line + 1
		vim.api.nvim_set_current_win(P.source_win)
		vim.api.nvim_win_set_cursor(P.source_win, { destination, 0 })
		P.outcome = string.format("Cursor moved to line %d in the real fixture buffer.", destination)
	elseif action == "select" then
		vim.api.nvim_set_current_win(P.source_win)
		vim.api.nvim_win_set_cursor(P.source_win, { source_line, 0 })
		vim.cmd("normal! v$")
		P.outcome = "The selected text is now in Visual mode in the fixture buffer."
	elseif action == "edit" then
		local line = vim.api.nvim_buf_get_lines(P.source_buf, source_line - 1, source_line, false)[1]
		vim.api.nvim_buf_set_lines(P.source_buf, source_line - 1, source_line, false, { line .. "  -- drill applied" })
		P.outcome = "The fixture source was edited by the exercised mapping."
	elseif action == "window" then
		open_result("Window reached by " .. example.key, { "The correction mapping opened this real split.", example.description }, "text")
		P.outcome = "A real split was opened and focused."
	elseif action == "diagnostic" then
		open_result("Diagnostic details", { "Error at the cursor:", example.description, "", "Fix the highlighted expression before continuing." }, "text")
		P.outcome = "A diagnostic-details buffer was opened beside the fixture."
	elseif action == "diff" then
		open_result("Diff for current hunk", {
			"@@ -12,5 +12,5 @@ function build()",
			"-return run(target)",
			"+return run(target, { verbose = true })",
		}, "diff")
		P.outcome = "A real diff buffer was opened for the fixture hunk."
	elseif action == "search" then
		open_result("Search results", { "src/main.lua:7: " .. example.description, "tests/main_spec.lua:18: matching fixture result" }, "text")
		P.outcome = "A project-search results buffer was opened."
	elseif action == "outline" then
		open_result("Document symbols", { "▾ module nvim_game", "  ▾ function start", "  ▸ function render", "  ▸ function finish" }, "text")
		P.outcome = "A document-symbol buffer was opened."
	elseif action == "file" then
		open_result("Pinned file", { "src/parser.lua", "", "local function parse(input)", "  return input", "end" }, "lua")
		P.outcome = "The selected pinned-file fixture was opened in a split."
	elseif action == "definition" or action == "assembly" then
		open_result("Definition reached by " .. example.key, {
			"local function calculate_total(items)",
			"  return vim.iter(items):sum()",
			"end",
		}, action == "assembly" and "asm" or "lua")
		P.outcome = "A definition buffer was opened and focused."
	elseif action == "debug" then
		open_result("Debug session", { "Thread 1 paused", "▶ write_result(result)", "", "Stepping state changed by the drill." }, "text")
		P.outcome = "The debug-session buffer now shows the exercised transition."
	elseif action == "target" or action == "task" then
		open_result("Task output", { "$ " .. example.description, "", "fixture action completed successfully" }, "text")
		P.outcome = "A task-output buffer was opened for the selected action."
	else
		open_result("Result of " .. example.key, { example.description, "", "This action ran inside the isolated correction tab." }, "text")
		P.outcome = "A real result buffer was opened for the exercised action."
	end
end

local function complete()
	if not P or P.completed then
		return
	end
	P.completed = true
	apply_effect()
	render_info()
	local finished = P
	vim.defer_fn(function()
		if P ~= finished then
			return
		end
		local on_success = P.on_success
		M.close()
		if on_success then
			on_success()
		end
	end, P.observe_ms)
end

function M.close()
	if not P then
		return
	end
	local drill = P
	P = nil
	if drill.tab and vim.api.nvim_tabpage_is_valid(drill.tab) then
		pcall(vim.api.nvim_set_current_tabpage, drill.tab)
		pcall(vim.cmd, "tabclose!")
	end
	if drill.parent_tab and vim.api.nvim_tabpage_is_valid(drill.parent_tab) then
		pcall(vim.api.nvim_set_current_tabpage, drill.parent_tab)
	end
	if drill.parent_win and vim.api.nvim_win_is_valid(drill.parent_win) then
		pcall(vim.api.nvim_set_current_win, drill.parent_win)
	end
end

function M.open(question, options)
	M.close()
	setup_hl()
	options = options or {}
	local parent_tab = vim.api.nvim_get_current_tabpage()
	local parent_win = options.parent_win or vim.api.nvim_get_current_win()

	vim.cmd("tabnew")
	local source_win = vim.api.nvim_get_current_win()
	local source_buf = vim.api.nvim_get_current_buf()
	local example = examples.resolve(question)
	P = {
		tab = vim.api.nvim_get_current_tabpage(),
		parent_tab = parent_tab,
		parent_win = parent_win,
		source_win = source_win,
		source_buf = source_buf,
		example = example,
		wrong_answer = options.wrong_answer or "",
		completed = false,
		outcome = nil,
		observe_ms = options.observe_ms or M.observe_ms,
		on_success = options.on_success,
		on_abort = options.on_abort,
	}

	vim.bo[source_buf].bufhidden = "wipe"
	vim.bo[source_buf].buftype = "nofile"
	vim.bo[source_buf].filetype = example.action == "diff" and "diff" or "lua"
	set_lines(source_buf, example.lines, true)
	vim.wo[source_win].number = true
	vim.wo[source_win].relativenumber = true
	vim.api.nvim_win_set_cursor(source_win, { math.min(example.cursor, #example.lines), 0 })
	vim.api.nvim_buf_clear_namespace(source_buf, NS, 0, -1)
	vim.api.nvim_buf_add_highlight(source_buf, NS, "NvimGameExampleCursor", example.cursor - 1, 0, -1)

	vim.cmd("vsplit")
	P.info_win = vim.api.nvim_get_current_win()
	P.info_buf = scratch_buffer({}, "nvimgameinfo", false)
	vim.api.nvim_win_set_buf(P.info_win, P.info_buf)
	vim.api.nvim_win_set_width(P.info_win, math.min(42, math.floor(vim.o.columns / 2)))
	vim.wo[P.info_win].number = false
	vim.wo[P.info_win].relativenumber = false
	vim.wo[P.info_win].signcolumn = "no"
	vim.wo[P.info_win].wrap = true
	add_abort_mapping(P.info_buf)

	vim.api.nvim_set_current_win(source_win)
	vim.keymap.set("n", example.key, complete, {
		buffer = source_buf,
		nowait = true,
		silent = true,
		desc = "KeyGame: run correction drill",
	})
	add_abort_mapping(source_buf)
	render_info()
	return source_buf, source_win
end

function M.active()
	return P ~= nil
end

function M._state_for_test()
	return P
end

return M
