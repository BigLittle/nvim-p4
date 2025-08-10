# nvim-p4

A Neovim plugin for intuitive and interactive Perforce changelist management.

## ✨ Features

- 🖥 Set/Switch active client using a popup menu
- 📋 Show all pending changelists for the active client
- 📂 Easily to edit opened file(s)
- 🚚 Move opened file bewteen changelists
- 🔄 Revert opened file
- 📊 Diff opened file against have / latest revision.
- 👈 Blame line in opened file 

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
  opts = {}
}
```

## 🧑‍💻 Usage

`:P4BlameLine` to show the commit changelist, author, and timestamp that last modified the line. 

`:P4Changes` to see the status of current active client. If no client is set, a popup menu will appear. 

   | Key     | Action                                 |
   | ------- | -------------------------------------- |
   | Esc / q | Hide window                            |
   | F5      | Refresh current status                 |
   | Space   | Expand / Collapse a changelist         |
   | c       | Switch to another client               |
   | d       | Diff opened file                       |
   | e       | Edit file(s) in a new buffer           |
   | j / k   | Navigation                             |
   | m       | Move opened file to another changelist |
   | r       | Revert opened file                     |

`:P4Clients` to select an active client from all your Perforce workspaces.

   | Key     | Action        |
   | ------- | ------------- |
   | Enter   | Select client |
   | Esc / q | Close window  |
   | j / k   | Navigation    |

`:P4Diff` to compare current buffer file to the depot content (the latest revision).

`:P4Edit` to make current buffer file opened for edit in current active client.

`:P4Revert` to revert current buffer file.

`:P4RevertIfUnchanged` to revert current buffer file if it's unchanged.
