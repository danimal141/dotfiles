return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- main branch は完全書き直し版で nvim 0.10+ の vim.treesitter API に
    -- 直接乗る。lazy-loading 非対応 (lazy = false 必須)、setup() は optional、
    -- highlight / indent / fold は user が autocmd で start を呼ぶ。
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- parser install dir のデフォルトでよいので setup() は呼ばない。

      -- filetype → treesitter parser 名のマッピング。同じ filetype で
      -- 複数 parser がある場合 (javascriptreact → javascript) はここで吸収。
      local ft_to_lang = {
        bash = "bash",
        sh = "bash",
        c = "c",
        cpp = "cpp",
        css = "css",
        dockerfile = "dockerfile",
        go = "go",
        gomod = "gomod",
        gosum = "gosum",
        graphql = "graphql",
        hcl = "hcl",
        html = "html",
        javascript = "javascript",
        javascriptreact = "javascript",
        json = "json",
        jsonc = "json",
        kotlin = "kotlin",
        lua = "lua",
        python = "python",
        ruby = "ruby",
        rust = "rust",
        scss = "scss",
        terraform = "terraform",
        toml = "toml",
        tsx = "tsx",
        typescript = "typescript",
        typescriptreact = "tsx",
        vim = "vim",
        help = "vimdoc",
        yaml = "yaml",
      }

      -- 未 install の parser を要求。`install` は async でジョブを返すので、
      -- bootstrap 時は wait() を付けて同期化 (新 parser が無いまま buffer
      -- 開いて highlight 失敗するのを防ぐ)。install 済みなら no-op に近い。
      local parsers = {}
      local seen = {}
      for _, lang in pairs(ft_to_lang) do
        if not seen[lang] then
          table.insert(parsers, lang)
          seen[lang] = true
        end
      end
      -- markview.nvim が要求する parser。markdown は vim builtin syntax を
      -- highlight に使う方針なので ft_to_lang には載せず (treesitter.start
      -- を markdown では呼ばない)、parser だけ install しておく。
      for _, lang in ipairs({ "markdown", "markdown_inline" }) do
        if not seen[lang] then
          table.insert(parsers, lang)
          seen[lang] = true
        end
      end
      require("nvim-treesitter").install(parsers):wait(300000)

      -- filetype 一致時に treesitter highlight を起動する。markdown は
      -- 意図的に pattern から外して vim builtin syntax を使う (master 由来の
      -- range() bug 回避は main branch で不要になる想定だが、念のため markdown
      -- だけ後で個別検証することにして当面 builtin に任せる)。
      vim.api.nvim_create_autocmd("FileType", {
        pattern = vim.tbl_keys(ft_to_lang),
        callback = function(args)
          local lang = ft_to_lang[vim.bo[args.buf].filetype]
          if lang then
            pcall(vim.treesitter.start, args.buf, lang)
          end
        end,
      })
    end,
  },
}
