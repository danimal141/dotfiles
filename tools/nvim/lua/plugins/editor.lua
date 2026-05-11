return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    cmd = "Telescope",
    keys = {
      { "<C-p>", function() require("telescope.builtin").find_files() end, desc = "Telescope find files" },
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Telescope find files" },
      { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Telescope live grep" },
      { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Telescope buffers" },
      { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Telescope help tags" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      defaults = {
        file_ignore_patterns = { "node_modules", ".git" },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
      },
    },
  },
}
