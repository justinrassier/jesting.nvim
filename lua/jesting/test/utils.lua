local M = {}

M.created_files = {}

function M.create_file(name, contents, row, col)
	local bufnr = vim.fn.bufnr(name, true)
	vim.api.nvim_set_option_value("bufhidden", "hide", {
		buf = bufnr,
	})
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, contents)
	if row then
		vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })
	end

	table.insert(M.created_files, bufnr)
	return bufnr
end

function M.dump_buffer(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for _, line in ipairs(lines) do
		print(line)
	end
end

return M
