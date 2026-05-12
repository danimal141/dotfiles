return {
  {
    "craftzdog/solarized-osaka.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      transparent = false,
      styles = { sidebars = "normal" },
    },
    config = function(_, opts)
      require("solarized-osaka").setup(opts)
      vim.cmd.colorscheme("solarized-osaka")
    end,
  },
  {
    "stevearc/aerial.nvim",
    cmd = { "AerialToggle", "AerialOpen", "AerialClose", "AerialNext", "AerialPrev" },
    keys = {
      { "tt", "<cmd>AerialToggle<CR>", desc = "Aerial toggle" },
    },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },
  {
    "simeji/winresizer",
    cmd = "WinResizerStartResize",
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
}
