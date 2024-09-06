local popup = require("plenary.popup")
local M = {}

local config = {
	console_log_window_width = 80,
	integrated_terminal_size = 80,
	integrated_terminal_orientation = "vertical",
}

local inline_testing_augroup = vim.api.nvim_create_augroup("Jesting", { clear = true })
local inline_testing_ns = vim.api.nvim_create_namespace("Jesting")
local inline_testing_results = {}
local test_results_winnr = nil

local console_logs = {}
local capturing_logs = false
local console_log_win = nil
local console_log_buf = nil

local std_out_messages = {}

local jobId = nil

M.buf_to_status_map = {}
local STATUS_MAP = {
	["ATTACHED"] = "🔗",
	["RUNNING"] = "⏳",
	["PASSED"] = "✅",
	["FAILED"] = "❌",
}

function clean_terminal_control_characters(text)
	-- Pattern to match terminal control characters
	local control_char_pattern = "\x1b%[%d*[%a-zA-Z]"
	-- Remove all terminal control characters
	local cleaned_input = text:gsub(control_char_pattern, "")
	return cleaned_input
end

function M.lualine_status()
	local current_buf_nr = vim.api.nvim_get_current_buf()
	local jesting_status = M.buf_to_status_map[current_buf_nr]
	if jesting_status then
		return string.format("%s", jesting_status)
	end
	return ""
end

function M.run_nx_test_for_file_in_terminal(project_name)
	-- get file name for the current buffer
	local current_buffer = vim.api.nvim_buf_get_name(0)

	-- build command string
	local test_command = "nx test " .. project_name .. " --testFile " .. current_buffer .. " --watch"

	local terminal_orientation = config.integrated_terminal_orientation == "vertical" and "vnew" or "new"
	-- execute the nx command in a new terminal buffer
	vim.fn.execute(
		tostring(config.integrated_terminal_size) .. " " .. terminal_orientation .. " | terminal " .. test_command
	)
end

function M.unattach()
	local bufnr = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(bufnr)
	M.buf_to_status_map[bufnr] = nil
	M.clear_namespace_for_current_buffer(bufnr)
	vim.api.nvim_clear_autocmds({ group = inline_testing_augroup, pattern = buf_name })

	if jobId ~= nil then
		vim.fn.jobstop(jobId)
		jobId = nil
	end
	vim.notify("Jesting unattached from " .. buf_name, vim.log.levels.INFO, { title = "Jesting" })
end

function M.attach(cmd, single_test)
	-- force killing any running jobs
	if jobId ~= nil then
		vim.fn.jobstop(jobId)
		jobId = nil
	end
	local buf_name = vim.api.nvim_buf_get_name(0)
	local buf_nr = vim.api.nvim_get_current_buf()
	M.buf_to_status_map[buf_nr] = STATUS_MAP["ATTACHED"]

	vim.api.nvim_create_autocmd("VimLeave", {
		group = inline_testing_augroup,
		callback = function()
			-- force killing any running jobs
			if jobId ~= nil then
				vim.fn.jobstop(jobId)
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = inline_testing_augroup,
		pattern = buf_name,
		callback = function(args)
			M.buf_to_status_map[buf_nr] = STATUS_MAP["RUNNING"]
			inline_testing_results = {}
			M.clear_console_log_stuff()

			local bufnr = vim.api.nvim_get_current_buf()
			M.clear_namespace_for_current_buffer(bufnr)

			-- add an hour glass to each test line
			local line_num = 0
			for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
				-- get the test name from the it statement
				local test = M.get_matching_it_statements_for_line(line)
				local text = { "⌛" }

				if test ~= nil then
					if single_test and test == single_test then
						vim.api.nvim_buf_set_extmark(bufnr, inline_testing_ns, line_num, 0, { virt_text = { text } })
						break
					else
						vim.api.nvim_buf_set_extmark(bufnr, inline_testing_ns, line_num, 0, { virt_text = { text } })
					end
				end
				line_num = line_num + 1
			end

			if jobId ~= nil then
				return
			end

			jobId = vim.fn.jobstart(cmd, {
				stdout_buffered = true,
				--nx sends output to stderr when uing the --json flag
				on_stdout = function(j, data)
					std_out_messages = data
				end,

				on_stderr = function(_, data)
					for _, result in ipairs(data) do
						result = clean_terminal_control_characters(result)
						-- If the output has the following, then the test run is complete for this iteration of the watcher
						if string.match(result, "Test results written to") then
							M.on_test_run_complete(bufnr)
						end

						-- Capture console.log and console.warn messages for display in a window
						local match_console_marker = string.match(result, "console.log")
						local match_console_warn_marker = string.match(result, "console.warn")
						if match_console_marker or match_console_warn_marker ~= nil then
							capturing_logs = true
						end

						-- if the string has has 'at' and ends with a colon, it's a stack trace
						if string.match(result, "^.* at .+:") ~= nil then
							capturing_logs = false
						end

						if capturing_logs == true and not match_console_marker then
							table.insert(console_logs, result)
						end
					end
				end,
				on_exit = function(data, code)
					-- do nothing now as we are using the --watch flag
					jobId = nil
				end,
			})
		end,
	})

	vim.notify("Jesting attached to " .. buf_name, vim.log.levels.INFO, { title = "Jesting" })
end

function M.select_menu_item()
	local line_num = vim.fn.line(".")
	print(line_num)
	vim.api.nvim_win_close(test_results_winnr, true)
	test_results_winnr = nil

	-- get the test result for the selected line
	local test_result = inline_testing_results[line_num]

	-- move the cursor to the test result
	vim.api.nvim_win_set_cursor(0, { test_result.line_num + 1, 0 })
end

function M.add_extmark_to_test_result(bufnr, test_results)
	local diagnostics_tbl = {}
	for _, result in ipairs(test_results) do
		if result.passed == true then
			local text = { "✅" }
			vim.api.nvim_buf_set_extmark(bufnr, inline_testing_ns, result.line_num, 0, { virt_text = { text } })
		else
			table.insert(diagnostics_tbl, {
				bufnr = bufnr,
				lnum = result.line_num,
				col = 0,
				end_lnum = result.line_num,
				end_col = 0,
				severity = vim.diagnostic.severity.ERROR,
				message = "Test Failed: " .. clean_terminal_control_characters(result.error_message),
			})
		end
	end
	vim.diagnostic.set(inline_testing_ns, bufnr, diagnostics_tbl, {})
end

function M.get_matching_it_statements_for_line(line)
	return string.match(line, "it%(['\"`](.*)['\"`].*%,")
end

function M.clear_namespace_for_current_buffer(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, inline_testing_ns, 0, -1)
	vim.diagnostic.reset(inline_testing_ns, bufnr)
end

function M.clear_console_log_stuff()
	console_logs = {}
	if console_log_win ~= nil then
		if vim.api.nvim_win_is_valid(console_log_win) then
			vim.api.nvim_win_close(console_log_win, true)
		end
		console_log_win = nil
	end
	if console_log_buf ~= nil then
		if vim.api.nvim_buf_is_valid(console_log_buf) then
			vim.api.nvim_buf_delete(console_log_buf, { force = true })
		end
		console_log_buf = nil
	end
end

function M.open_console_log_win()
	if #console_logs > 0 then
		local current_win = vim.api.nvim_get_current_win()
		if console_log_win == nil then
			vim.fn.execute(config.console_log_window_width .. " vnew")
			console_log_win = vim.api.nvim_get_current_win()
		end
		if console_log_buf == nil then
			console_log_buf = vim.api.nvim_get_current_buf()
			-- set buffer to be a scratch buffer
			vim.api.nvim_buf_set_option_value(console_log_buf, "buflisted", false)
		end
		vim.api.nvim_buf_set_lines(console_log_buf, 0, -1, false, console_logs)
		vim.api.nvim_win_set_buf(console_log_win, console_log_buf)

		-- set cursor back to the original window
		vim.api.nvim_set_current_win(current_win)
	end
end

function M.setup(user_config)
	-- override default config with user config
	config = vim.tbl_deep_extend("force", config, user_config)
end

--
-- After test run is complete, read in the JSON file and parse the results
--
function M.on_test_run_complete(bufnr)
	-- first check to see if we have the circular JSON serialization error
	for _, result in ipairs(std_out_messages) do
		if string.match(result, "starting at object with constructor 'Object'") then
			vim.notify(vim.inspect(std_out_messages), vim.log.levels.ERROR, { title = "Jesting" })
			return
		end
	end

	-- read in JSON file
	local file = io.open("/tmp/results.json", "r")
	if file ~= nil then
		local json = file:read("*all")
		local results = vim.fn.json_decode(json)
		file:close()

		-- get the test results
		local testResults = results.testResults[1].assertionResults

		if #results.testResults == 1 and string.match(results.testResults[1].message, "Test suite failed to run") then
			-- concat the cmd table together into a single string
			local cmd_str = ""
			-- for _, v in ipairs(cmd) do
			-- 	cmd_str = cmd_str .. v .. " "
			-- end

			vim.notify(
				"Jesting failed to run " .. cmd_str .. "\n" .. results.testResults[1].message,
				vim.log.levels.ERROR,
				{ title = "Jesting" }
			)

			M.clear_namespace_for_current_buffer(bufnr)
			return
		end

		-- -- make a map of test name to result
		local testMap = {}
		for _, result in ipairs(testResults) do
			-- table.insert(testMap, {name = result.title, status = result.status})
			testMap[result.title] = { status = result.status, error_message = result.failureMessages[1] }
		end

		-- assemble the test results in to the inline_testing_results table
		local line_num = 0
		for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
			-- get the test name from the it statement
			local test = M.get_matching_it_statements_for_line(line)
			if test ~= nil then
				local result = testMap[test]
				if result ~= nil and (result.status == "passed" or result.status == "failed") then
					table.insert(inline_testing_results, {
						name = test,
						line_num = line_num,
						passed = result.status == "passed",
						error_message = result.error_message,
					})
				end
			end
			line_num = line_num + 1
		end

		local any_failures = false
		for _, result in ipairs(inline_testing_results) do
			if not result.passed then
				any_failures = true
				break
			end
		end

		if any_failures then
			M.buf_to_status_map[bufnr] = STATUS_MAP["FAILED"]
		else
			M.buf_to_status_map[bufnr] = STATUS_MAP["PASSED"]
		end

		M.open_console_log_win()
		M.clear_namespace_for_current_buffer(bufnr)
		M.add_extmark_to_test_result(bufnr, inline_testing_results)
	end
end
return M

-- function M.create_popup_of_test_results(test_result)
-- 	-- creat a new buffer
-- 	local bufnr = vim.api.nvim_create_buf(false, true)
--
-- 	-- assemble list of test results
-- 	local lines = {}
-- 	for _, result in ipairs(test_result) do
-- 		local text = result.passed and "✅" or "❌"
-- 		table.insert(lines, text .. " " .. result.name)
-- 	end
--
-- 	-- add a line of text
-- 	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
--
-- 	local width = 125
-- 	local height = 25
-- 	local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
-- 	-- open a window in the center of the screen
-- 	test_results_winnr, win = popup.create(bufnr, {
-- 		title = "Test Results",
-- 		line = math.floor(((vim.o.lines - height) / 2) - 1),
-- 		col = math.floor((vim.o.columns - width) / 2),
-- 		minwidth = width,
-- 		minheight = height,
-- 		borderchars = borderchars,
-- 	})
--
-- 	vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "<Cmd>lua require('jr.custom.commands').select_menu_item()<CR>", {})
-- end
