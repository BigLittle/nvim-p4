local client = require("nvim-p4.client")
client.bootstrap()

vim.api.nvim_create_user_command('P4V', function()
    if not client.get_current_client() then
        client.select_client(function()
            require("nvim-p4.changelists").open()
        end)
    else
        require("nvim-p4.changelists").open()
    end
end, {})
