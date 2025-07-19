# nvim-p4

A Neovim plugin for intuitive and interactive Perforce changelist management.

## ✨ Features

- 🖥 Set/Switch active client using a popup menu
- 📋 Show all pending changelists for the active client
- 📂 Easily to edit opened file(s)

## 📃 Requirements

- Neovim 0.10 or later
- Perforce CLI ([p4](https://www.perforce.com/downloads/helix-core-server)) installed and configured.
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) for UI components
- [mini.icons](https://github.com/echasnovski/mini.icons) for file icons

## 📦 Installation

Install the plugin with lazy.nvim:

```lua
{
  "BigLittle/nvim-p4",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "echasnovski/mini.icons",
  },
  config = function()
    require("nvim-p4")
  end,
}
```

## 🧑‍💻 Usage

- `:P4Changes` to see the status of your Perforce workspace. If no client is set, a popup menu will appear.
   Keyboard shortcuts:
   | Key | Action |
   | F5 | Refresh |
   | o | Expand / Collapse a changelist |
   | e | Edit file(s) in a new buffer |
   | j / k | Navigation |
   | Esc / q | Hide window |

- `:P4Clients` to select a active client (workspace) from all your Perforce workspaces.
