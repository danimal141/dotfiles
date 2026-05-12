return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdate", "TSInstall", "TSInstallInfo", "TSInstallSync", "TSUpdateSync" },
    opts = {
      -- nvim 0.12 + nvim-treesitter master branch の markdown / markdown_inline
      -- parser に互換性 bug ("attempt to call method 'range' (a nil value)")
      -- があり、highlight だけ disable しても aerial/indent などが parser を
      -- 起動して同じ crash を引く。長期的には nvim-treesitter main branch
      -- への移行が必要だが、暫定として ensure_installed から markdown を外し
      -- parser そのものを置かないことで全経路を塞ぐ。markdown highlight は
      -- vim builtin syntax にフォールバックする (実用上の劣化は限定的)。
      ensure_installed = {
        "bash", "c", "cpp", "css", "dockerfile", "go", "gomod", "gosum",
        "graphql", "hcl", "html", "javascript", "json", "jsonc", "kotlin",
        "lua", "luadoc", "python", "ruby",
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
