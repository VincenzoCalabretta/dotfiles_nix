local M = {}

local function parse(s)
  s = vim.trim(s):gsub("_", ""):gsub("'", "")
  if s:match("^0[xX]") then
    return tonumber(s:sub(3), 16)
  elseif s:match("^0[bB]") then
    return tonumber(s:sub(3), 2)
  elseif s:match("^0[oO]") then
    return tonumber(s:sub(3), 8)
  end
  return tonumber(s, 10) or tonumber(s, 16)
end

local function to_bin(n)
  if n == 0 then return "0b0000_0000" end
  local bits = {}
  local tmp = math.abs(n)
  while tmp > 0 do
    table.insert(bits, 1, tmp % 2)
    tmp = math.floor(tmp / 2)
  end
  while #bits % 4 ~= 0 do table.insert(bits, 1, 0) end
  local groups = {}
  for i = 1, #bits, 4 do
    table.insert(groups, table.concat(bits, "", i, i + 3))
  end
  local prefix = n < 0 and "-0b" or "0b"
  return prefix .. table.concat(groups, "_")
end

function M.show(input)
  input = input or vim.fn.expand("<cword>")
  local n = parse(input)
  if not n then
    vim.notify("numconv: not a number: '" .. input .. "'", vim.log.levels.WARN)
    return
  end
  n = math.floor(n)

  local hex = n >= 0
    and string.format("0x%X", n)
    or string.format("-0x%X", -n)

  local lines = {
    string.format("  dec  %d", n),
    string.format("  hex  %s", hex),
    string.format("  bin  %s", to_bin(n)),
  }

  local width = 4
  for _, l in ipairs(lines) do width = math.max(width, #l + 2) end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype   = "numconv"

  vim.api.nvim_open_win(buf, true, {
    relative  = "cursor",
    row       = 1,
    col       = 0,
    width     = width,
    height    = #lines,
    style     = "minimal",
    border    = "rounded",
    title     = "  " .. vim.trim(input) .. "  ",
    title_pos = "center",
  })

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, nowait = true, silent = true })
  end
end

function M.setup()
  vim.keymap.set("n", "<leader>cn", function()
    M.show(vim.fn.expand("<cword>"))
  end, { desc = "NumConv: word under cursor" })

  vim.keymap.set("v", "<leader>cn", function()
    vim.cmd("normal! y")
    M.show(vim.fn.getreg('"'))
  end, { desc = "NumConv: visual selection" })
end

return M
