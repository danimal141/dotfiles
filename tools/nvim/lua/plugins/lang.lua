return {
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_auto_close = 1
      -- mac の OS デフォルトブラウザを起動する。空文字列だと自動 open
      -- されないので注意 (旧 .vimrc は空文字列で運用していたが、
      -- nvim では明示的に "open" コマンドを渡す)。
      vim.g.mkdp_browser = "open"
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
