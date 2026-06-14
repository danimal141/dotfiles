return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    cmd = "Telescope",
    keys = {
      { "<C-p>", function() require("telescope.builtin").find_files() end, desc = "Telescope find files" },
      { "<C-f>", function() require("telescope.builtin").live_grep() end, desc = "Telescope live grep" },
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Telescope find files" },
      { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Telescope live grep" },
      { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Telescope buffers" },
      { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Telescope help tags" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      defaults = {
        file_ignore_patterns = { "node_modules", ".git" },
        -- telescope 0.1.8 の previewer は nvim-treesitter main branch で消えた
        -- API を参照するため、preview 内の treesitter highlight を無効化して
        -- vim builtin syntax にフォールバックさせる。
        preview = { treesitter = false },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
      },
    },
  },
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFindFile", "NvimTreeOpen", "NvimTreeClose" },
    keys = {
      { "<leader>n", "<cmd>NvimTreeToggle<CR>", desc = "NvimTree toggle" },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view = { width = 30 },
      renderer = {
        add_trailing = false,
        -- symlink 先 path も表示してリンク先がわかるようにする (default true)
        symlink_destination = true,
      },
      -- 隠しファイル / gitignore 対象も表示する。dotfiles repo では
      -- ~/.config 配下を symlink 化していて、symlink が gitignore 対象に
      -- なっていると nvim-tree のデフォルト (git_ignored = true) で非表示に
      -- なってしまうため両方 off にする。
      filters = { dotfiles = false, git_ignored = false },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {},
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },
}
