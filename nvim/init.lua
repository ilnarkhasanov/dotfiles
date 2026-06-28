-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Options
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.clipboard = "unnamedplus"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.autoread = true
vim.opt.termguicolors = true

-- Space as leader (most ergonomic)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("lazy").setup({

  -- Fuzzy file + content search
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          -- Show hidden files, ignore .git
          file_ignore_patterns = { "^%.git/" },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        },
      })
      require("telescope").load_extension("fzf")
    end,
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files hidden=true<cr>",  desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>",               desc = "Live grep (search contents)" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>",                desc = "Recent files" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>",                 desc = "Open buffers" },
    },
  },

  -- File browser via telescope
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("file_browser")
    end,
    keys = {
      { "<leader>fe", "<cmd>Telescope file_browser<cr>", desc = "File browser" },
    },
  },

  -- Git: stage hunks, partial staging, blame, diff
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          -- Stage / unstage hunk under cursor
          map("n", "<leader>gs", gs.stage_hunk,        "Stage hunk")
          map("n", "<leader>gu", gs.undo_stage_hunk,   "Unstage hunk")
          map("n", "<leader>gS", gs.stage_buffer,      "Stage entire file")
          map("n", "<leader>gR", gs.reset_buffer,      "Reset entire file")
          map("n", "<leader>gp", gs.preview_hunk,      "Preview hunk diff")
          map("n", "<leader>gb", gs.blame_line,        "Blame current line")
          map("n", "<leader>gd", gs.diffthis,          "Diff this file")

          -- Visual: stage only the selected lines (partial hunk)
          map("v", "<leader>gs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Stage selected lines")

          -- Navigate between hunks
          map("n", "]h", gs.next_hunk, "Next hunk")
          map("n", "[h", gs.prev_hunk, "Prev hunk")
        end,
      })
    end,
  },

  -- LSP: go-to-definition, references, hover, autoimport completions
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- basedpyright: faster drop-in replacement for pyright
      vim.lsp.config("basedpyright", {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoImportCompletions = true,
              typeCheckingMode = "basic",
            },
          },
        },
      })
      vim.lsp.enable("basedpyright")

      -- ruff: Rust-based linter/formatter, near-instant
      vim.lsp.config("ruff", {
        capabilities = capabilities,
      })
      vim.lsp.enable("ruff")

      -- Attach keymaps only when LSP connects to a buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set("n", "gd",          vim.lsp.buf.definition,     opts)
          vim.keymap.set("n", "gD",          vim.lsp.buf.declaration,    opts)
          vim.keymap.set("n", "gi",          vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "gr",          vim.lsp.buf.references,     opts)
          vim.keymap.set("n", "K",           vim.lsp.buf.hover,          opts)
          vim.keymap.set("n", "<leader>rn",  vim.lsp.buf.rename,         opts)
          vim.keymap.set("n", "<leader>ca",  vim.lsp.buf.code_action,    opts)
          vim.keymap.set("n", "]d",          vim.diagnostic.goto_next,   opts)
          vim.keymap.set("n", "[d",          vim.diagnostic.goto_prev,   opts)
          vim.keymap.set("n", "<leader>di",  vim.diagnostic.open_float,  opts)
        end,
      })

      vim.diagnostic.config({
        virtual_text = { prefix = "●", spacing = 4 },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })
    end,
  },

  -- Autocomplete (nvim-cmp sources autoimport suggestions from pyright)
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      { "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"]     = cmp.mapping.select_next_item(),
          ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
        }),
        -- LSP source first so pyright autoimport suggestions appear at top
        sources = cmp.config.sources(
          { { name = "nvim_lsp" }, { name = "luasnip" } },
          { { name = "buffer" },   { name = "path" } }
        ),
      })
    end,
  },

  -- Treesitter: fast syntax highlighting + smarter indentation
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        ensure_installed = { "python", "lua", "vim", "vimdoc", "markdown", "bash" },
        auto_install = true,
      })
    end,
  },

  -- File tree
  {
    "nvim-tree/nvim-tree.lua",
    config = function()
      require("nvim-tree").setup({})
    end,
    keys = {
      { "<leader>t", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file tree" },
    },
  },

  -- Comments: gcc / gc<motion>
  { "numToStr/Comment.nvim", opts = {} },

  -- Markdown preview
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npx --yes yarn install",
    ft = { "markdown" },
  },

  -- Shows available keymaps after pressing leader
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 400, -- ms after pressing leader before popup appears
    },
  },

  -- Vim practice game
  { "ThePrimeagen/vim-be-good" },

}, {
  performance = {
    rtp = {
      -- Skip built-in plugins that slow startup
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
