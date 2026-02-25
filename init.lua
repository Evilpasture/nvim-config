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

-- Force block cursor in all modes.
-- Thick blocks glow beautifully with the CRT bloom and don't get hidden by scanlines.
opt.guicursor = "n-v-c-sm:block,i-ci-ve:block,r-cr-o:block"
opt.sidescrolloff = 8 -- Keeps text away from the left/right curved glass edges

-- Replaces the default '~' on empty lines with a blank space
-- Makes the empty part of the screen look like an unlit CRT tube
opt.fillchars = { eob = " " }

if is_windows then
    -- Set shell to powershell
    opt.shell = "powershell.exe"

    -- This specific block fixes the XML/EntityName/Node errors
    opt.shellcmdflag =
    "-NoLogo -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
    opt.shellquote = ""
    opt.shellxquote = ""
    opt.shellpipe = "| Out-File -Encoding UTF8 %s"
    opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s"
end

-- ==========================================================================
-- SMART PYTHON VENV DETECTION
-- ==========================================================================
local function get_python_path()
    local venv_names = { ".venv", "venv", "env" }
    for _, name in ipairs(venv_names) do
        -- Use joinpath to handle slashes correctly for the OS
        local python_bin = vim.fs.joinpath(vim.fn.getcwd(), name, "Scripts", "python.exe")
        if vim.fn.executable(python_bin) == 1 then
            return python_bin
        end
    end
    return "python"
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

local function warn_insert()
    print("Go to Normal Mode.")
end
-- ==========================================================================
-- KEYBINDINGS (Global)
-- ==========================================================================
vim.g.mapleader = " "
local keymap = vim.keymap

-- File Operations
-- The Earthquake Save
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
-- Normal Mode: Standard paste is fine
keymap.set('n', '<C-v>', '"+p', { desc = 'Paste' })

-- Visual Mode: The "Sticky" Paste
-- 1. "_d  -> Delete selection into the black hole (trash it)
-- 2. " +P -> Paste the system clipboard BEFORE the cursor's new position
keymap.set('v', '<C-v>', '"_d"+P', { desc = 'Paste (Keep Clipboard)' })

-- Insert Mode: Already handled by <C-r> which doesn't overwrite
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
keymap.set('i', '<up>', warn_insert)
keymap.set('i', '<down>', warn_insert)
keymap.set('i', '<left>', warn_insert)
keymap.set('i', '<right>', warn_insert)

-- Preview Markdown with 'gp' (Get Preview)
keymap.set('n', 'gp', ':Glow<CR>', { desc = 'Toggle Glow Markdown Preview' })

-- Reset highlight when switching to Normal Mode
keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR><Esc>')

-- Smart Run Code (F5)
keymap.set('n', '<F5>', function()
    vim.cmd("w") -- Save file
    local ft = vim.bo.filetype
    local ok, toggleterm = pcall(require, "toggleterm")
    if not ok then return end

    -- Helper to make paths Windows/PowerShell safe
    -- 1. Convert / to \
    -- 2. Wrap in double quotes
    local function wrap(path)
        return '"' .. path:gsub("/", "\\") .. '"'
    end

    local raw_path = vim.fn.expand("%:p")
    local path = wrap(raw_path)
    local python = wrap(get_python_path())

    if ft == "python" then
        -- The '&' is the PowerShell call operator.
        -- It is MANDATORY when the command (python path) is a quoted string.
        local cmd = string.format('& %s %s', python, path)
        toggleterm.exec(cmd)
    elseif ft == "cpp" or ft == "c" then
        -- Get the executable path by removing the extension and adding .exe
        local raw_exe = vim.fn.expand("%:p:r") .. ".exe"
        local exe = wrap(raw_exe)
        local compiler = (ft == "cpp") and "clang++" or "clang"

        -- The logic: Compile, and IF (and only if) successful ($?), run the exe
        local cmd = string.format('%s %s -o %s ; if ($?) { & %s }', compiler, path, exe, exe)
        toggleterm.exec(cmd)
    elseif ft == "lua" then
        vim.cmd("luafile %")
        print("Lua script executed.")
    else
        print("No runner for: " .. ft)
    end
end, { desc = 'Save and Run Code' })

-- Open a terminal on the right (Vertical Split)
keymap.set('n', '<leader>tf', '<cmd>ToggleTerm direction=vertical size=60<cr>', { desc = 'Terminal Right' })

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
                ensure_installed = { "clangd", "lua_ls", "basedpyright", "ruff" },
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
                    -- Quick Fix: Automatically apply the first available code action
                    -- Inside your LspAttach callback block
                    vim.keymap.set('n', '<leader>f', function()
                        local line = vim.fn.line('.') - 1
                        local bufnr = vim.api.nvim_get_current_buf()

                        -- 1. Get Neovim diagnostics for the current line
                        local line_diagnostics = vim.diagnostic.get(bufnr, { lnum = line })

                        -- 2. Convert Neovim diagnostics to LSP-compatible diagnostics
                        local lsp_diagnostics = {}
                        for _, d in ipairs(line_diagnostics) do
                            -- Neovim stores the original LSP diagnostic in user_data
                            if d.user_data and d.user_data.lsp_diagnostic then
                                table.insert(lsp_diagnostics, d.user_data.lsp_diagnostic)
                            else
                                -- Fallback: manually reconstruct if user_data is missing
                                table.insert(lsp_diagnostics, {
                                    range = {
                                        start = { line = d.lnum, character = d.col },
                                        ["end"] = { line = d.end_lnum, character = d.end_col },
                                    },
                                    severity = d.severity,
                                    message = d.message,
                                    source = d.source or "clangd",
                                    code = d.code,
                                })
                            end
                        end

                        -- 3. Construct the request with a range covering the line
                        local params = {
                            textDocument = vim.lsp.util.make_text_document_params(),
                            range = {
                                start = { line = line, character = 0 },
                                ["end"] = { line = line, character = 1000 }, -- Cover the whole line
                            },
                            context = {
                                diagnostics = lsp_diagnostics -- Now correctly formatted
                            }
                        }

                        vim.lsp.buf_request(0, 'textDocument/codeAction', params, function(err, result, ctx, _)
                            if err or not result or vim.tbl_isempty(result) then
                                vim.notify("No fixes available on this line.", vim.log.levels.WARN)
                                return
                            end

                            local actions = {}
                            for _, item in ipairs(result) do
                                table.insert(actions, item.action or item)
                            end

                            local function get_priority(action)
                                local title = (action.title or ""):lower()
                                local kind = action.kind or ""
                                if title:match("designated") then return 10 end
                                if title:match("include") then return 9 end
                                if action.isPreferred then return 8 end
                                if kind:match("quickfix") then return 7 end
                                return 1
                            end

                            table.sort(actions, function(a, b)
                                return get_priority(a) > get_priority(b)
                            end)

                            local choice = actions[1]
                            local applied = false

                            if choice.edit then
                                vim.lsp.util.apply_workspace_edit(choice.edit, "utf-8")
                                applied = true
                            end

                            if choice.command then
                                local cmd = type(choice.command) == "table" and choice.command or choice
                                pcall(vim.lsp.buf.execute_command, cmd)
                                applied = true
                            end

                            if not applied then
                                pcall(vim.lsp.buf.execute_command, choice)
                            end

                            vim.notify("Sentience Applied: " .. choice.title, vim.log.levels.INFO)
                        end)
                    end, { buffer = event.buf, desc = "Super Strong Auto-fix" })
                    local client = vim.lsp.get_client_by_id(event.data.client_id)
                    if client and client.supports_method('textDocument/documentHighlight') then
                        local group = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })

                        -- Clear existing highlights before setting new ones
                        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                            buffer = event.buf,
                            group = group,
                            callback = vim.lsp.buf.document_highlight,
                        })

                        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                            buffer = event.buf,
                            group = group,
                            callback = vim.lsp.buf.clear_references,
                        })

                        -- Optional: Clear highlights when the LSP leaves the buffer
                        vim.api.nvim_create_autocmd('LspDetach', {
                            group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
                            callback = function(event2)
                                vim.lsp.buf.clear_references()
                                vim.api.nvim_clear_autocmds({ group = 'lsp-highlight', buffer = event2.buf })
                            end,
                        })
                    end
                end,
            })

            -- ==========================================
            -- 4. NATIVE SERVER CONFIGURATION (Neovim 0.11+)
            -- ==========================================

            -- Clangd
            vim.lsp.config('clangd', {
                capabilities = capabilities,
                cmd = {
                    "clangd",
                    "--background-index",
                    "--clang-tidy", -- This enables Clang-Tidy engine
                    "--header-insertion=iwyu",
                    "--completion-style=detailed",
                    "--function-arg-placeholders",
                    "--fallback-style=llvm",
                },
            })
            vim.lsp.enable('clangd')

            vim.lsp.inlay_hint.enable(true)

            -- Lua
            vim.lsp.config('lua_ls', {
                capabilities = capabilities,
                settings = {
                    Lua = {
                        completion = { callSnippet = "Replace" },
                        diagnostics = {
                            disable = { "missing-fields" },
                            globals = { "vim" },
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
                            pythonPath = get_python_path(),
                        },
                    },
                },
            })
            vim.lsp.enable('basedpyright')

            vim.lsp.config('ruff', { capabilities = capabilities, })
            vim.lsp.enable('ruff')

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
                    -- Use Ruff for fixing (imports) and formatting (black-compatible style)
                    python = { "ruff_fix", "ruff_format" },
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
            local ok, cp = pcall(require, "catppuccin")
            if ok then
                cp.setup({
                    transparent_background = true, -- <--- LETS THE CRT SHADER BREATHE
                    integrations = {
                        treesitter = true,
                        rainbow_delimiters = true,
                        telescope = true,
                        mason = true,
                    }
                })
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
                lualine.setup({
                    options = {
                        theme = 'catppuccin',
                        component_separators = '|',
                        section_separators = { left = '', right = '' },
                    },
                    sections = {
                        -- Add empty strings to the extreme edges to push content inward
                        -- away from the CRT curvature
                        lualine_a = { function() return ' ' end, 'mode' },
                        lualine_z = { 'location', function() return ' ' end }
                    }
                })
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
        branch = 'master',
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
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "refractalize/oil-git-status.nvim",
        },
        config = function()
            local ok, oil = pcall(require, "oil")
            if not ok then return end

            -- 1. Setup Oil
            oil.setup({
                columns = {
                    "icon",
                    -- "permissions", -- (Optional)
                    -- "size",        -- (Optional)
                    -- "mtime",       -- (Optional)
                },
                -- CRITICAL: This is what the README requires.
                -- We need space in the gutter for the git icons.
                win_options = {
                    signcolumn = "yes:2",
                },
                view_options = {
                    show_hidden = true,
                    is_hidden_file = function(name, bufnr)
                        return vim.startswith(name, ".")
                    end,
                    is_always_hidden = function(name, bufnr)
                        return name == ".." or name == ".git"
                    end,
                },
                float = {
                    padding = 2,
                    max_width = 100,
                    max_height = 0,
                    border = "rounded",
                    win_options = {
                        winblend = 0,
                    },
                },
            })

            -- 2. Setup Git Status (AFTER Oil)
            require("oil-git-status").setup({
                show_ignored = true, -- Show '!!' for ignored files
                symbols = {
                    -- Symbols for the "Index" (Staged changes)
                    index = {
                        ["A"] = "✚", -- Added
                        ["M"] = "", -- Modified
                        ["D"] = "✖", -- Deleted
                        ["R"] = "➜", -- Renamed
                    },
                    -- Symbols for the "Working Tree" (Unstaged changes)
                    working_tree = {
                        ["M"] = "", -- Modified
                        ["?"] = "★", -- Untracked
                        ["!"] = "", -- Ignored
                        ["D"] = "✖", -- Deleted
                    },
                }
            })

            -- 3. Set Colors for the Icons
            -- The plugin uses specific highlight groups. We link them to standard colors
            -- so they aren't just white text.
            vim.api.nvim_set_hl(0, "OilGitStatusIndexAdded", { link = "DiagnosticSignOk" })
            vim.api.nvim_set_hl(0, "OilGitStatusIndexModified", { link = "DiagnosticSignWarn" })
            vim.api.nvim_set_hl(0, "OilGitStatusWorkingTreeUntracked", { link = "DiagnosticSignInfo" })
            vim.api.nvim_set_hl(0, "OilGitStatusWorkingTreeModified", { link = "DiagnosticSignWarn" })
            vim.api.nvim_set_hl(0, "OilGitStatusWorkingTreeIgnored", { link = "Comment" })
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
                close_on_exit = false,
                auto_scroll = true,
                persist_mode = false,
                shell = is_windows and "powershell.exe" or vim.o.shell,
            })
        end,
        keys = {
            { "<C-`>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
            { "<C-`>", "<cmd>ToggleTerm<cr>", mode = "t",              desc = "Toggle Terminal" },
        },
    },
    {
        "ellisonleao/glow.nvim",
        config = true,
        cmd = "Glow",
        -- This ensures it only loads when you actually want to preview
    },

    -- Rainbow Delimiters
    {
        "hiphish/rainbow-delimiters.nvim",
        dependencies = "nvim-treesitter/nvim-treesitter",
        config = function()
            local rb = require('rainbow-delimiters')
            require('rainbow-delimiters.setup').setup({
                strategy = {
                    [''] = rb.strategy['global'], -- Use global strategy by default
                },
                query = {
                    [''] = 'rainbow-delimiters',
                    ['lua'] = 'rainbow-blocks',
                },
                highlight = {
                    'RainbowDelimiterRed',
                    'RainbowDelimiterYellow',
                    'RainbowDelimiterBlue',
                    'RainbowDelimiterOrange',
                    'RainbowDelimiterGreen',
                    'RainbowDelimiterViolet',
                    'RainbowDelimiterCyan',
                },
            })
        end
    },
    -- TODO Comments
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local ok, todo = pcall(require, "todo-comments")
            if ok then
                todo.setup({
                    -- The default signs look great, but you can
                    -- tweak them here if the CRT bloom makes them too "glowy"
                    highlight = {
                        multiline = true,
                        before = "",      -- "fg" or "bg" or empty
                        keyword = "wide", -- "fg", "bg", "wide"
                        after = "fg",
                    },
                })
            end
        end,
        keys = {
            { "<leader>td", "<cmd>TodoTelescope<cr>",                            desc = "Search TODOs" },
            { "]t",         function() require("todo-comments").jump_next() end, desc = "Next TODO" },
            { "[t",         function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
        }
    },
})

-- Allow escaping terminal with ESC and navigating with Ctrl-hjkl
function _G.set_terminal_keymaps()
    local opts = { buffer = 0 }
    vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
    vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], opts)
    vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], opts)
    vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], opts)
    vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], opts)
end

vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "term://*",
    callback = function()
        set_terminal_keymaps()
    end,
})

-- ==========================================================================
-- UTILS
-- ==========================================================================
vim.keymap.set('n', '<leader>wr', function()
    local reg = vim.v.register
    -- Default to 'a' if no register was specified (indicated by double quote)
    if reg == '"' then reg = 'a' end

    vim.ui.input({ prompt = 'Write to Register (' .. reg .. '): ' }, function(input)
        if input and input ~= "" then
            -- 1. Check if it's a letter (%a)
            -- 2. Check if it's uppercase
            local is_letter = reg:match("%a")
            local is_upper = reg == reg:upper()

            -- Mode 'a' = append, 'c' = create/replace
            local mode = (is_letter and is_upper) and "a" or "c"

            vim.fn.setreg(reg, input, mode)

            local action = mode == "a" and "Appended to @" or "Stored in @"
            vim.notify(action .. reg .. ": " .. input, vim.log.levels.INFO)
        end
    end)
end, { desc = "Write string to register (Use uppercase like 'A' to append)" })


-- Link these to existing theme highlights so they look natural
-- LspReferenceWrite usually implies the variable is being CHANGED.
vim.api.nvim_set_hl(0, "LspReferenceText", { link = "Visual" })
vim.api.nvim_set_hl(0, "LspReferenceRead", { link = "Visual" })
vim.api.nvim_set_hl(0, "LspReferenceWrite", { underline = true, bold = true, sp = "Yellow" })


-- ==========================================================================
-- AUTO-START CLICKER DAEMON
-- ==========================================================================
local function start_clicker()
    -- Get the path to your nvim config folder
    local nvim_dir = vim.fn.stdpath("config")
    -- Path to your compiled binary
    local clicker_path = nvim_dir .. "\\build\\clicker.exe"

    -- Check if it actually exists before trying to run it
    if vim.fn.executable(clicker_path) == 1 then
        -- Start the process in the background
        -- 'detach = true' keeps it running even if Neovim reloads
        -- 'hide = true' ensures no annoying console window pops up
        vim.fn.jobstart({ clicker_path }, {
            detach = true,
            hide = true,
            on_exit = function()
                print("Clicker Daemon stopped.")
            end
        })
    else
        vim.notify("Clicker binary not found at: " .. clicker_path, vim.log.levels.WARN)
    end
end

-- Run it on startup
start_clicker()


-- ==========================================================================
-- AUDIO BRIDGE (CRT CLACK) with DEBOUNCE
-- ==========================================================================
local last_clack_time = 0
local CLACK_COOLDOWN = 40 -- ms (Adjust this: lower = faster, higher = more "stiff")

local function send_clack(char)
    local now = vim.uv.now()
    if (now - last_clack_time) < CLACK_COOLDOWN then
        return -- Skip this clack, we're typing too fast!
    end
    last_clack_time = now

    local pipe_path = "\\\\.\\pipe\\nvim_clack"
    vim.uv.fs_open(pipe_path, "w", 438, function(err, fd)
        if not err and fd then
            vim.uv.fs_write(fd, char, nil, function()
                vim.uv.fs_close(fd)
            end)
        end
    end)
end

local clack_group = vim.api.nvim_create_augroup("ClackGroup", { clear = true })

-- 1. Normal Typing: Sends 's' for space, 'k' for everything else
vim.api.nvim_create_autocmd("InsertCharPre", {
    group = clack_group,
    callback = function()
        if vim.v.char == " " then
            send_clack("s")
        else
            send_clack("k")
        end
    end,
})

-- 2. Enter Key: Sends 'e'
vim.keymap.set('i', '<CR>', function()
    send_clack("e")
    return "<CR>"
end, { expr = true })

-- 3. Backspace: Sends 'k' (or 's' if you prefer a lighter clack)
vim.keymap.set('i', '<BS>', function()
    send_clack("k")
    return "<BS>"
end, { expr = true })

-- 4. Save Sound: Sends 'e' when you save the file
vim.api.nvim_create_autocmd("BufWritePost", {
    group = clack_group,
    callback = function()
        send_clack("e")
    end,
})

-- The Earthquake Save
vim.keymap.set('n', '<leader>w', function()
    vim.cmd("w")
    send_clack("x") -- Send the explosion signal!
end, { desc = 'Save File & Shake Screen' })
