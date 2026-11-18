-- Minimal Neovim configuration managed by chezmoi.
-- Intentionally plugin-free: works offline on a fresh machine. Add a plugin
-- manager later if you want one.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
-- Only use the system clipboard when a provider (wl-copy, xclip, pbcopy, …)
-- exists. Headless servers have none, and yanks would fail without this guard.
if vim.fn.has("clipboard") == 1 then
  opt.clipboard = "unnamedplus"
end
opt.termguicolors = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.scrolloff = 8
opt.colorcolumn = "100"

-- Keep visual-mode indentation after pressing Tab.
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- Navigation between splits.
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Clear search highlighting.
vim.keymap.set("n", "<leader>nh", "<cmd>nohlsearch<cr>")

-- Save and quit.
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>")
