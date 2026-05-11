return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach = function(_, bufnr)
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, noremap = true, silent = true })
        end
        map("n", "gd", vim.lsp.buf.definition, "LSP: definition")
        map("n", "gD", vim.lsp.buf.declaration, "LSP: declaration")
        map("n", "gi", vim.lsp.buf.implementation, "LSP: implementation")
        map("n", "gr", vim.lsp.buf.references, "LSP: references")
        map("n", "K", vim.lsp.buf.hover, "LSP: hover")
        map("n", "<C-k>", vim.lsp.buf.signature_help, "LSP: signature help")
        map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: rename")
        map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
        map("n", "[d", vim.diagnostic.goto_prev, "Diagnostic: prev")
        map("n", "]d", vim.diagnostic.goto_next, "Diagnostic: next")
        map("n", "<leader>e", vim.diagnostic.open_float, "Diagnostic: float")
      end

      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })

      vim.lsp.config("*", {
        capabilities = capabilities,
        on_attach = on_attach,
      })

      -- 各 server に cmd を明示することで PATH 上に binary が無い時の
      -- enable をスキップする (filetype マッチ時の spawn 失敗エラー回避)。
      local servers = {
        gopls = {
          cmd = { "gopls" },
          settings = {
            gopls = {
              usePlaceholders = true,
              analyses = { unusedparams = true, shadow = true },
              staticcheck = true,
            },
          },
        },
        rust_analyzer = { cmd = { "rust-analyzer" } },
        ts_ls = {
          cmd = { "typescript-language-server", "--stdio" },
          single_file_support = false,
          root_dir = function(bufnr, on_dir)
            if vim.fs.root(bufnr, { "deno.json", "deno.jsonc" }) then
              return
            end
            local root = vim.fs.root(bufnr, { "package.json", "tsconfig.json", "jsconfig.json", ".git" })
            if root then
              on_dir(root)
            end
          end,
        },
        solargraph = { cmd = { "solargraph", "stdio" } },
        jedi_language_server = { cmd = { "jedi-language-server" } },
        terraformls = { cmd = { "terraform-ls", "serve" } },
        clangd = { cmd = { "clangd" } },
        bashls = { cmd = { "bash-language-server", "start" } },
        yamlls = {
          cmd = { "yaml-language-server", "--stdio" },
          settings = {
            yaml = {
              format = { enable = true, singleQuote = true },
              validate = false,
            },
          },
        },
        jsonls = { cmd = { "vscode-json-language-server", "--stdio" } },
        cssls = { cmd = { "vscode-css-language-server", "--stdio" } },
        html = { cmd = { "vscode-html-language-server", "--stdio" } },
        dockerls = { cmd = { "docker-langserver", "--stdio" } },
        graphql = {
          cmd = { "graphql-lsp", "server", "-m", "stream" },
          filetypes = { "graphql", "typescriptreact", "javascriptreact", "typescript", "javascript" },
        },
        denols = {
          cmd = { "deno", "lsp" },
          root_markers = { "deno.json", "deno.jsonc" },
          single_file_support = false,
        },
        lua_ls = {
          cmd = { "lua-language-server" },
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
              diagnostics = { globals = { "vim" } },
            },
          },
        },
      }

      local enabled = {}
      for name, cfg in pairs(servers) do
        if vim.fn.executable(cfg.cmd[1]) == 1 then
          vim.lsp.config(name, cfg)
          table.insert(enabled, name)
        end
      end
      vim.lsp.enable(enabled)
    end,
  },
}
