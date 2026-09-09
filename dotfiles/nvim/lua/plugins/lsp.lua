return {
  {
    -- We can make mason the root plugin here since you don't need nvim-lspconfig
    'williamboman/mason.nvim',
    dependencies = {
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim',       opts = {} },
      -- lazydev replaces the deprecated neodev.nvim
      {
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
          library = {
            { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
          },
        },
      },
      -- If you use nvim-cmp, ensure this is installed somewhere in your config
      'hrsh7th/cmp-nvim-lsp', 
    },
    config = function()
      -- Initialize Mason first
      require('mason').setup()

      -- ── 1. LSP Attach: keymaps & document-highlight ───────────────────
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- gd/gr are intentionally NOT bound here (buffer-local maps would
          -- shadow the global ones). They're set once, globally, in
          -- lua/lsp_fallback.lua, which tries LSP first and falls through
          -- to a gtags query when the client has no results (or no client
          -- is attached at all) -- see that file for why.
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>ct', require('telescope.builtin').lsp_type_definitions, '[C]ode [T]ype definition')
          map('<leader>cd', require('telescope.builtin').lsp_document_symbols, '[C]ode [D]ocument symbols')
          map('<leader>cw', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[C]ode [W]orkspace symbols')
          map('<leader>cr', vim.lsp.buf.rename, '[C]ode [R]ename')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
          map('K', vim.lsp.buf.hover, 'Hover Documentation')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('<leader>cf', vim.lsp.buf.format, '[C]ode [F]ormat current buffer')

          local client = vim.lsp.get_client_by_id(event.data.client_id)

          if client and client.supports_method('textDocument/formatting') then
            vim.keymap.set({ 'n', 'x' }, 'gq', function()
              vim.lsp.buf.format({ async = false, timeout_ms = 5000 })
            end, { buffer = event.buf, desc = 'LSP: Format buffer' })
          end

          if client and client.supports_method('textDocument/definition') then
            vim.bo[event.buf].tagfunc = 'v:lua.vim.lsp.tagfunc'
          end

          if client and client.server_capabilities.documentHighlightProvider then
            local group = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = group,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = group,
              callback = vim.lsp.buf.clear_references,
            })
          end

          if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
            map('<leader>ch', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
            end, '[C]ode toggle inlay [H]ints')
          end

          if client and client.supports_method('textDocument/codeLens') then
            map('<leader>cl', vim.lsp.codelens.run, '[C]ode [L]ens run')
            vim.lsp.codelens.refresh()
            vim.api.nvim_create_autocmd({ 'BufEnter', 'InsertLeave' }, {
              buffer = event.buf,
              callback = vim.lsp.codelens.refresh,
            })
          end
        end,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event.buf }
        end,
      })

      -- ── 2. Capabilities (cmp_nvim_lsp) ────────────────────────────────
      local capabilities = vim.tbl_deep_extend(
        'force',
        vim.lsp.protocol.make_client_capabilities(),
        require('cmp_nvim_lsp').default_capabilities()
      )

      -- ── 3. Mason: ensure tools are installed ──────────────────────────
      require('mason-tool-installer').setup {
        -- clangd intentionally NOT managed by mason: on Nix, the mason-built
        -- binary shadows the Nix-profile clangd on $PATH (mason prepends its
        -- bin dir) and doesn't know how to find the Nix toolchain's system
        -- headers, causing spurious errors on every file. Use the
        -- Nix-profile clangd via an absolute path instead (see below).
        ensure_installed = { 'lua-language-server','basedpyright', 'ruff', 'stylua', 'rust-analyzer' },
      }

      -- ── 4. Helper: resolve .venv python for the current project ───────
      local function find_venv_python()
        local cwd = vim.fn.getcwd()
        local venv_python = cwd .. '/.venv/bin/python'
        if vim.fn.executable(venv_python) == 1 then
          return venv_python
        end
        return vim.fn.exepath('python3') or 'python3'
      end

      -- ── 5. Server configs (vim.lsp.config — 0.11+ native API) ─────────

      -- Lua LS
      vim.lsp.config('lua_ls', {
        cmd = { 'lua-language-server' },
        filetypes = { 'lua' },
        root_markers = { '.luarc.json', '.luarc.jsonc', '.luacheckrc', '.stylua.toml', 'stylua.toml', '.git' },
        capabilities = capabilities,
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
            codeLens   = { enable = true },
            hint       = { enable = true, semicolon = 'Disable' },
          },
        },
      })

      -- Ruff
      vim.lsp.config('ruff', {
        cmd = { 'ruff', 'server' },
        filetypes = { 'python' },
        root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
        capabilities = capabilities,
        init_options = {
          settings = {
            interpreter = { find_venv_python() },
          },
        },
      })

      -- Basedpyright
      vim.lsp.config('basedpyright', {
        cmd = { 'basedpyright-langserver', '--stdio' },
        filetypes = { 'python' },
        root_markers = { 'pyrightconfig.json', 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoSearchPaths    = true,
              useLibraryCodeForTypes = true,
              diagnosticMode     = 'openFilesOnly',
              extraPaths         = { 'model/root' },
              ignore = {
                'bazel*/**',
                '**/.venv/**',
                '.ruff_cache/**',
                'pypan_*/**',
              },
              exclude = {
                'bazel*/**',
                '**/.venv/**',
                '.ruff_cache/**',
                'pypan_*/**',
              },
            },
          },
        },
      })

      -- Rust Analyzer
      vim.lsp.config('rust_analyzer', {
        cmd = { 'rust-analyzer' },
        filetypes = { 'rust' },
        root_markers = { 'Cargo.toml', 'rust-project.json' },
        capabilities = capabilities,
        settings = {
          ['rust-analyzer'] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = { enable = true },
            },
            checkOnSave = true,
            check = {
              allFeatures = true,
              command = 'clippy',
            },
            procMacro = { enable = true },
            inlayHints = {
              bindingModeHints = { enable = false },
              closureReturnTypeHints = { enable = 'with_block' },
              lifetimeElisionHints = { enable = 'skip_trivial' },
              parameterHints = { enable = true },
            },
          },
        },
      })

      -- Clangd
      -- Absolute path: avoids mason's bin dir (prepended to $PATH) shadowing
      -- this with a generic build that can't see the Nix toolchain's headers.
      vim.lsp.config('clangd', {
        cmd = { vim.fn.expand('~/.nix-profile/bin/clangd') },
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
        root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' },
        capabilities = capabilities,
      })

      -- Nixd
      -- Not mason-managed: installed via Nix (modules/nvim.nix) like clangd.
      vim.lsp.config('nixd', {
        cmd = { 'nixd' },
        filetypes = { 'nix' },
        root_markers = { 'flake.nix', '.git' },
        capabilities = capabilities,
      })

      -- MLIR
      -- Not mason-managed: installed via Nix (modules/nvim.nix), ships as
      -- part of llvmPackages.mlir. Only knows MLIR's built-in dialects.
      vim.lsp.config('mlir_lsp', {
        cmd = { 'mlir-lsp-server' },
        filetypes = { 'mlir' },
        root_markers = { '.git' },
        capabilities = capabilities,
      })

      -- TableGen (.td)
      -- Same package as mlir_lsp above. Full cross-file resolution needs a
      -- tablegen_compile_commands.json (CMake-generated); falls back to
      -- single-file parsing without one.
      vim.lsp.config('tblgen_lsp', {
        cmd = { 'tblgen-lsp-server' },
        filetypes = { 'tablegen' },
        root_markers = { 'tablegen_compile_commands.json', '.git' },
        capabilities = capabilities,
      })

      -- Starpls (Bazel/Starlark)
      -- Not mason-managed: installed via Nix (modules/nvim.nix). Neovim's
      -- built-in filetype detection maps BUILD, BUILD.bazel, WORKSPACE, and
      -- *.bzl all to filetype 'bzl'.
      vim.lsp.config('starpls', {
        cmd = { 'starpls', 'server' },
        filetypes = { 'bzl' },
        root_markers = { 'WORKSPACE', 'WORKSPACE.bazel', 'MODULE.bazel', '.git' },
        capabilities = capabilities,
      })

      -- ── 6. Enable servers ─────────────────────────────────────────────
      vim.lsp.enable({ 'lua_ls', 'ruff', 'basedpyright', 'rust_analyzer', 'clangd', 'nixd', 'mlir_lsp', 'tblgen_lsp', 'starpls' })

      -- ── 7. Diagnostics display ────────────────────────────────────────
      vim.diagnostic.config({
        virtual_text = {
          prefix = '●',
          spacing = 4,
          source = 'if_many',
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = 'rounded',
          source = 'always',
        },
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
