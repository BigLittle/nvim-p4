local client = require("nvim-p4.client")
client.bootstrap()

vim.api.nvim_create_user_command('P4Changes', function()
    if client.name == nil then client.select_client() end
    if client.name == nil then return end
    require("nvim-p4.changes").open()
end, { desc = "View all changelists in current client." })

vim.api.nvim_create_user_command('P4Clients', function()
    client.select_client(function(selected)
        print("Selected Perforce client: " .. selected)
    end)
end, { desc = "List Perforce clients." })
