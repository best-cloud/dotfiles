-- Minimal Neovim configuration managed by chezmoi.
-- Intentionally plugin-free: works offline on a fresh machine. Add a plugin
-- manager later if you want one.
--
-- The Windows profile sets XDG_CONFIG_HOME, so this same file is used on
-- Linux, macOS and Windows.

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
opt.breakindent = true
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.backup = false
opt.scrolloff = 8
opt.colorcolumn = "100"
opt.cursorline = true
opt.cursorlineopt = "number"
opt.confirm = true
opt.inccommand = "split"
opt.list = true
opt.listchars = "tab:» ,trail:·,nbsp:␣,extends:›,precedes:‹"
opt.fillchars = "eob: "
opt.completeopt = "menuone,noselect"
opt.wildmode = "longest:full,full"
opt.timeoutlen = 400
opt.ttimeoutlen = 10
opt.laststatus = 3
opt.formatoptions:remove("o")
opt.diffopt:append("linematch:60")

-- Keep undo files in the state directory instead of next to edited files.
local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir

-- netrw: a tree-style browser with no banner. `:Ex` still opens it.
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_winsize = 25

-- Teach Neovim the file types used by this repository.
vim.filetype.add({
  extension = { kdl = "kdl" },
  filename = { [".envrc"] = "sh" },
})

-- Diagnostics (LSP, if a server is started later): virtual text, sorted by
-- severity, and no virtual lines that shift the code around.
vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { border = "rounded", source = true },
})

-- Keep visual-mode indentation after pressing Tab.
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and keep selection" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and keep selection" })

-- Navigation between splits.
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left split" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower split" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper split" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right split" })

-- Diagnostics navigation and float. `jump` is Neovim 0.11+; fall back to the
-- older functions on 0.9/0.10 so the same config works on every packaged
-- Neovim.
local function diagnostic_prev()
  if vim.diagnostic.jump then
    vim.diagnostic.jump({ count = -1 })
  else
    vim.diagnostic.goto_prev()
  end
end
local function diagnostic_next()
  if vim.diagnostic.jump then
    vim.diagnostic.jump({ count = 1 })
  else
    vim.diagnostic.goto_next()
  end
end
vim.keymap.set("n", "[d", diagnostic_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", diagnostic_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>dh", vim.diagnostic.open_float, { desc = "Show diagnostic" })
vim.keymap.set("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostics to location list" })

-- Clear search highlighting.
vim.keymap.set("n", "<leader>nh", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Save and quit.
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Write buffer" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Leave terminal mode without closing the terminal buffer.
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })

-- Briefly highlight yanked text. `vim.hl` is 0.11+; `vim.highlight` still
-- exists on older releases.
local highlight_yank = (vim.hl and vim.hl.on_yank) or vim.highlight.on_yank
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  group = vim.api.nvim_create_augroup("user_yank", { clear = true }),
  callback = function()
    pcall(highlight_yank, { timeout = 150 })
  end,
})

-- Restore the cursor to the last edited line when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore last cursor position",
  group = vim.api.nvim_create_augroup("user_cursor", { clear = true }),
  callback = function(event)
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(event.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
