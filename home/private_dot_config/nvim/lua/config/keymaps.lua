-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Keep deletes out of the unnamed/system clipboard. Explicit yanks still use
-- `unnamedplus`, as configured in lua/plugins/clipboard.lua.
vim.keymap.set({ "n", "x" }, "d", '"_d', { desc = "Delete without copying" })

-- Ghostty sends Cmd+C as CSI-u <D-c>. Without a visual-mode binding, Nvim
-- treats it like `c` (change selection), deleting the text and entering
-- Insert mode. Copy and reselect the original range instead.
vim.keymap.set("x", "<D-c>", '"+ygv', { desc = "Copy selection and keep it" })
