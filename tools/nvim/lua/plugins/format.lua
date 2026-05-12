return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        rust = { "rustfmt" },
        go = { "goimports" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        json = { "prettier" },
        markdown = { "prettier" },
        html = { "prettier" },
        yaml = { "prettier" },
        ruby = { "rubocop" },
        python = { "black", "isort" },
      },
      formatters = {
        prettier = {
          prepend_args = { "--no-semi", "--single-quote", "--trailing-comma", "all" },
        },
      },
      format_on_save = {
        timeout_ms = 1500,
        lsp_format = "fallback",
      },
    },
  },
}
