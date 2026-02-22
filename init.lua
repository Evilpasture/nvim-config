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

-- Undo / Redo (Ctrl+Z, Ctrl+Y)
keymap.set('n', '<C-z>', 'u', { desc = 'Undo' })
keymap.set('n', '<C-y>', '<C-r>', { desc = 'Redo' })
keymap.set('i', '<C-z>', '<Esc>ua', { desc = 'Undo in Insert Mode' })
keymap.set('i', '<C-y>', '<Esc><C-r>a', { desc = 'Redo in Insert Mode' })

-- Standard Clipboard Operations
keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })
keymap.set('v', '<C-c>', '"+y', { desc = 'Copy to Clipboard' })
keymap.set('v', '<C-x>', '"+d', { desc = 'Cut to Clipboard' })
keymap.set('n', '<C-v>', '"+p', { desc = 'Paste from Clipboard' })
keymap.set('i', '<C-v>', '<C-r>+', { desc = 'Paste in Insert Mode' })

-- Shift + Arrow Selection
keymap.set('n', '<S-Up>', 'v<Up>')
keymap.set('n', '<S-Down>', 'v<Down>')
keymap.set('n', '<S-Left>', 'v<Left>')
keymap.set('n', '<S-Right>', 'v<Right>')
keymap.set('v', '<S-Up>', '<Up>')
keymap.set('v', '<S-Down>', '<Down>')
keymap.set('v', '<S-Left>', '<Left>')
keymap.set('v', '<S-Right>', '<Right>')
keymap.set('i', '<S-Up>', '<Esc>v<Up>')
keymap.set('i', '<S-Down>', '<Esc>v<Down>')
keymap.set('i', '<S-Left>', '<Esc>v<Left>')
keymap.set('i', '<S-Right>', '<Esc>v<Right>')

-- Diagnostic Navigation & Floating Window
keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })
keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Show line diagnostics' })

-- Git Keymaps (Fugitive)
keymap.set('n', '<leader>gs', vim.cmd.Git, { desc = 'Git Status' })
keymap.set('n', '<leader>gp', ':Git push<CR>', { desc = 'Git Push' })

-- Window Navigation
keymap.set('n', '<C-h>', '<C-w>h')
keymap.set('n', '<C-j>', '<C-w>j')
keymap.set('n', '<C-k>', '<C-w>k')
keymap.set('n', '<C-l>', '<C-w>l')

-- ==========================================================================
-- DIAGNOSTIC CONFIGURATION
-- ==========================================================================
vim.diagnostic.config({
    virtual_text = true,
    float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
    },
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
  
  -- Git integration
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

  -- Syntax Highlighting
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

  -- Color Highlighter
  { 
    "nvchad/nvim-colorizer.lua",
    config = function() require("colorizer").setup() end 
  },

  -- Which-Key
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },

  -- Theme & Aesthetics
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
    keys = {
        { '<leader>ff', ':Telescope find_files<CR>', desc = 'Find File' },
        { '<leader>lg', ':Telescope live_grep<CR>', desc = 'Search Text' },
        { '<leader>D', ':Telescope diagnostics<CR>', desc = 'Project Diagnostics' },
    }
  },

  -- Toggleterm
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
        require("toggleterm").setup({
            open_mapping = [[<c-\>]], 
            direction = 'float',      
            shell = "powershell.exe",
            float_opts = {
                border = 'curved',
                width = function() return math.ceil(vim.o.columns * 0.8) end,
                height = function() return math.ceil(vim.o.lines * 0.8) end,
            }
        })
    end
  },

  -- Oil.nvim
  {
    'stevearc/oil.nvim',
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { view_options = { show_hidden = true } },
    keys = { { '<leader>e', ':Oil<CR>', desc = 'File Explorer' } }
  }
})

vim.cmd.colorscheme "catppuccin"

-- ==========================================================================
-- TREESITTER SETUP
-- ==========================================================================
local ts_status, ts_configs = pcall(require, "nvim-treesitter.configs")
if ts_status then
    ts_configs.setup({
        ensure_installed = { "c", "lua", "vim", "vimdoc" },
        highlight = { enable = true },
        indent = { enable = true },
    })
end

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
      keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    end,
  })
end
