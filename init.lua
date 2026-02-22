-- ==========================================================================
-- BASIC SETTINGS
-- ==========================================================================
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = 'a'
opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.termguicolors = true
opt.cursorline = true
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
opt.scrolloff = 10
opt.updatetime = 250
opt.signcolumn = "yes"

-- ==========================================================================
-- KEYBINDINGS
-- ==========================================================================
vim.g.mapleader = " "
local keymap = vim.keymap

keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Save File' })
keymap.set('n', '<leader>q', ':q<CR>', { desc = 'Quit Neovim' })
keymap.set('n', '<c-s>', ':w<CR>')
keymap.set('i', '<c-s>', '<Esc>:w<CR>a')

-- Undo / Redo
keymap.set('n', '<C-z>', 'u', { desc = 'Undo' })
keymap.set('n', '<C-y>', '<C-r>', { desc = 'Redo' })

-- Standard Clipboard Operations
keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })
keymap.set('v', '<C-c>', '"+y', { desc = 'Copy' })
keymap.set('v', '<C-x>', '"+d', { desc = 'Cut' })
keymap.set('n', '<C-v>', '"+p', { desc = 'Paste' })

-- Diagnostic Navigation
keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev Diagnostic' })
keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next Diagnostic' })
keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Line Diagnostics' })

-- Git Keymaps
keymap.set('n', '<leader>gs', vim.cmd.Git, { desc = 'Git Status' })
keymap.set('n', '<leader>gp', ':Git push<CR>', { desc = 'Git Push' })

-- ==========================================================================
-- DIAGNOSTIC CONFIGURATION
-- ==========================================================================
vim.diagnostic.config({
    virtual_text = true,
    float = { focusable = false, border = "rounded" },
})

-- ==========================================================================
-- BOOTSTRAP LAZY.NVIM
-- ==========================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ==========================================================================
-- PLUGINS
-- ==========================================================================
require("lazy").setup({
  "neovim/nvim-lspconfig",
  "tpope/vim-fugitive",

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
    },
  },

  -- Treesitter: Fixed the module loading issue
  { 
    "nvim-treesitter/nvim-treesitter", 
    build = ":TSUpdate",
    config = function()
      -- Use pcall to avoid crashing if the module is missing during first install
      local status, configs = pcall(require, "nvim-treesitter.configs")
      if not status then
          return
      end
      configs.setup({
        ensure_installed = { "c", "lua", "vim", "vimdoc" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },

  { "nvchad/nvim-colorizer.lua", config = true },
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function() require('lualine').setup({ options = { theme = 'catppuccin' }}) end
  },
  
  -- Telescope
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.5',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      defaults = {
        preview = {
          treesitter = false -- Disable TS preview to prevent initialization crashes
        }
      }
    },
    keys = {
        { '<leader>ff', ':Telescope find_files<CR>', desc = 'Find File' },
        { '<leader>lg', ':Telescope live_grep<CR>', desc = 'Search Text' },
        { '<leader>D', ':Telescope diagnostics<CR>', desc = 'Project Diagnostics' },
    }
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
        require("toggleterm").setup({
            open_mapping = [[<c-\>]], 
            direction = 'float',      
            shell = "powershell.exe",
        })
    end
  },

  {
    'stevearc/oil.nvim',
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { view_options = { show_hidden = true } },
    keys = { { '<leader>e', ':Oil<CR>', desc = 'File Explorer' } }
  }
})

vim.cmd.colorscheme "catppuccin"

-- ==========================================================================
-- AUTOCOMPLETION SETUP
-- ==========================================================================
local cmp_status, cmp = pcall(require, 'cmp')
if cmp_status then
  cmp.setup({
    snippet = { expand = function(args) require('luasnip').lsp_expand(args.body) end },
    mapping = cmp.mapping.preset.insert({
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ['<Tab>'] = cmp.mapping.select_next_item(),
      ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    }),
    sources = cmp.config.sources({ { name = 'nvim_lsp' }, { name = 'path' } }, { { name = 'buffer' } })
  })
end

-- ==========================================================================
-- LSP CONFIGURATION
-- ==========================================================================
local lsp_status, lspconfig = pcall(require, "lspconfig")
if lsp_status then
  local capabilities = {}
  local cmp_lsp_status, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
  if cmp_lsp_status then
    capabilities = cmp_nvim_lsp.default_capabilities()
  end

  lspconfig.clangd.setup({
    cmd = { "D:/LLVM/bin/clangd.exe", "--background-index", "--clang-tidy" },
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      local opts = { buffer = bufnr, silent = true }
      keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      keymap.set('n', 'K',  vim.lsp.buf.hover, opts)
      keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
      keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    end,
  })
end
