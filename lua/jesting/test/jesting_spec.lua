local eq = assert.are.same
local jesting = require("jesting")
local utils = require("jesting.test.utils")

describe("Jesting", function()
	before_each(function()
		jesting = require("jesting")
	end)
	it("should attach to a buffer and update the global status map for lualine", function()
		local bufnr = utils.create_file("/tmp/jesting-test", { "hello world" })
		local mockJestingCommand = {
			"nx",
			"command",
			"--thing",
		}

		jesting.attach(mockJestingCommand)

		local status = jesting.lualine_status()
		eq("🔗", status)
	end)
	it("full happy-path test", function()
		-- local uri = vim.uri_from_fname("lua/jesting/test/fixtures/simple-jest-spec.js")
		-- get current working directory
		local cwd = vim.fn.getcwd()
		local file = cwd .. "/lua/jesting/test/fixtures/simple-jest.spec.js"
		local uri = vim.uri_from_fname(file)
		local bufnr = vim.uri_to_bufnr(uri)
		vim.api.nvim_win_set_buf(0, bufnr)
		vim.fn.execute("edit")

		-- utils.dump_buffer(bufnr)
		-- local mockJestingCommand = {
		--   "nx",
		--   "command",
		--   "--thing",
		-- }
		--
		-- jesting.attach(mockJestingCommand)
		--
		-- local status = jesting.lualine_status()
		-- eq("🔗", status)
	end)
end)
