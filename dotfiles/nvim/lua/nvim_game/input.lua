-- Shared key-token capture for the quiz and its correction exercises.
--
-- This deliberately captures the physical sequence instead of invoking the
-- configured mapping.  A drill can therefore safely practice mappings that
-- normally stage a hunk, start a debugger, or change editor state.

local M = {}

M.LEADER = "<leader>"

local function bind(buf, key, action, callback)
	vim.keymap.set("n", key, function()
		callback(action)
	end, { buffer = buf, nowait = true, silent = true })
end

-- Install every token the game can ask the user to type.  The callback gets
-- printable characters verbatim and the special sentinels below.
function M.setup(buf, callback)
	local alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local digits = "1234567890"
	local puncts = {
		"!",
		'"',
		"#",
		"$",
		"%",
		"&",
		"(",
		")",
		"*",
		"+",
		",",
		"-",
		".",
		"/",
		":",
		";",
		"<",
		"=",
		">",
		"?",
		"@",
		"[",
		"\\",
		"]",
		"^",
		"_",
		"`",
		"{",
		"|",
		"}",
		"~",
		"'",
	}

	for i = 1, #alpha do
		local char = alpha:sub(i, i)
		bind(buf, char, char, callback)
	end
	for i = 1, #digits do
		local char = digits:sub(i, i)
		bind(buf, char, char, callback)
	end
	for _, char in ipairs(puncts) do
		bind(buf, char, char, callback)
	end

	-- Space is this configuration's leader, and answers use the readable
	-- <leader> spelling rather than an invisible literal space.
	bind(buf, "<Space>", M.LEADER, callback)

	for byte = string.byte("a"), string.byte("z") do
		local char = string.char(byte)
		bind(buf, "<C-" .. char .. ">", "<C-" .. char .. ">", callback)
	end
	for _, key in ipairs({ "<Tab>", "<S-Tab>" }) do
		bind(buf, key, key, callback)
	end

	-- Capture both cases so newly discovered defaults do not require changes to
	-- the game just because they use an Alt-modified capital.
	for i = 1, #alpha do
		local char = alpha:sub(i, i)
		bind(buf, "<M-" .. char .. ">", "<M-" .. char .. ">", callback)
	end

	-- These are game controls, not answer tokens.  Escape remains an answer
	-- token because it is itself a configured Neovim binding.
	bind(buf, "<CR>", "__submit__", callback)
	bind(buf, "<BS>", "__bs__", callback)
	bind(buf, "<Esc>", "__escape__", callback)
	bind(buf, "<C-c>", "__quit__", callback)
end

function M.backspace(input)
	if input:sub(-1) == ">" then
		local start = input:find("<[^<>]*>$")
		return start and input:sub(1, start - 1) or input:sub(1, -2)
	end
	return input:sub(1, -2)
end

function M.append(input, action)
	if action == "__escape__" then
		return input .. "<Esc>"
	end
	return input .. action
end

function M.is_prefix(input, expected)
	return expected:sub(1, #input) == input
end

-- Split the notation used by db.lua into the actions delivered by setup().
-- It is also used by tests to simulate a physical correction attempt.
function M.tokens(key)
	local tokens, pos = {}, 1
	while pos <= #key do
		if key:sub(pos, pos) == "<" then
			local finish = key:find(">", pos, true)
			assert(finish, "unterminated key token: " .. key)
			tokens[#tokens + 1] = key:sub(pos, finish)
			pos = finish + 1
		else
			tokens[#tokens + 1] = key:sub(pos, pos)
			pos = pos + 1
		end
	end
  return tokens
end

function M.can_capture(key)
  for _, token in ipairs(M.tokens(key)) do
    if #token == 1 then
      -- All printable ASCII tokens are mapped individually in setup().
      if not token:match('[%w%p ]') then return false end
    elseif token ~= M.LEADER
      and token ~= '<Esc>'
      and token ~= '<Tab>'
      and token ~= '<S-Tab>'
      and not token:match('^<C%-%a>$')
      and not token:match('^<M%-%a>$') then
      return false
    end
  end
  return true
end

return M
