local client = require("nvim-p4.client")
client.bootstrap()

vim.api.nvim_create_user_command('P4V', function()
    if not client.get_current_client() then
        print("No Perforce client set. Please set a client first.")
        -- client.select_client(function()
        --     require("nvim-p4.changelists").open()
        -- end)
    else
        print("Opening P4V Explorer for client: " .. client.get_current_client())
        -- require("nvim-p4.changelists").open()
    end
end, { desc = "Open P4V Explorer" })

vim.api.nvim_create_user_command('P4Client', function()
    client.select_client(function(selected)
        print("Selected Perforce client: " .. selected)
    end)
end, { desc = "Select Perforce Client" })
