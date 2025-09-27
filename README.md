# nvim-p4

A Neovim plugin for intuitive and interactive Perforce changelist management.

## ✨ Features

- 🖥 Set/Switch active client using a popup menu
- 📋 Show all pending changelists for the active client
- 📂 Edit opened file(s) in a new buffer
- 🚚 Move opened file bewteen changelists
- 🔄 Revert opened file
- 📊 Diff opened file against have / latest revision
- 🔍 Blame current line in opened file 
- 🕒 Refresh changelists automatically (Default off)

## 📃 Requirements

- Neovim 0.10 or later
- Perforce CLI ([p4](https://www.perforce.com/downloads/helix-core-server)) installed and configured.
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) for UI components
- [mini.icons](https://github.com/nvim-mini/mini.icons) for file icons

## 📦 Installation

Install the plugin with lazy.nvim:

```lua
{
  "BigLittle/nvim-p4",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-mini/mini.icons",
  },
  opts = {
    -- your options here
    -- leave empty for defaults
  },
}
```

## ⚙️ Configuration
```lua
{
  blame = {
    icons = {
      date = "󰥔",
      changelist = "",
      user = "",
    },
  },
  changes = {
    description_window_size = {
      width = 50,
      height = 10 
    },
    refresh_on_open = {
      enabled = true,
      threshold = 30, -- in minutes
    auto_refresh = {
      enabled = false,
      interval = 300000, -- in milliseconds
    },
    keymaps = {
      create_changelist = "c",
      diff = "d",
      edit_changelist = "e",
      move = "m",
      open = "o",
      refresh = "<F5>",
      revert = "r",
      switch_client = "s",
      toggle_changelist = "<Space>",
    },
    icons = {
      client = "",
      edited = "󰷈",
      opened = "󰈔",
      synced = "󱍸",
      unknown_ft = "",
      unresolved = "󰷊",
      unsynced = "",
    },
  },
}
```

## 🧑‍💻 Usage

`:P4Blame` to show the commit changelist, author, and timestamp that last modified the line. 

`:P4Changes` to see the status of current active client. If no client is set, a popup menu will appear. 

   | Key     | Action                                 |
   | ------- | -------------------------------------- |
   | Esc / q | Hide window                            |
   | F5      | Refresh current status                 |
   | Space   | Expand / Collapse a changelist         |
   | c       | Create a new pending changelist        |
   | e       | Edit a pending changelist              |
   | d       | Diff opened file                       |
   | j / k   | Navigation                             |
   | m       | Move opened file to another changelist |
   | o       | Open file(s) in a new buffer           |
   | r       | Revert opened file                     |
   | s       | Switch to another client               |

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
