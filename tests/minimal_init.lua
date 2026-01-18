-- tests/minimal_init.lua
-- Minimal init for testing ime-auto.nvim

-- Add current directory to runtimepath
vim.cmd([[set runtimepath+=.]])

-- Add plenary.nvim to runtimepath
vim.cmd([[set runtimepath+=~/.local/share/nvim/site/pack/vendor/start/plenary.nvim]])

-- Basic settings for testing
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.swapfile = false
vim.opt.backup = false

-- Explicitly load the plugin (plugin/ directory may not auto-load in headless mode)
vim.cmd([[runtime! plugin/ime-auto.lua]])

-- Load plenary for testing
require("plenary.busted")
