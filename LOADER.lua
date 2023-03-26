local ROOTPATH = "WirusHub"
local APPENDATION_PACKAGE = "\\package.json"
local APPENDATION_INDEX = "\\index.lua"

local HttpService = cloneref(game:GetService("HttpService"))
local JSONDecode = HttpService.JSONDecode

if shared.WirusHub then
	error("Wirus Hub is already loaded.")
end

if isfile(ROOTPATH) then
	error("Root directory occupied by a file. Wirus Hub cannot continue.")
end
if not isfolder(ROOTPATH) then
	makefolder(ROOTPATH)
end

local packages = {}

local packageCount = 0

local checkVal = function(value, ...)
	local valType = typeof(value)
	local types = {...}
	for i = 1, #types do
		if valType == types[i] then
			return false
		end
	end
	return true
end

--PARSE AND SANITIZE FILESYSTEM
for _, packagePath in listfiles(ROOTPATH) do
	if isfolder(packagePath) then
		local jsonPath = packagePath .. APPENDATION_PACKAGE
		if isfile(jsonPath) then
			local indexPath = packagePath .. APPENDATION_INDEX
			if isfile(indexPath) then
				local validJson, packageData = pcall(JSONDecode, HttpService, readfile(jsonPath))
				local packageFunction = loadfile(indexPath)
				if validJson and packageFunction then
					local packageName = packageData.PackageName
					local author = packageData.Author
					local dependencies = packageData.Dependencies
					local gamesWhitelist = packageData.GameIdWhitelist
					local gamesBlacklist = packageData.GameIdBlacklist
					local placesWhitelist = packageData.PlaceIdWhitelist
					local placesBlacklist = packageData.PlaceIdBlacklist
					local commandList = packageData.Commands
					local keybindList = packageData.Keybinds
					
					if typeof(packageName) ~= "string" then
						warn("Invalid package at " .. packagePath .. ": invalid package name.")
						continue
					end

					do
						local foundPackage = packages[packageName]
						if foundPackage then
							local foundPath = foundPackage.Path
							error("Two packages use the same name (" .. packageName .. "). Wirus Hub cannot continue:\n" .. foundPath .. "\n" .. packagePath)
						end
					end
					
					if checkVal(author, "string", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid author.")
						continue
					end
					if checkVal(dependencies, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid dependency list.")
						continue
					end
					if checkVal(gamesWhitelist, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid game whitelist.")
						continue
					end
					if checkVal(gamesBlacklist, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid game blacklist.")
						continue
					end
					if checkVal(placesWhitelist, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid place whitelist.")
						continue
					end
					if checkVal(placesBlacklist, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid place blacklist.")
						continue
					end
					if checkVal(commandList, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid command list.")
						continue
					end
					if checkVal(keybindList, "table", "nil") then
						warn("Invalid package at " .. packagePath .. ": invalid command list.")
						continue
					end
					
					packages[packageName] = {
						Name = packageName,
						Author = author,
						Dependencies = dependencies,
						GameIdWhitelist = gamesWhitelist,
						GameIdBlacklist = gamesBlacklist,
						PlaceIdWhitelist = placesWhitelist,
						PlaceIdBlacklist = placesBlacklist,
						Commands = commandList,
						Keybinds = keybindList,
						Path = packagePath,
						Loaded = false,
						Index = packageFunction
					}
					packageCount += 1
				else
					if not validJson then
						warn("Invalid package at " .. packagePath .. ": invalid package.json.")
					end
					if not packageFunction then
						warn("Invalid package at " .. packagePath .. ": invalid index.lua.")
					end
				end
			else
				warn("Invalid package at " .. packagePath .. ": index.lua not found.")
			end
		else
			warn("Invalid package at " .. packagePath .. ": package.json not found.")
		end
	end
end

local module = {_packages = packages}
shared.WirusHub = module

local getFilesInPath
getFilesInPath = function(path)
	local files = {}
	local fileList = listfiles(path)
	for i = 1, #fileList do
		local filePath = fileList[i]
		if isfile(filePath) then
			table.insert(files, filePath)
		else
			local foundFiles = getFilesInPath(filePath)
			for i2 = 1, #foundFiles do
				table.insert(files, foundFiles[i2])
			end
		end
	end
	return files
end

local crypt = syn.crypt
local base64 = crypt.base64
local base64encode = base64.encode
local base64decode = base64.decode

local compress = function(...) return ... end --zstd isn't in v3 yet
local decompress = compress

module.getFilesInPath = getFilesInPath

local DELIMITER = " "
module._encodeModule = function(path, folderName)
	local lastChar = string.sub(path, -1, -1)
	if lastChar ~= "/" and lastChar ~= "\\" then
		path ..= "\\"
	end
	local pathLen = #path + 1
	local data = base64encode(folderName) .. DELIMITER
	local fileList = getFilesInPath(path)
	for i = 1, #fileList do
		local filePath = fileList[i]
		local fileName = string.sub(filePath, pathLen, -1) --"package.json"
		local fileData = readfile(filePath)
		data ..= base64encode(fileName) .. DELIMITER .. base64encode(fileData) .. DELIMITER
	end
	return compress(string.sub(data, 1, -2))
end

module._installModule = function(whp)
	local raw = string.split(decompress(whp), DELIMITER)
	local folderName = base64decode(table.remove(raw, 1))
	if messagebox("Would you like to install the package \"" .. folderName .. "\"? Only install packages from sources you trust.", "Wirus Hub", 4) == 6 then
		local packagePath = ROOTPATH .. "\\" .. folderName
		if isfile(packagePath) then
			error("[Wirus Hub] Failed to install package \"" .. folderName .. "\". " .. packagePath .. " already exists as a file.")
		elseif not isfolder(packagePath) then
			makefolder(packagePath)
		end
		local nextFileName
		for i = 1, #raw do
			local data = base64decode(raw[i])
			if i % 2 == 0 then
				local nextFilePath = packagePath .. "\\" .. nextFileName
				local split = string.split(nextFileName, "\\")
				local splitLen = #split
				local currentPath = packagePath
				print(splitLen)
				for i2 = 1, splitLen do
					currentPath ..= "\\" .. split[i2]
					if i2 == splitLen then
						if isfolder(currentPath) then
							error("[Wirus Hub] Failed to install package \"" .. folderName .. "\". " .. currentPath .. " already exists as a folder.")
						end
						writefile(currentPath, data)
					else
						warn("how did i get here")
						if isfile(currentPath) then
							error("[Wirus Hub] Failed to install package \"" .. folderName .. "\". " .. currentPath .. " already exists as a file.")
						end
						if not isfolder(currentPath) then
							makefolder(currentPath)
						end
					end
				end
			else
				nextFileName = data
			end
		end
	end
end

local loadedCount = 0
local cycles = 1
while true do
	local shouldBreak = true
	for packageName, package in packages do
		if not package.Loaded then
			local dependencies = package.Dependencies
			local shouldLoad = true
			if dependencies then
				for i = 1, #dependencies do
					local depName = dependencies[i]
					local requiredDependency = true
					if string.sub(depName, -1, -1) == "?" then
						requiredDependency = false
						depName = string.sub(depName, 1, -2)
					end
					local foundPackage = packages[depName]
					if foundPackage then
						local foundLoaded = foundPackage.Loaded
						if not foundLoaded then
							if cycles == 1 then
								local foundDeps = foundPackage.Dependencies
								if foundDeps then
									for i2 = 1, #foundDeps do
										local foundDepName = foundDeps[i2]
										local requiredFoundDependency = true
										if string.sub(foundDepName, -1, -1) == "?" then
											requiredFoundDependency = false
											foundDepName = string.sub(foundDepName, 1, -2)
										end
										if requiredFoundDependency and foundDepName == packageName then
											warn(packageName .. " cannot continue. Recursively depended on by " .. foundDepName)
											warn(foundDepName .. " cannot continue. Recursively depended on by " .. packageName)
											packages[packageName] = nil
											packages[foundDepName] = nil
										end
									end
								end
							end
							shouldBreak = false
							shouldLoad = false
						end
					elseif requiredDependency then
						warn(packageName .. " cannot continue. Missing dependency " .. depName .. ".")
						packages[packageName] = nil
						shouldLoad = false
					end
				end
			else
				shouldLoad = true
			end
			if shouldLoad then
				local packageFunction = package.Index
				
				local loaded, returned = pcall(packageFunction, package)
				if loaded then
					package.Loaded = true
					module[packageName] = returned
					loadedCount += 1
				else
					warn(packageName .. " cannot continue. Error: " .. returned)
					packages[packageName] = nil
				end
			end
		end
	end
	if shouldBreak then
		break
	else
		cycles += 1
	end
end

print(string.format("Finished loading Wirus Hub. (%s packages, %s cycle%s, %s failed)", loadedCount, cycles, if cycles == 1 then "" else "s", packageCount - loadedCount))
