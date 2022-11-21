local path = require("plenary.path")
local scan = require("plenary.scandir")
local M = {}

local function find_nearest_project_json(starting_dir)
	local current_dir = path:new(starting_dir)
	local scan_result
	local count = 1
	-- keep going up directories until you find a `.project.json` (or stop at 10 as then something went wrong)
	repeat
		current_dir = current_dir:parent()
		scan_result = scan.scan_dir(current_dir:normalize(), { search_pattern = ".project.json" })
		count = count + 1
	until #scan_result > 0 or count >= 10

	return scan_result[1]
end

-- given a path, find the project name by first finding the directory of the nearest project.json file
-- then using the root angular.json to match the project name to the directory
function M.get_project_name_from_path(current_path)
	local nearest_project_json_directory = find_nearest_project_json(current_path)
	if nearest_project_json_directory == nil then
		print("No project.json found!")
		return
	end
	local project_directory = path:new(nearest_project_json_directory):parent()
	project_directory = path:new(project_directory):make_relative()

	-- read in angular.json file
	local angular_json = vim.fn.json_decode(vim.fn.readfile("angular.json"))

	-- get the project name from the project_directory
	local project_name = nil
	for key, value in pairs(angular_json.projects) do
		if value == project_directory then
			project_name = key
		end
	end

	if project_name == nil then
		print("No project found!")
		return
	end

	return project_name
end

return M
