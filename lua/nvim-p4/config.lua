local defalut = {
    client = {
    },
    changes = {
        keymaps = {
            edit = "e",
            move = "m",
            refresh = "<F5>",
            revert = "r",
            switch_client = "c",
            toggle_changelist = "<Space>",
        }
    }
}

local M = {}

function M.setup(user_opts)
    M.opts = vim.tbl_deep_extend("force", defalut, user_opts or {})

    local client = require("nvim-p4.client")
    local changes = require("nvim-p4.changes")
    local p4 = require("nvim-p4.p4")
    client.bootstrap()

    vim.api.nvim_create_user_command('P4Changes', function()
        client.ensure_client(function() changes.open() end)
    end, { desc = "View all pending changelists in current client." })

    vim.api.nvim_create_user_command('P4Clients', function()
        client.select_client(function()
            if client.name == nil then return end
            print("Selected Perforce client: " .. client.name)
        end)
    end, { desc = "Select a Perforce client." })

    vim.api.nvim_create_user_command('P4Info', function()
        client.ensure_client(function() print(p4.info()) end)
    end, { desc = "Show Perforce info." })

    vim.api.nvim_create_user_command('P4Edit', function()
        client.ensure_client(function()
            if client.name == nil then return end
            local path = vim.api.nvim_buf_get_name(0)
            p4.edit(nil, path)
            vim.cmd("checktime")
        end)
    end, { desc = "Open file in a client for edit." })
end

return M
