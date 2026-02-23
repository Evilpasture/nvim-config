-- ==========================================================================
-- BASIC SETTINGS
-- ==========================================================================
local opt = vim.opt

-- Defensive Wrapper for OS detection
local is_windows = vim.fn.has("win32") == 1

opt.number = true
opt.relativenumber = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.smartindent = true
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 10
opt.updatetime = 250 -- Fast update for diagnostic hover

opt.mouse = 'a'
opt.clipboard = "unnamedplus"
opt.mousemoveevent = true -- Enable mouse hover events
opt.ignorecase = true
opt.smartcase = true

if is_windows then
    opt.shell = "powershell.exe"
end


-- ==========================================================================
-- FILETYPE AND TREESITTER BRIDGE
-- ==========================================================================
vim.filetype.add({
    extension = {
        hlsl = "hlsl",
        glsl = "glsl",
        vert = "glsl",
        frag = "glsl",
    },
})

-- Register the language BEFORE lazy-loading starts
vim.treesitter.language.register('hlsl', 'hlsl')
vim.treesitter.language.register('glsl', 'glsl')

-- Create the autocmd HERE (Global scope)
-- This ensures that as soon as a file is identified as hlsl,
-- it tries to start treesitter, even if the plugin is still loading.
vim.api.nvim_create_autocmd({ "FileType" }, {
    pattern = { "hlsl", "glsl" },
    callback = function(ev)
        pcall(vim.treesitter.start, ev.buf, "hlsl")
    end,
})

local function warn()
    print("Use HJKL. Please.")
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

-- IDE-style Tab Indenting
keymap.set('v', '<Tab>', '>gv', { desc = 'Indent selection' })
keymap.set('v', '<S-Tab>', '<gv', { desc = 'Unindent selection' })

-- Window Navigation
keymap.set('n', '<leader>v', ':vsplit<CR>', { desc = 'Vertical Split' })
keymap.set('n', '<leader>h', ':split<CR>', { desc = 'Horizontal Split' })
keymap.set('n', '<C-h>', '<C-w>h')
keymap.set('n', '<C-l>', '<C-w>l')
keymap.set('n', '<C-j>', '<C-w>j')
keymap.set('n', '<C-k>', '<C-w>k')
keymap.set('n', '<leader>cx', ':close<CR>', { desc = 'Close Pane' })

-- Diagnostic Navigation
keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev Diagnostic' })
keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next Diagnostic' })

-- Git Keymaps
keymap.set('n', '<leader>gs', vim.cmd.Git, { desc = 'Git Status' })
keymap.set('n', '<leader>gp', ':Git push<CR>', { desc = 'Git Push' })

-- Disable Arrow keys in Normal mode
keymap.set('n', '<up>', warn)
keymap.set('n', '<down>', warn)
keymap.set('n', '<left>', warn)
keymap.set('n', '<right>', warn)

-- Disable Arrow keys in Insert mode (Force the escape habit)
keymap.set('i', '<up>', '<nop>')
keymap.set('i', '<down>', '<nop>')
keymap.set('i', '<left>', '<nop>')
keymap.set('i', '<right>', '<nop>')

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

    -- NEW: lazydev.nvim (Solves the "vim" global issue perfectly)
    {
        "folke/lazydev.nvim",
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                -- Load luvit types when the `vim.uv` word is found
                { path = "luvit-meta/library", words = { "vim%.uv" } },
            },
        },
    },
    { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` types

    -- 1. LSP & Mason
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            local ok_mason, mason = pcall(require, "mason")
            local ok_mason_lsp, mason_lsp = pcall(require, "mason-lspconfig")
            local ok_cmp_lsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

            if not (ok_mason and ok_mason_lsp) then return end

            -- 1. Mason handles DOWNLOADING the servers
            mason.setup()
            mason_lsp.setup({
                ensure_installed = { "clangd", "lua_ls", "basedpyright" },
                automatic_installation = true,
            })

            -- 2. Shared Capabilities (for nvim-cmp autocompletion)
            local capabilities = ok_cmp_lsp and cmp_nvim_lsp.default_capabilities() or {}

            -- 3. Native Neovim Keymaps (Replaces on_attach)
            -- This runs automatically whenever ANY language server attaches to a buffer
            vim.api.nvim_create_autocmd('LspAttach', {
                desc = 'LSP Actions',
                callback = function(event)
                    local opts = { buffer = event.buf, silent = true }
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)

                    -- Balanced K Hover logic
                    vim.keymap.set('n', 'K', function()
                        local winid = vim.diagnostic.open_float(nil, { focusable = false, scope = "cursor" })
                        if not winid then vim.lsp.buf.hover() end
                    end, opts)
                end,
            })

            -- ==========================================
            -- 4. NATIVE SERVER CONFIGURATION (Neovim 0.11+)
            -- ==========================================

            -- Clangd
            vim.lsp.config('clangd', { capabilities = capabilities })
            vim.lsp.enable('clangd')

            -- Lua
            vim.lsp.config('lua_ls', {
                capabilities = capabilities,
                settings = {
                    Lua = {
                        completion = { callSnippet = "Replace" },
                        diagnostics = {
                            disable = { "missing-fields" },
                            globals = { "vim" }, -- <--- ADD THIS LINE
                        },
                        -- Optional but highly recommended:
                        -- Tells lua_ls where the rest of Neovim's source code is
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                    },
                },
            })
            vim.lsp.enable('lua_ls')

            -- Python (Basedpyright)
            vim.lsp.config('basedpyright', {
                capabilities = capabilities,
                settings = {
                    basedpyright = {
                        analysis = {
                            autoSearchPaths = true,
                            diagnosticMode = "openFilesOnly",
                            typeCheckingMode = "basic",
                        },
                    },
                },
            })
            vim.lsp.enable('basedpyright')

            -- ==========================================

            -- Smart Auto-Hover Logic
            vim.api.nvim_create_autocmd("CursorHold", {
                callback = function()
                    -- 1. If we're in Insert mode or a floating window is already open, stop.
                    if vim.api.nvim_get_mode().mode ~= 'n' then return end

                    for _, winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
                        local conf = vim.api.nvim_win_get_config(winid)
                        if conf.relative ~= "" then return end
                    end

                    -- 2. Try to show Diagnostics.
                    -- In Neovim, open_float returns the window ID if it opens one.
                    local diag_winid, _ = vim.diagnostic.open_float(nil, {
                        focusable = false,
                        scope = "cursor",
                        border = "rounded"
                    })

                    -- 3. If NO diagnostic window was opened, trigger LSP Hover (Shift+K)
                    if not diag_winid then
                        pcall(vim.lsp.buf.hover, {
                            focusable = false,
                            border = "rounded"
                        })
                    end
                end
            })
        end
    },
    -- 2. Autocompletion (Defensive)
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
            local ok_cmp, cmp = pcall(require, "cmp")
            if not ok_cmp then return end

            local ok_luasnip, luasnip = pcall(require, "luasnip")
            if not ok_luasnip then return end

            local ok_lspkind, lspkind = pcall(require, "lspkind")

            -- Safe snippet loading
            pcall(function() require('luasnip.loaders.from_vscode').lazy_load() end)

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
                    format = ok_lspkind and lspkind.cmp_format({
                        mode = 'symbol_text',
                        maxwidth = 50,
                        ellipsis_char = '...',
                    }) or nil
                }
            })
        end
    },

    -- 3. Formatting (Defensive)
    {
        'stevearc/conform.nvim',
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        config = function()
            local ok, conform = pcall(require, "conform")
            if not ok then return end

            conform.setup({
                formatters_by_ft = {
                    lua = { "stylua" },
                    c = { "clang-format" },
                    cpp = { "clang-format" },
                    hlsl = { "clang-format" },
                    glsl = { "clang-format" },
                    python = { "black" }, -- Python Formatter
                    javascript = { "prettier" },
                },
                format_on_save = { timeout_ms = 500, lsp_fallback = true },
            })
        end
    },

    -- 4. Syntax Highlighting
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" }, -- Load when opening a file
        config = function()
            local ok, configs = pcall(require, "nvim-treesitter.configs")
            if not ok then return end

            -- 1. Get the installer module
            local install = require('nvim-treesitter.install')

            -- 2. Configure compilers
            -- On Windows, 'zig' is a great choice, but we must tell
            -- Treesitter to use it correctly without manual Env vars.
            install.compilers = { "zig" }
            install.prefer_git = false

            configs.setup({
                -- Add "zig" to ensure_installed if you want highlighting for zig files too
                ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "javascript", "python", "hlsl", "glsl" },
                highlight = { enable = true, additional_vim_regex_highlighting = false, },
                indent = { enable = true },
            })
        end
    },

    -- 5. Auto Pairs
    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        config = function()
            local ok, npairs = pcall(require, "nvim-autopairs")
            if ok then npairs.setup({}) end
        end
    },

    -- 6. Git Integration
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            local ok, gs = pcall(require, "gitsigns")
            if ok then gs.setup() end
        end
    },
    { "tpope/vim-fugitive" },

    -- 7. UI & Theme
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            -- Defensive: check if catppuccin loads, then apply
            local ok = pcall(require, "catppuccin")
            if ok then
                vim.cmd.colorscheme "catppuccin"
            end
        end
    },
    {
        "nvchad/nvim-colorizer.lua",
        config = function()
            local ok, colorizer = pcall(require, "colorizer")
            if ok then colorizer.setup() end
        end
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            local ok, lualine = pcall(require, 'lualine')
            if ok then
                lualine.setup({ options = { theme = 'catppuccin' } })
            end
        end
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        config = function()
            local ok, ibl = pcall(require, "ibl")
            if ok then ibl.setup() end
        end
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            local ok, wk = pcall(require, "which-key")
            if ok then wk.setup() end
        end
    },

    -- 8. Navigation
    {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        branch = '0.1.x',
        config = function()
            local ok, telescope = pcall(require, "telescope")
            if not ok then return end

            telescope.setup({
                defaults = {
                    file_ignore_patterns = { "node_modules", ".git" },
                    layout_strategy = 'horizontal',
                    layout_config = { width = 0.9, height = 0.9 },
                }
            })
        end,
        keys = {
            { '<leader>ff', ':Telescope find_files<CR>',  desc = 'Find File' },
            { '<leader>lg', ':Telescope live_grep<CR>',   desc = 'Search Text' },
            { '<leader>D',  ':Telescope diagnostics<CR>', desc = 'Project Diagnostics' },
        }
    },
    {
        'stevearc/oil.nvim',
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            local ok, oil = pcall(require, "oil")
            if ok then oil.setup({ view_options = { show_hidden = true } }) end
        end,
        keys = { { '<leader>e', ':Oil<CR>', desc = 'File Explorer' } }
    },
    {
        'stevearc/aerial.nvim',
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        config = function()
            local ok, aerial = pcall(require, "aerial")
            if ok then
                aerial.setup({ layout = { max_width = { 40, 0.2 }, min_width = 20 } })
            end
        end,
        keys = { { "<leader>a", "<cmd>AerialToggle!<CR>", desc = "Toggle Code Outline" } },
    },

    -- 9. Terminal
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        config = function()
            local ok, toggleterm = pcall(require, "toggleterm")
            if not ok then return end

            toggleterm.setup({
                direction = 'horizontal',
                size = 15,
                shell = is_windows and "powershell.exe" or vim.o.shell,
            })
        end,
        keys = {
            { "<C-`>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
            { "<C-`>", "<cmd>ToggleTerm<cr>", mode = "t",              desc = "Toggle Terminal" },
        },
    },
})
