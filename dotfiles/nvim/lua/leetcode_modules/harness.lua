-- Phase 2 of the leetcode.nvim <-> dap_modules debug integration (see
-- dap_modules/examples/leetcode_debug/README.md for Phase 1).
--
-- :LeetDebugPrep reads the currently open question's meta_data (param
-- names/types, method name) and every test case currently in its testcase
-- popup buffer, then generates one small C++ harness per test case plus a
-- shared cc_library + one cc_binary per case in BUILD.bazel next to the
-- solution file, so dap_modules' bazel_picker (<leader>bd) can build and
-- gdbserver-debug any individual case directly, instead of only
-- leetcode.nvim's own :Leet run/:Leet submit console. Only scalar/array/
-- string param and return types are supported; ListNode/TreeNode-shaped
-- problems are refused with a clear error rather than generating
-- something that won't compile.
local M = {}

local function passthrough(s)
  return s
end

local function brackets_to_braces(s)
  return (s:gsub("%[", "{"):gsub("%]", "}"))
end

-- Keyed by LeetCode's own meta_data type strings (see
-- lua/leetcode/api/types.lua's metadata_param/metadata_return in the
-- leetcode.nvim source). LeetCode's bracket-notation test-case text is
-- already valid C++ once brackets become braces, so no runtime parsing is
-- needed -- values are baked into the generated source as literals.
local TYPE_MAP = {
  integer = { cpp = "int", transform = passthrough },
  ["integer[]"] = { cpp = "std::vector<int>", transform = brackets_to_braces },
  ["integer[][]"] = { cpp = "std::vector<std::vector<int>>", transform = brackets_to_braces },
  long = { cpp = "long long", transform = passthrough },
  ["long[]"] = { cpp = "std::vector<long long>", transform = brackets_to_braces },
  double = { cpp = "double", transform = passthrough },
  number = { cpp = "double", transform = passthrough },
  boolean = { cpp = "bool", transform = passthrough },
  string = { cpp = "std::string", transform = passthrough },
  ["string[]"] = { cpp = "std::vector<std::string>", transform = brackets_to_braces },
  character = { cpp = "char", transform = passthrough },
}

-- Overloaded on the Solution method's actual return type, so the harness
-- just calls print_result(result) and C++ overload resolution picks the
-- matching formatter. A return type outside this set fails at compile
-- time with "no matching function" -- acceptable for the unsupported
-- (ListNode/TreeNode/...) case, though M.prep() already refuses those
-- earlier with a clearer Lua-side error.
local PRINT_HELPERS = [[
inline void print_result(int v) { std::printf("%d\n", v); }
inline void print_result(long long v) { std::printf("%lld\n", v); }
inline void print_result(double v) { std::printf("%g\n", v); }
inline void print_result(bool v) { std::printf("%s\n", v ? "true" : "false"); }
inline void print_result(char v) { std::printf("\"%c\"\n", v); }
inline void print_result(const std::string& v) { std::printf("\"%s\"\n", v.c_str()); }
inline void print_result(const std::vector<int>& v) {
  std::printf("[");
  for (size_t i = 0; i < v.size(); ++i) std::printf("%s%d", i ? "," : "", v[i]);
  std::printf("]\n");
}
inline void print_result(const std::vector<long long>& v) {
  std::printf("[");
  for (size_t i = 0; i < v.size(); ++i) std::printf("%s%lld", i ? "," : "", v[i]);
  std::printf("]\n");
}
inline void print_result(const std::vector<double>& v) {
  std::printf("[");
  for (size_t i = 0; i < v.size(); ++i) std::printf("%s%g", i ? "," : "", v[i]);
  std::printf("]\n");
}
inline void print_result(const std::vector<std::string>& v) {
  std::printf("[");
  for (size_t i = 0; i < v.size(); ++i) std::printf("%s\"%s\"", i ? "," : "", v[i].c_str());
  std::printf("]\n");
}
inline void print_result(const std::vector<std::vector<int>>& v) {
  std::printf("[");
  for (size_t i = 0; i < v.size(); ++i) {
    std::printf("%s[", i ? "," : "");
    for (size_t j = 0; j < v[i].size(); ++j) std::printf("%s%d", j ? "," : "", v[i][j]);
    std::printf("]");
  }
  std::printf("]\n");
}]]

local CPP_KEYWORDS = {
  ["new"] = true,
  ["class"] = true,
  ["delete"] = true,
  ["template"] = true,
  ["namespace"] = true,
  ["operator"] = true,
  ["public"] = true,
  ["private"] = true,
  ["protected"] = true,
  ["friend"] = true,
  ["union"] = true,
  ["typename"] = true,
  ["this"] = true,
  ["true"] = true,
  ["false"] = true,
}

local function sanitize_ident(name)
  name = (name or ""):gsub("[^%w_]", "_")
  if name == "" then
    name = "arg"
  elseif name:match("^%d") then
    name = "_" .. name
  end
  if CPP_KEYWORDS[name] then
    name = name .. "_"
  end
  return name
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

local BUILD_HEADER = 'load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")\n'

local function library_block(lib_name, sol_basename)
  return ([[

# Generated by leetcode_modules/harness.lua (:LeetDebugPrep). The solution
# needs its own cc_library: cc_binary has neither `hdrs` nor `textual_hdrs`
# (verified against a real Bazel 9.1.0 build -- see
# dap_modules/examples/leetcode_debug/README.md), only cc_library does.
cc_library(
    name = "%s",
    hdrs = ["%s"],
)
]]):format(lib_name, sol_basename)
end

local function binary_block(bin_name, harness_basename, lib_name)
  return ([[

cc_binary(
    name = "%s",
    srcs = ["%s"],
    deps = [":%s"],
    copts = ["-fno-omit-frame-pointer"],
    visibility = ["//visibility:public"],
)
]]):format(bin_name, harness_basename, lib_name)
end

---Read every test case (each one value per line, in meta_data.params
---order, cases separated by a blank line) out of the currently open
---question's testcase popup buffer. Blocks shorter than nparams lines are
---dropped (e.g. a stray trailing blank line at the buffer's end).
---@param question lc.ui.Question
---@param nparams integer
---@return string[][]|nil
local function read_testcases(question, nparams)
  local testcase = question.console and question.console.testcase
  local bufnr = testcase and testcase.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local cases, current = {}, {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line == "" then
      if #current > 0 then
        table.insert(cases, current)
        current = {}
      end
    else
      table.insert(current, line)
    end
  end
  if #current > 0 then
    table.insert(cases, current)
  end

  local result = {}
  for _, case in ipairs(cases) do
    if #case >= nparams then
      table.insert(result, case)
    end
  end
  return #result > 0 and result or nil
end

function M.prep()
  local ok, utils = pcall(require, "leetcode.utils")
  if not ok then
    vim.notify("leetcode_debug: leetcode.nvim isn't loaded", vim.log.levels.ERROR)
    return
  end

  local question = utils.curr_question()
  if not question then
    vim.notify("leetcode_debug: no LeetCode question is open in this tab", vim.log.levels.ERROR)
    return
  end

  local meta = question.q.meta_data
  if not meta or not meta.params or not meta["return"] then
    vim.notify("leetcode_debug: this question has no usable meta_data.params/return", vim.log.levels.ERROR)
    return
  end

  for _, param in ipairs(meta.params) do
    if not TYPE_MAP[param.type] then
      vim.notify(
        ('leetcode_debug: unsupported param type "%s" (%s) -- not implemented yet'):format(param.type, param.name),
        vim.log.levels.ERROR
      )
      return
    end
  end

  local ret_type = meta["return"].type
  if not TYPE_MAP[ret_type] then
    vim.notify(
      ('leetcode_debug: unsupported return type "%s" -- not implemented yet'):format(tostring(ret_type)),
      vim.log.levels.ERROR
    )
    return
  end

  local cases = read_testcases(question, #meta.params)
  if not cases then
    vim.notify("leetcode_debug: couldn't read any full test case from the testcase popup", vim.log.levels.ERROR)
    return
  end

  local sol_path = question.file:absolute()
  local sol_basename = vim.fs.basename(sol_path)
  local dir = vim.fs.dirname(sol_path)
  local pkg = vim.fs.basename(dir)

  local frontend_id = question.q.frontend_id
  local title_slug = question.q.title_slug
  local safe_slug = (title_slug:gsub("-", "_"))
  local lib_name = safe_slug .. "_solution"

  local build_path = dir .. "/BUILD.bazel"
  local existing = read_file(build_path)
  local appended = existing or ""

  if not existing then
    appended = BUILD_HEADER
  end
  if not appended:find('name = "' .. lib_name .. '"', 1, true) then
    appended = appended .. library_block(lib_name, sol_basename)
  end

  local bin_names, new_count = {}, 0

  for case_idx, case in ipairs(cases) do
    local decl_lines, arg_names = {}, {}
    for i, param in ipairs(meta.params) do
      local mapped = TYPE_MAP[param.type]
      local ident = sanitize_ident(param.name)
      table.insert(decl_lines, ("  %s %s = %s;"):format(mapped.cpp, ident, mapped.transform(case[i])))
      table.insert(arg_names, ident)
    end

    local harness_basename = ("%s.%s_case%d_harness.cc"):format(frontend_id, title_slug, case_idx)
    local harness_path = dir .. "/" .. harness_basename
    local call = ("Solution().%s(%s)"):format(meta.name, table.concat(arg_names, ", "))

    local harness_content = ([[
// Generated by leetcode_modules/harness.lua (:LeetDebugPrep) -- overwritten
// each time you re-run it against a (possibly edited) test case.
#include <cstdio>
#include <string>
#include <vector>
#include "%s"

namespace leetcode_debug_harness {
%s
}  // namespace leetcode_debug_harness

int main() {
%s
  auto result = %s;
  leetcode_debug_harness::print_result(result);
}
]]):format(sol_basename, PRINT_HELPERS, table.concat(decl_lines, "\n"), call)

    write_file(harness_path, harness_content)

    local bin_name = ("%s_debug_case%d"):format(safe_slug, case_idx)
    if not appended:find('name = "' .. bin_name .. '"', 1, true) then
      appended = appended .. binary_block(bin_name, harness_basename, lib_name)
      new_count = new_count + 1
    end
    table.insert(bin_names, bin_name)
  end

  write_file(build_path, appended)

  vim.notify(
    ("leetcode_debug: %d case(s), %d new target(s) -- //%s:{%s} ready in <leader>bd"):format(
      #cases,
      new_count,
      pkg,
      table.concat(bin_names, ",")
    )
  )
end

return M
