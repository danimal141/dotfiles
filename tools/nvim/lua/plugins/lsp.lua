return {
  {
    "neovim/nvim-lspconfig",
    -- nvim 0.11+ の vim.lsp.enable() で autostart hook を取り付ける必要が
    -- あるため、最初の buffer 読み込みより前に config を走らせる。
    -- BufReadPre lazy load では hook 登録と filetype 検出のタイミングが
    -- 競合して初回 attach に間に合わないため eager load にする (lspconfig
    -- 自体は軽量なので起動時間への影響は無視できる)。
    lazy = false,
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

      -- Gemfile.lock を眺めて `gem "ruby-lsp"` が依存に入っているか判定。
      -- Gemfile.lock の spec 行は "    ruby-lsp (1.2.3)" のような形式。
      local function project_uses_ruby_lsp(root)
        local lockfile = root .. "/Gemfile.lock"
        local f = io.open(lockfile, "r")
        if not f then return false end
        local content = f:read("*a")
        f:close()
        return content:find("\n%s+ruby%-lsp%s") ~= nil
      end

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
        -- Ruby は ruby-lsp を優先しつつ、composed bundle が組めない project
        -- (= Gemfile はあるが Gemfile.lock に ruby-lsp 含まれていない) では
        -- solargraph に fallback する。両方を同時に attach させると補完 /
        -- format / diagnostics が衝突するので root_dir で排他選択する。
        --
        --   Gemfile 無し                                    → ruby-lsp standalone
        --   Gemfile + Gemfile.lock に ruby-lsp 含まれる     → ruby-lsp
        --   Gemfile あり + ruby-lsp 入りでない (or lock 無) → solargraph
        --
        -- ruby-lsp は mise global ruby の gem として配備する想定
        -- (gem install ruby-lsp)。global gem の bin が PATH に来るので
        -- cmd は { "ruby-lsp" } 直叩きで OK。
        ruby_lsp = {
          cmd = { "ruby-lsp" },
          root_dir = function(bufnr, on_dir)
            local gemfile = vim.fs.root(bufnr, { "Gemfile" })
            if not gemfile then
              -- Gemfile 無し → ファイルの親 dir を root として standalone 起動
              local file = vim.api.nvim_buf_get_name(bufnr)
              on_dir(vim.fs.dirname(file))
              return
            end
            if project_uses_ruby_lsp(gemfile) then
              on_dir(gemfile)
            end
            -- Gemfile あるが ruby-lsp 入りでない → 起動しない (solargraph 担当)
          end,
        },
        solargraph = {
          cmd = { "solargraph", "stdio" },
          root_dir = function(bufnr, on_dir)
            local gemfile = vim.fs.root(bufnr, { "Gemfile" })
            -- Gemfile 無し or ruby-lsp 入り project は ruby-lsp が担当する
            if not gemfile then return end
            if project_uses_ruby_lsp(gemfile) then return end
            on_dir(gemfile)
          end,
        },
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
  {
    "ray-x/lsp_signature.nvim",
    event = "LspAttach",
    opts = {
      bind = true,
      handler_opts = { border = "rounded" },
      hint_enable = false,
      floating_window = true,
    },
  },
}
