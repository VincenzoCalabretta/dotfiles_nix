return {
  {
    'stevearc/overseer.nvim',
    opts = {}, 
    config = function(_, opts)
      local overseer = require("overseer")
      
      overseer.setup(opts)

      overseer.register_template({
        name = "Bazel Build (Current Package)",
        builder = function(params)
          local current_dir = vim.fn.expand("%:p:h")
          
          local build_files = vim.fs.find({"BUILD", "BUILD.bazel"}, {
            upward = true,
            path = current_dir,
            type = "file",
          })
          
          if #build_files == 0 then
            return {
              cmd = { "echo" },
              args = { "Error: No BUILD or BUILD.bazel file found in parent directories." },
              components = { "default" }
            }
          end
          
          local build_dir = vim.fn.fnamemodify(build_files[1], ":h")
          
          local ws_files = vim.fs.find({"WORKSPACE", "WORKSPACE.bazel", "MODULE.bazel"}, {
            upward = true,
            path = build_dir,
            type = "file",
          })
          
          local target = "//..." 
          local ws_dir = nil -- Initialize ws_dir so we can pass it to the task
          
          if #ws_files > 0 then
            ws_dir = vim.fn.fnamemodify(ws_files[1], ":h")
            local rel_pkg = build_dir:sub(#ws_dir + 2) 
            
            if rel_pkg == "" then
              target = "//:all" 
            else
              target = "//" .. rel_pkg .. ":all"
            end
          end

          return {
            cmd = { "bazel" },
            args = { "build", target },
            cwd = ws_dir,
            components = { 
              "default",
              { 
                "on_output_quickfix", 
                open_on_exit = "failure",
                -- Teach Neovim how to read Bazel and Rustc output:
                -- 1. Strip 'ERROR: ' and 'WARNING: ' from Bazel file paths
                -- 2. Catch Rust compiler arrows '--> src/main.rs:line:col'
                errorformat = [[ERROR: %f:%l:%c: %m,WARNING: %f:%l:%c: %m,%Eerror%.%#: %m,%Z --> %f:%l:%c,%f:%l:%c: %m]]
              },
              "on_result_diagnostics",
            },
          }
        end,
        condition = {
          callback = function(search)
            return vim.fn.filereadable(search.dir .. "/WORKSPACE") == 1 
                or vim.fn.filereadable(search.dir .. "/WORKSPACE.bazel") == 1
                or vim.fn.filereadable(search.dir .. "/MODULE.bazel") == 1
          end,
        },
      })

      -- vim.api.nvim_create_autocmd("BufWritePost", {
      --   pattern = { "*.rs", "*.cc", "*.cpp", "*.h", "*.rs", "*.java", "*.py" },
      --   group = vim.api.nvim_create_augroup("OverseerBazelAutoBuild", { clear = true }),
      --   callback = function()
      --     local is_bazel = #vim.fs.find({"WORKSPACE", "WORKSPACE.bazel", "MODULE.bazel"}, { upward = true, type = "file" }) > 0
      --
      --     if is_bazel then
      --       overseer.run_task({ name = "Bazel Build (Current Package)" })
      --     end
      --   end,
      -- })

      vim.keymap.set("n", "<leader>o", "<cmd>OverseerToggle<CR>", { desc = "Toggle Overseer UI" })
      vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<CR>", { desc = "Run Overseer Task" })
    end,
  },
}
