return {
  {
    "toppair/peek.nvim",
    ft = "markdown",
    -- deno は mise global で入っている前提 (denols でも使用)。
    -- 社内 VPN の SSL inspection 下では deno.land への HTTPS 取得が
    -- UnknownIssuer になるため、init.lua と同じ /etc/nix/ca-bundle.pem を
    -- DENO_CERT に渡して build を通す。
    -- 加えて upstream の app/src/markdownit.ts は全リンクの href を
    -- 'javascript:return' に書き換えてしまい (webview 内ナビ抑止のため)、
    -- browser モードで開いた preview でリンクが踏めず、クリックで
    -- "Illegal return statement" まで吐く。bundle 前に sed で該当行を
    -- 除去し、リンクの href を保持させる。
    -- sed の -i は BSD (空引数必須) / GNU (引数なしも可) で挙動が違うため
    -- -i.bak で両対応し、直後に .bak を削除する。
    build = [[sed -i.bak "s|token.attrSet('href', 'javascript:return');||" app/src/markdownit.ts && rm app/src/markdownit.ts.bak && DENO_CERT=/etc/nix/ca-bundle.pem deno task --quiet build:fast]],
    config = function()
      require("peek").setup({
        auto_load = true,
        close_on_bdelete = true,
        syntax = true,
        theme = "dark",
        -- webview は内蔵 Deno webview でリンククリックが効かないため、
        -- OS デフォルトブラウザを起動する "browser" を使う。
        app = "browser",
      })
      vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
    end,
  },
  {
    -- in-buffer の markdown プレビュー。peek.nvim (browser 経由) と
    -- 性質が異なるため検証用に併用。markdown / markdown_inline parser は
    -- treesitter.lua 側で install 済み。
    "OXY2DEV/markview.nvim",
    ft = { "markdown" },
    config = function()
      require("markview").setup({})
    end,
  },
  {
    "tpope/vim-rails",
    ft = "ruby",
  },
  {
    "mechatroner/rainbow_csv",
    ft = { "csv", "tsv" },
  },
  {
    "slim-template/vim-slim",
    ft = "slim",
  },
  {
    "aklt/plantuml-syntax",
    ft = "plantuml",
  },
  {
    "tpope/vim-endwise",
    event = "InsertEnter",
  },
}
