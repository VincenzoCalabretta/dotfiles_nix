-- Foreground, side-effect-free correction exercise for nvim_game.

local capture = require("nvim_game.input")
local examples = require("nvim_game.examples")

local M = {}
local NS = vim.api.nvim_create_namespace("nvim_game_practice")
local P = nil

-- Leave the successful simulated result visible long enough to connect the
-- physical key sequence with its effect before returning to the quiz.
M.observe_ms = 3000

local function setup_hl()
	local groups = {
		NvimGameExampleTitle = { fg = "#FFD700", bold = true },
		NvimGameExampleKey = { fg = "#FFAA33", bold = true },
		NvimGameExampleText = { fg = "#B8C0D9" },
		NvimGameExampleCode = { fg = "#9CDCFE" },
		NvimGameExampleCursor = { fg = "#44FF88", bold = true },
		NvimGameExampleInput = { fg = "#00CCFF", bold = true },
		NvimGameExampleError = { fg = "#FF5555", bold = true },
		NvimGameExampleOk = { fg = "#44FF88", bold = true },
		NvimGameExampleMuted = { fg = "#777788", italic = true },
	}
	for name, value in pairs(groups) do
		vim.api.nvim_set_hl(0, name, value)
	end
end

local function pad_center(text, width)
	local left = math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
	return string.rep(" ", left) .. text
end

local function divider(width)
	return string.rep("─", width)
end

local function set_buf(lines)
	vim.bo[P.buf].modifiable = true
	vim.api.nvim_buf_set_lines(P.buf, 0, -1, false, lines)
	vim.bo[P.buf].modifiable = false
end

local function add_hl(line, start_col, end_col, group)
	pcall(vim.api.nvim_buf_add_highlight, P.buf, NS, group, line, start_col, end_col)
end

local function truncate(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	return text:sub(1, math.max(1, width - 1)) .. "…"
end

local function render()
	if not (P and vim.api.nvim_buf_is_valid(P.buf)) then
		return
	end

	local lines, hls = {}, {}
	local function add(text, group)
		lines[#lines + 1] = text
		if group then
			hls[#hls + 1] = { #lines - 1, 0, -1, group }
		end
	end

	add("", nil)
	add(pad_center("⌨  CORRECTION EXERCISE", P.width), "NvimGameExampleTitle")
	add(pad_center("Practice the displayed binding to continue", P.width), "NvimGameExampleMuted")
	add(divider(P.width), "NvimGameExampleMuted")
	add("", nil)

	local wrong = P.wrong_answer ~= "" and P.wrong_answer or "(empty)"
	add(pad_center("You answered: " .. truncate(wrong, P.width - 18), P.width), "NvimGameExampleError")
	local correct_line = pad_center("Correct key: " .. P.example.key, P.width)
	add(correct_line, "NvimGameExampleKey")
	local correct_line_index = #lines - 1
	local key_start = correct_line:find(P.example.key, 1, true)
	if key_start then
		hls[#hls + 1] = { correct_line_index, key_start - 1, key_start - 1 + #P.example.key, "NvimGameExampleKey" }
	end
	add("", nil)
	add(pad_center(P.example.title .. "  ·  " .. P.example.mode, P.width), "NvimGameExampleTitle")
	add(pad_center(truncate(P.example.prompt, P.width - 4), P.width), "NvimGameExampleText")
	add(pad_center("Goal: " .. truncate(P.example.description, P.width - 10), P.width), "NvimGameExampleText")
	add("", nil)

	local content_start = #lines
	for index, text in ipairs(P.example.lines) do
		local marker = index == P.example.cursor and "▶ " or "  "
		add(
			marker .. truncate(text, P.width - 2),
			index == P.example.cursor and "NvimGameExampleCursor" or "NvimGameExampleCode"
		)
	end
	local cursor_line = content_start + P.example.cursor - 1
	if cursor_line >= content_start then
		hls[#hls + 1] = { cursor_line, 0, 1, "NvimGameExampleCursor" }
	end

	add("", nil)
	add(divider(P.width), "NvimGameExampleMuted")
	if P.completed then
		add(pad_center("✓  Correct key accepted — simulated result applied", P.width), "NvimGameExampleOk")
		add(pad_center(truncate(P.outcome, P.width - 4), P.width), "NvimGameExampleOk")
		add(
			pad_center(string.format("Observe the result — returning in %.1f seconds…", P.observe_ms / 1000), P.width),
			"NvimGameExampleMuted"
		)
	else
		local input = P.input == "" and "▋" or (P.input .. "▋")
		local input_line = pad_center("Type it: " .. input, P.width)
		add(input_line, P.message_group or "NvimGameExampleInput")
		add(
			pad_center(P.message or "This is a safe simulation; the real mapping will not run.", P.width),
			P.message and P.message_group or "NvimGameExampleMuted"
		)
		add(pad_center("<BS> retry input    <C-c> abandon game", P.width), "NvimGameExampleMuted")
	end

	set_buf(lines)
	vim.api.nvim_buf_clear_namespace(P.buf, NS, 0, -1)
	for _, highlight in ipairs(hls) do
		add_hl(highlight[1], highlight[2], highlight[3], highlight[4])
	end
end

function M.close()
	if not P then
		return
	end
	local practice = P
	P = nil
	if practice.win and vim.api.nvim_win_is_valid(practice.win) then
		vim.api.nvim_win_close(practice.win, true)
	end
	if practice.buf and vim.api.nvim_buf_is_valid(practice.buf) then
		pcall(vim.api.nvim_buf_delete, practice.buf, { force = true })
	end
	if practice.parent_win and vim.api.nvim_win_is_valid(practice.parent_win) then
		pcall(vim.api.nvim_set_current_win, practice.parent_win)
	end
end

local function complete()
	if not P or P.completed then
		return
	end
	P.completed = true
	P.message = nil
	P.outcome = "Simulated result: " .. P.example.description
	P.example.prompt = "The shown mapping was captured; its safe simulated result is now visible."
	P.example.lines[P.example.cursor] = P.example.lines[P.example.cursor] .. "  ← simulated effect"
	render()
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

function M.handle_key(action)
	if not P or P.completed then
		return
	end

	if action == "__quit__" then
		local on_abort = P.on_abort
		M.close()
		if on_abort then
			on_abort()
		end
		return
	end
	if action == "__bs__" then
		P.input = capture.backspace(P.input)
		P.message, P.message_group = nil, nil
		render()
		return
	end
	if action == "__submit__" then
		P.message = "Type the displayed key sequence; <Enter> is not required."
		P.message_group = "NvimGameExampleMuted"
		render()
		return
	end

	local candidate = capture.append(P.input, action)
	if candidate == P.example.key then
		P.input = candidate
		complete()
	elseif capture.is_prefix(candidate, P.example.key) then
		P.input = candidate
		P.message, P.message_group = nil, nil
		render()
	else
		P.input = ""
		P.message = "That sequence does not match. Try the shown key again."
		P.message_group = "NvimGameExampleError"
		render()
	end
end

function M.open(question, options)
	M.close()
	setup_hl()
	options = options or {}
	local width = math.max(40, math.min(94, vim.o.columns - 4))
	local height = math.max(14, math.min(28, vim.o.lines - 4))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "nvimgameexample"
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		row = math.max(0, math.floor((vim.o.lines - height) / 2)),
		style = "minimal",
		border = "rounded",
		title = "  Practice the correct key  ",
		title_pos = "center",
		zindex = 310,
	})
	vim.wo[win].cursorline = false
	vim.wo[win].wrap = false
	vim.wo[win].signcolumn = "no"

	P = {
		buf = buf,
		win = win,
		parent_win = options.parent_win,
		width = width,
		example = examples.resolve(question),
		wrong_answer = options.wrong_answer or "",
		input = "",
		message = nil,
		message_group = nil,
		completed = false,
		outcome = nil,
		observe_ms = options.observe_ms or M.observe_ms,
		on_success = options.on_success,
		on_abort = options.on_abort,
	}
	capture.setup(buf, M.handle_key)
	render()
	return buf, win
end

function M.active()
	return P ~= nil
end

-- Internal inspection hooks used by the headless regression test.
function M._state_for_test()
	return P
end

return M
