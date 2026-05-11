return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local lspconfig = require("lspconfig")
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

      local servers = {
        gopls = {
          settings = {
            gopls = {
              usePlaceholders = true,
              analyses = { unusedparams = true, shadow = true },
              staticcheck = true,
            },
          },
        },
        rust_analyzer = {},
        ts_ls = {},
        solargraph = {},
        jedi_language_server = {},
        terraformls = {},
        clangd = {},
        bashls = {},
        yamlls = {
          settings = {
            yaml = {
              format = { enable = true, singleQuote = true },
              validate = false,
            },
          },
        },
        jsonls = {},
        cssls = {},
        html = {},
        dockerls = {},
        graphql = {
          filetypes = { "graphql", "typescriptreact", "javascriptreact", "typescript", "javascript" },
        },
        denols = {
          root_dir = lspconfig.util.root_pattern("deno.json", "deno.jsonc"),
        },
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
              diagnostics = { globals = { "vim" } },
            },
          },
        },
      }

      -- ts_ls と denols は同一 buffer に attach すると衝突するため、deno project
      -- (deno.json があるディレクトリ) では ts_ls を起動しない
      servers.ts_ls.root_dir = function(fname)
        local util = lspconfig.util
        if util.root_pattern("deno.json", "deno.jsonc")(fname) then
          return nil
        end
        return util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git")(fname)
      end
      servers.ts_ls.single_file_support = false

      for server, cfg in pairs(servers) do
        cfg.capabilities = capabilities
        cfg.on_attach = on_attach
        lspconfig[server].setup(cfg)
      end
    end,
  },
}
