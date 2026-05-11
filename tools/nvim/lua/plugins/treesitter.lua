return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdate", "TSInstall", "TSInstallInfo", "TSUpdateSync" },
    opts = {
      ensure_installed = {
        "bash", "c", "cpp", "css", "dockerfile", "go", "gomod", "gosum",
        "graphql", "hcl", "html", "javascript", "json", "jsonc", "kotlin",
        "lua", "luadoc", "markdown", "markdown_inline", "python", "ruby",
        "rust", "scss", "terraform", "toml", "tsx", "typescript", "vim",
        "vimdoc", "yaml",
      },
      auto_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
