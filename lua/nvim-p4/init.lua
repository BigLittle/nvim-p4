local changes = require("nvim-p4.changes")
local client = require("nvim-p4.client")
local p4 = require("nvim-p4.p4")

client.bootstrap()

vim.api.nvim_create_user_command('P4Changes', function()
    if client.name == nil then client.select_client() end
    if client.name == nil then return end
    changes.open()
end, { desc = "View all pending changelists in current client." })

vim.api.nvim_create_user_command('P4Clients', function()
    client.select_client(function()
        if client.name == nil then return end
        print("Selected Perforce client: " .. client.name)
    end)
end, { desc = "Select a Perforce client." })

vim.api.nvim_create_user_command('P4Info', function()
    client.ensure_client(function()
        print(p4.info())
    end)
end, { desc = "Show Perforce info." })
