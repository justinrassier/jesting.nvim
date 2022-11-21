local jesting = require("jesting")
local utils = require("jesting.utils")

vim.api.nvim_create_user_command("JestingAttach", function()
	local current_buffer = vim.api.nvim_buf_get_name(0)
	local cmd = {
		"npx",
		"jest",
		"--testPathPattern=" .. current_buffer,
		"--json",
		"--outputFile=/tmp/results.json",
	}
	jesting.attach(cmd)
end, {})

vim.api.nvim_create_user_command("JestingAttachNx", function()
	local current_buffer = vim.api.nvim_buf_get_name(0)
	local project_name = utils.get_project_name_from_path(current_buffer)
	local cmd = {
		"nx",
		"test",
		project_name,
		"--testFile=" .. current_buffer,
		"--json",
		"--outputFile=/tmp/results.json",
		"--skip-nx-cache",
	}

	jesting.attach(cmd)
end, {})

vim.api.nvim_create_user_command("JestingUnattach", "lua require('jesting').unattach()", {})
