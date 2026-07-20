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

          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
          map('K', vim.lsp.buf.hover, 'Hover Documentation')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('<leader>f', vim.lsp.buf.format, '[F]ormat current buffer')

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
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
            end, '[T]oggle Inlay [H]ints')
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
        -- Added clangd here
        ensure_installed = { 'lua-language-server','basedpyright', 'ruff', 'stylua', 'rust-analyzer', 'clangd' },
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
      vim.lsp.config('clangd', {
        cmd = { 'clangd' },
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
        root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' },
        capabilities = capabilities,
      })


      -- ── 6. Enable servers ─────────────────────────────────────────────
      vim.lsp.enable({ 'lua_ls', 'ruff', 'basedpyright', 'rust_analyzer', 'clangd' })

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
