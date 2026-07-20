local M = {}

-- Function to run expression in scratch.cpp and show output in floating window
function M.show_value_category(expr)
  local scratch = "/tmp/scratch.cpp"
  local exe = "/tmp/scratch.out"

  -- Write the scratch file
  local f = io.open(scratch, "w")
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

  -- Compile and run
  vim.fn.system("g++ -std=c++20 " .. scratch .. " -o " .. exe)
  local result = vim.fn.system(exe)

  -- Show result in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
  local opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = math.max(20, #result),
    height = 1,
    style = "minimal",
    border = "rounded",
  }
  vim.api.nvim_open_win(buf, false, opts)
end

-- Optional: setup visual mode mapping
function M.setup()
  vim.keymap.set("v", "<leader>p", function()
    vim.cmd('normal! y')
    local expr = vim.fn.getreg('"')
    M.show_value_category(expr)
  end, { desc = "Show value category of expression" })
end

return M
