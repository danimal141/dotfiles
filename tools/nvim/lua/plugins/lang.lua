return {
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_auto_close = 1
      -- 空文字列が docs 上の "use system default browser" 挙動
      -- (mac: open, linux: xdg-open, win: start)。
      vim.g.mkdp_browser = ""
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
