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
		"npx",
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

vim.api.nvim_create_user_command("JestingAttachSingleTestNx", function()
	local current_buffer = vim.api.nvim_buf_get_name(0)
	local project_name = utils.get_project_name_from_path(current_buffer)
	local it_name = nil

	local curren_line_num = vim.api.nvim_win_get_cursor(0)[1]

	-- go up the file until we find a line that starts with 'it'
	local line_num = curren_line_num
	while line_num > 0 do
		local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
		local match = jesting.get_matching_it_statements_for_line(line)
		if match then
			it_name = match
			break
		end
		line_num = line_num - 1
	end

	if it_name == nil then
		vim.notify("Could not find test name for current line", vim.log.levels.ERROR, { title = "Jesting" })
		return
	end

	local cmd = {
		"npx",
		"nx",
		"test",
		project_name,
		"--testFile=" .. current_buffer,
		'--testNamePattern="' .. it_name .. '$"',
		"--json",
		"--outputFile=/tmp/results.json",
		"--skip-nx-cache",
	}

	jesting.attach(cmd, it_name)
end, {})

vim.api.nvim_create_user_command("JestingCloseConsoleLogWindow", function()
	jesting.clear_console_log_stuff()
end, {})

vim.api.nvim_create_user_command("JestingUnattach", "lua require('jesting').unattach()", {})
