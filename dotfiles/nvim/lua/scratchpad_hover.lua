local M = {}

-- Show value category of a C++ expression
function M.show_value_category(expr)
  if not expr or expr == "" then
    vim.notify("No expression provided", vim.log.levels.WARN)
    return
  end

  local scratch = "/tmp/scratch.cpp"
  local exe = "/tmp/scratch.out"

  -- Write scratch.cpp
  local f, err = io.open(scratch, "w")
  if not f then
    vim.notify("Failed to open scratch file: " .. err, vim.log.levels.ERROR)
    return
  end

  f:write([[
#include <iostream>
#include <string>
#include <type_traits>
#include <utility>

#define IS_LVALUE(...) std::is_lvalue_reference<decltype((__VA_ARGS__))>::value
#define IS_XVALUE(...) std::is_rvalue_reference<decltype((__VA_ARGS__))>::value
#define IS_PRVALUE(...) !std::is_reference<decltype((__VA_ARGS__))>::value

#define PRINT_VALUE_CATEGORY(expr) \
    std::cout << #expr << " => " \
              << "L:" << IS_LVALUE(expr) << " " \
              << "X:" << IS_XVALUE(expr) << " " \
              << "P:" << IS_PRVALUE(expr) << "\n";

int main() {
    PRINT_VALUE_CATEGORY(]] .. expr .. [[);
}
]])
  f:close()

  -- Compile
  local compile_cmd = "g++ -std=c++20 " .. scratch .. " -o " .. exe
  local compile_output = vim.fn.system(compile_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Compilation failed:\n" .. compile_output, vim.log.levels.ERROR)
    return
  end

  -- Run executable
  local result = vim.fn.system(exe)
  if not result then
    vim.notify("Execution failed", vim.log.levels.ERROR)
    return
  end

  -- Create buffer safely
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    vim.notify("Failed to create buffer", vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(result, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Open floating window
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end

  local opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
  }

  vim.api.nvim_open_win(buf, false, opts)
end

-- Setup function: creates visual mode mapping
function M.setup()
  vim.keymap.set("v", "<leader>p", function()
    vim.cmd("normal! y")  -- yank selection
    local expr = vim.fn.getreg('"')
    M.show_value_category(expr)
  end, { desc = "Show C++ value category of expression" })
end

return M
