return {
  {
    "toppair/peek.nvim",
    ft = "markdown",
    -- deno は mise global で入っている前提 (denols でも使用)。
    -- 社内 VPN の SSL inspection 下では deno.land への HTTPS 取得が
    -- UnknownIssuer になるため、init.lua と同じ /etc/nix/ca-bundle.pem を
    -- DENO_CERT に渡して build を通す。
    build = "DENO_CERT=/etc/nix/ca-bundle.pem deno task --quiet build:fast",
    config = function()
      require("peek").setup({
        auto_load = true,
        close_on_bdelete = true,
        syntax = true,
        theme = "dark",
        app = "webview",
      })
      vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
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
