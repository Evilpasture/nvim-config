-- ==========================================================================
-- BASIC SETTINGS
-- ==========================================================================
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation
opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.smartindent = true

-- UI & Colors
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 10
opt.updatetime = 250 -- FAST UPDATE: This controls how quickly the error popup appears

-- Clipboard & Mouse
opt.mouse = 'a'
opt.clipboard = "unnamedplus"

-- Search
opt.ignorecase = true
opt.smartcase = true

-- Windows Specific
if vim.fn.has("win32") == 1 then
    opt.shell = "powershell.exe"
end

-- ==========================================================================
-- KEYBINDINGS (Global)
-- ==========================================================================
vim.g.mapleader = " "
local keymap = vim.keymap

-- File Operations
keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Save File' })
keymap.set('n', '<leader>q', ':q<CR>', { desc = 'Quit Neovim' })
keymap.set('n', '<c-s>', ':w<CR>')
keymap.set('i', '<c-s>', '<Esc>:w<CR>a')

-- Undo / Redo
keymap.set('n', '<C-z>', 'u', { desc = 'Undo' })
keymap.set('n', '<C-y>', '<C-r>', { desc = 'Redo' })

-- Clipboard
keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })
keymap.set('v', '<C-c>', '"+y', { desc = 'Copy' })
keymap.set('v', '<C-x>', '"+d', { desc = 'Cut' })
keymap.set('n', '<C-v>', '"+p', { desc = 'Paste' })
keymap.set('i', '<C-v>', '<C-r>+', { desc = 'Paste in Insert Mode' })

-- Window Navigation
keymap.set('n', '<leader>v', ':vsplit<CR>', { desc = 'Vertical Split' })
keymap.set('n', '<leader>h', ':split<CR>', { desc = 'Horizontal Split' })
keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Left Window' })
keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Right Window' })
keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Bottom Window' })
keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Top Window' })
keymap.set('n', '<leader>cx', ':close<CR>', { desc = 'Close Pane' })

-- Diagnostic Navigation (Jump between errors)
keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev Diagnostic' })
keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next Diagnostic' })

-- Git Keymaps (Fugitive)
keymap.set('n', '<leader>gs', vim.cmd.Git, { desc = 'Git Status' })
keymap.set('n', '<leader>gp', ':Git push<CR>', { desc = 'Git Push' })
keymap.set('n', '<leader>gl', ':Telescope git_commits<CR>', { desc = 'Git Log (Telescope)' })

-- ==========================================================================
-- BOOTSTRAP LAZY.NVIM
-- ==========================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
        lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ==========================================================================
-- PLUGINS
-- ==========================================================================
require("lazy").setup({

    -- 1. LSP & Mason (Heavily Guarded)
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            -- Protected Call for Mason
            local mason_status, mason = pcall(require, "mason")
            if not mason_status then return end
            mason.setup()

            -- Protected Call for Mason-LSPConfig
            local mason_lsp_status, mason_lsp = pcall(require, "mason-lspconfig")
            if not mason_lsp_status then return end

            mason_lsp.setup({
                ensure_installed = { "clangd", "lua_ls" },
                automatic_installation = true,
            })

            -- Protected Call for LSPConfig
            local lspconfig_status, lspconfig = pcall(require, "lspconfig")
            if not lspconfig_status then return end

            -- Protected Call for CMP Capabilities
            local cmp_lsp_status, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
            local capabilities = {}
            if cmp_lsp_status then
                capabilities = cmp_nvim_lsp.default_capabilities()
            end

            local on_attach = function(client, bufnr)
                local opts = { buffer = bufnr, silent = true }
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
            end

            -- Setup Handlers safely
            if mason_lsp.setup_handlers then
                mason_lsp.setup_handlers({
                    function(server_name)
                        lspconfig[server_name].setup({
                            capabilities = capabilities,
                            on_attach = on_attach,
                        })
                    end,
                    ["clangd"] = function()
                        lspconfig.clangd.setup({
                            capabilities = capabilities,
                            on_attach = on_attach,
                            cmd = { "clangd", "--background-index", "--clang-tidy" }
                        })
                    end,
                })
            end

            -- =================================================================
            -- DIAGNOSTIC CONFIG (Show errors automatically)
            -- =================================================================
            vim.diagnostic.config({
                virtual_text = {
                    prefix = '●', -- Could be '■', '▎', 'x'
                },
                signs = true,
                underline = true,
                update_in_insert = false,
                severity_sort = true,
                float = {
                    border = 'rounded',
                    source = 'always',
                    header = '',
                    prefix = '',
                },
            })

            -- MAGIC: Show diagnostic popup automatically on hover
            vim.cmd([[
            autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
            ]])
        end
    },

    -- 2. Autocompletion (Guarded)
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "rafamadriz/friendly-snippets",
            "onsails/lspkind.nvim",
        },
        config = function()
            local cmp_status, cmp = pcall(require, "cmp")
            if not cmp_status then return end

            local luasnip_status, luasnip = pcall(require, "luasnip")
            if not luasnip_status then return end

            local lspkind_status, lspkind = pcall(require, "lspkind")

            require('luasnip.loaders.from_vscode').lazy_load()

            cmp.setup({
                snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                    ['<Tab>'] = cmp.mapping.select_next_item(),
                    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'path' },
                }, {
                    { name = 'buffer' },
                }),
                formatting = {
                    format = lspkind_status and lspkind.cmp_format({
                        mode = 'symbol_text',
                        maxwidth = 50,
                        ellipsis_char = '...',
                    }) or nil
                }
            })
        end
    },

    -- 3. Formatting
    {
        'stevearc/conform.nvim',
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        opts = {
            formatters_by_ft = {
                lua = { "stylua" },
                c = { "clang-format" },
                cpp = { "clang-format" },
                javascript = { "prettier" },
            },
            format_on_save = { timeout_ms = 500, lsp_fallback = true },
        },
    },

    -- 4. Syntax Highlighting (Guarded)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            local status, configs = pcall(require, "nvim-treesitter.configs")
            if not status then return end

            configs.setup({
                ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "javascript", "python" },
                highlight = { enable = true },
                indent = { enable = true },
            })
        end
    },

    -- 5. Auto Pairs
    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        opts = {}
    },

    -- 6. Git Integration
    { "lewis6991/gitsigns.nvim",   config = true },
    { "tpope/vim-fugitive" },

    -- 7. UI & Theme
    { "catppuccin/nvim",           name = "catppuccin", priority = 1000 },
    { "nvchad/nvim-colorizer.lua", config = true },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            local status, lualine = pcall(require, 'lualine')
            if status then lualine.setup({ options = { theme = 'catppuccin' } }) end
        end
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        opts = {},
    },
    { "folke/which-key.nvim", event = "VeryLazy", opts = {} },

    -- 8. Navigation
    {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        branch = '0.1.x',
        opts = {
            defaults = {
                file_ignore_patterns = { "node_modules", ".git" },
                layout_strategy = 'horizontal',
                layout_config = { width = 0.9, height = 0.9 },
            }
        },
        keys = {
            { '<leader>ff', ':Telescope find_files<CR>',  desc = 'Find File' },
            { '<leader>lg', ':Telescope live_grep<CR>',   desc = 'Search Text' },
            { '<leader>D',  ':Telescope diagnostics<CR>', desc = 'Project Diagnostics' },
        }
    },
    {
        'stevearc/oil.nvim',
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = { view_options = { show_hidden = true } },
        keys = { { '<leader>e', ':Oil<CR>', desc = 'File Explorer' } }
    },
    {
        'stevearc/aerial.nvim',
        opts = { layout = { max_width = { 40, 0.2 }, min_width = 20 } },
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        keys = { { "<leader>a", "<cmd>AerialToggle!<CR>", desc = "Toggle Code Outline" } },
    },

    -- 9. Terminal
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        keys = {
            { "<C-`>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
            { "<C-`>", "<cmd>ToggleTerm<cr>", mode = "t",              desc = "Toggle Terminal" },
        },
        config = function()
            local status, toggleterm = pcall(require, "toggleterm")
            if not status then return end

            toggleterm.setup({
                direction = 'horizontal',
                size = 15,
                shell = vim.fn.has("win32") == 1 and "powershell.exe" or vim.o.shell,
            })
        end
    },
})

-- Apply Theme
vim.cmd.colorscheme "catppuccin"
