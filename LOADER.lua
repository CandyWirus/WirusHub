local REPO_OWNER = "CandyWirus"
local REPO_NAME = "WirusHubPackages"

local API_URL = `https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents`
local INCLUDED_PUBLIC_KEY = "eA5stSpBSqY/aliJnsYz8EJnc2pMorU+oU/NyhhK7Vk="

local ROOTPATH = "WirusHub"
local PACKAGESPATH = `{ROOTPATH}\\Packages`
local APPENDATION_PACKAGE = "\\package.json"
local APPENDATION_INDEX = "\\index.lua"

local HttpService = cloneref(game:GetService("HttpService"))
local JSONDecode = HttpService.JSONDecode
local toast_notification = syn.toast_notification

if shared.WirusHub then
	error("Wirus Hub is already loaded.")
end

if isfile(ROOTPATH) then
	error("Root directory occupied by a file. Wirus Hub cannot continue.")
end
if not isfolder(ROOTPATH) then
	makefolder(ROOTPATH)
end

if isfile(PACKAGESPATH) then
	error("Package directory occupied by a file. Wirus Hub cannot continue.")
end
if not isfolder(PACKAGESPATH) then
	makefolder(PACKAGESPATH)
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

local module = {_packages = packages}

--PACKAGE INSTALLER
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
local zstd = crypt.zstd
local sign = crypt.sign
local base64encode = base64.encode
local base64decode = base64.decode
local compress = zstd.compress
local decompress = zstd.decompress
local encrypt = sign.create
local decrypt = sign.open

INCLUDED_PUBLIC_KEY = base64decode(INCLUDED_PUBLIC_KEY)

module.getFilesInPath = getFilesInPath

local DELIMITER = " "

module._encodeModule = function(path, privateKey, newDownloadUrl)
	path = string.gsub(path, "/", "\\")
	local lastChar = string.sub(path, -1, -1)
	if lastChar ~= "\\" then
		path ..= "\\"
	end
	local pathLen = #path + 1
	local packageDefinitionPath = path .. "package.json"
	if isfile(packageDefinitionPath) then
		local json = readfile(packageDefinitionPath)
		local jsonBase64 = base64encode(json)
		local valid, packageDefinition = pcall(JSONDecode, HttpService, json)
		if valid then
			local packageName = packageDefinition.PackageName
			if typeof(packageName) ~= "string" or string.match(packageName, "[\\/:%*%?\"<>|]") then
				error(`Could not encode package: invalid PackageName.`)
			end
			local encryptedData = jsonBase64 .. DELIMITER
			local fileList = getFilesInPath(path)
			for i = 1, #fileList do
				local filePath = fileList[i]
				if filePath ~= packageDefinitionPath then
					local fileName = string.sub(filePath, pathLen, -1) --"package.json"
					local fileData = readfile(filePath)
					encryptedData ..= base64encode(fileName) .. DELIMITER .. base64encode(fileData) .. DELIMITER
				end
			end
			local packageVersion = packageDefinition.Version
			local updateData = base64encode(packageVersion)
			if newDownloadUrl then
				updateData ..= DELIMITER .. encrypt(newDownloadUrl, privateKey)
			end
			return compress(jsonBase64 .. DELIMITER ..  encrypt(encryptedData, privateKey)), compress(updateData)
		else
			error(`Invalid package at {path}: Invalid package.json.`)
		end
	elseif isfolder(packageDefinitionPath) then
		error(`Invalid package at {path}: package.json already exists as a folder.`)
	else
		error(`Invalid package at {path}: package.json not found.`)
	end
end

local installModule = function(whp, publicKey, noprompt)
	local decompressed = decompress(whp)
	local split = string.split(decompressed, DELIMITER)
	local encodedJson = table.remove(split, 1)
	local validSignature, fileData = pcall(decrypt, table.concat(split, DELIMITER), publicKey)
	if validSignature then
		fileData = string.split(fileData, DELIMITER)
		local validB64, json = pcall(base64decode, encodedJson)
		if validB64 then
			local validJson, packageDefinition = pcall(JSONDecode, HttpService, json)
			if validJson then
				local packageName = packageDefinition.PackageName
				local packageVersion = packageDefinition.Version
				if typeof(packageName) ~= "string" or string.match(packageName, "[\\/:%*%?\"<>|]") then
					error("[Wirus Hub] Could not install package: invalid package definition. (invalid name)")
				end
				if typeof(packageVersion) ~= "string" then
					error("[Wirus Hub] Could not install package: invalid package definition. (invalid version)")
				end
				local packagePath = PACKAGESPATH .. "\\" .. packageName
				if isfile(packagePath) then
					error(`[Wirus Hub] Failed to install package "{packageName}". {packagePath} already exists as a file.`)
				elseif isfolder(packagePath) then
					local installedVersion = "undefined"
					local installedPackageDefinitionPath = packagePath .. APPENDATION_PACKAGE
					if isfile(installedPackageDefinitionPath) then
						local raw = readfile(installedPackageDefinitionPath)
						local installedValidJson, installedPackageDefinition = pcall(JSONDecode, HttpService, raw)
						if installedValidJson then
							local definedVersion = installedPackageDefinition.Version
							if typeof(definedVersion) == "string" then
								installedVersion = definedVersion
							end
						else
							installedVersion = "invalid_invalid_definition"
						end
					else
						installedVersion = "invalid_no_definition"
					end
					Drawing:WaitForRenderer()
					if noprompt or messagebox(`Would you like to overwrite your installation of "{packageName}"?\nInstalled version: {installedVersion}\nNew version: {packageVersion}`, "Wirus Hub", 4) == 6 then
						delfolder(packagePath)
						noprompt = true
					else
						return
					end
				end
				Drawing:WaitForRenderer()
				if noprompt or messagebox(`Would you like to install the package "{packageName}"? Only install packages from sources you trust. Malicious packages are not sandboxed in any way.`, "Wirus Hub", 4) == 6 then
					makefolder(packagePath)
					local usedFileNames = {}
					local nextFileName = "package.json"
					for i = 1, #fileData do
						local data = base64decode(fileData[i])
						if i % 2 == 1 then
							if i == 1 then --package.json will always be the first file in the list
								if json ~= data then
									delfolder(packagePath)
									error(`[Wirus Hub] Aborted installation of "{packageName}". Installation file has been tampered with. [1]`)
								end
							else
								if table.find(usedFileNames, nextFileName) then
									delfolder(packagePath)
									error(`[Wirus Hub] Aborted installation of "{packageName}". Installation file has been tampered with. [2]`)
								end
								table.insert(usedFileNames, nextFileName)
							end
							local split = string.split(nextFileName, "\\")
							local splitLen = #split
							local currentPath = packagePath
							for i2 = 1, splitLen do
								currentPath ..= "\\" .. split[i2]
								if i2 == splitLen then
									if isfolder(currentPath) then
										delfolder(packagePath)
										error(`[Wirus Hub] Failed to install package "{packageName}. {currentPath} already exists as a folder.`)
									end
									writefile(currentPath, data)
								else
									if isfile(currentPath) then
										delfolder(packagePath)
										error(`[Wirus Hub] Failed to install package "{packageName}". {currentPath} already exists as a file.`)
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
					print(`[Wirus Hub] Successfully installed package "{packageName}"`)
					return packageVersion
				end
			else
				error("[Wirus Hub] Could not install package: invalid WHP. (json)")
			end
		else
			error("[Wirus Hub] Could not install package: invalid WHP. (base64)")
		end
	else
		error("[Wirus Hub] Could not install package: invalid signature.")
	end
end

module._installModule = function(whp, publicKey)
	return installModule(whp, publicKey)
end

local getUpdateForPackage = function(package)
	local publicKey = package.PublicKey
	if publicKey then
		local downloadUrl = package.DownloadUrl or false
		local updateUrl = package.UpdateUrl
		if updateUrl then
			local response = syn.request({
				Url = updateUrl
			})
			if response.Success then
				local whu = response.Body
				local decompressed = decompress(whu)
				local split = string.split(decompressed, DELIMITER)
				local validBase64, latestVersion = pcall(base64decode, table.remove(split, 1))
				if validBase64 then
					local installedVersion = package.Version
					if installedVersion and latestVersion <= installedVersion then
						return false
					end
					local signedDownloadUrl = table.concat(split, DELIMITER)
					if #signedDownloadUrl > 0 then
						local validDownloadUrl, newDownloadUrl = pcall(decrypt, signedDownloadUrl, publicKey)
						if validDownloadUrl then
							return newDownloadUrl
						else
							warn("Invalid WHU: corrupted download url")
							return downloadUrl
						end
					end
				else
					warn("Invalid WHU: version string invalid")
					return downloadUrl
				end
			else
				warn("Could not fetch WHU for package: " .. response.StatusMessage)
				return false
			end
		end
		return downloadUrl
	end
	return false
end

local updatePackage = function(package, force)
	local updateUrl = force or getUpdateForPackage(package)
	if updateUrl then
		local response = syn.request({
			Url = updateUrl
		})
		if response.Success then
			local whp = response.Body
			local publicKey = package.PublicKey
			return installModule(whp, publicKey, true)
		else
			warn(`Could not fetch WHP for package {package.Name}: {response.StatusMessage}`)
			return false
		end
	end
	return false
end
module._updatePackage = updatePackage

if #listfiles(PACKAGESPATH) == 0 then
	Drawing:WaitForRenderer()
	if messagebox(`You have no packages installed. Wirus Hub has no functionality without packages. Would you like to download the default packages from {REPO_OWNER}/{REPO_NAME}?`, "Wirus Hub", 4) == 6 then
		local response = syn.request({
			Url = API_URL
		})
		local body = response.Body
		if response.StatusCode == 200 then
			local data = HttpService:JSONDecode(body)
			for i = 1, #data do
				local asset = data[i]
				if string.sub(asset.name, -4, -1) == ".whp" then
					local url = asset.download_url
					local response2 = syn.request({
						Url = url
					})
					local whp = response2.Body
					if response2.StatusCode == 200 then
						task.spawn(installModule, whp, INCLUDED_PUBLIC_KEY, true)
					else
						error(`GitHub threw HTTP status "{response2.StatusMessage}". Body: {whp}`)
					end
				end
			end
		else
			error(`GitHub threw HTTP status "{response.StatusMessage}". Body: {body}`)
		end
	end
end

local Global_PlaceId = game.PlaceId
if Global_PlaceId == 0 then
    game:GetPropertyChangedSignal("PlaceId"):Wait()
    Global_PlaceId = game.PlaceId
end
local Global_GameId = game.GameId
if Global_GameId == 0 then
    game:GetPropertyChangedSignal("GameId"):Wait()
    Global_GameId = game.GameId
end

--PARSE AND SANITIZE FILESYSTEM
local usedPaths = {}
while true do
	local shouldBreak = true
	for _, packagePath in listfiles(PACKAGESPATH) do
		if not table.find(usedPaths, packagePath) then
			table.insert(usedPaths, packagePath)
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
							local packageVersion = packageData.Version
							local packagePublicKey = packageData.PublicKey
							local updateUrl = packageData.UpdateUrl
							local downloadUrl = packageData.DownloadUrl

							if typeof(packageName) ~= "string" then
								warn(`Invalid package at {packagePath}: invalid package name.`)
								continue
							end

							do
								local foundPackage = packages[packageName]
								if foundPackage then
									local foundPath = foundPackage.Path
									error(`Two packages use the same name ({packageName}). Wirus Hub cannot continue:\n{foundPath}\n{packagePath}`)
								end
							end

							if checkVal(author, "string", "nil") then
								warn(`Invalid package at {packagePath}: invalid author.`)
								continue
							end
							if checkVal(dependencies, "table", "nil") then
								warn(`Invalid package at {packagePath}: invalid dependency list.`)
								continue
							end
							if checkVal(commandList, "table", "nil") then
								warn(`Invalid package at {packagePath}: invalid command list.`)
								continue
							end
							if checkVal(keybindList, "table", "nil") then
								warn(`Invalid package at {packagePath}: invalid keybind list.`)
								continue
							end
							if checkVal(packageVersion, "string", "nil") then
								warn(`Invalid package at {packagePath}: invalid version.`)
								continue
							end

							if typeof(gamesWhitelist) == "table" then
								local invalid = true
								for i = 1, #gamesWhitelist do
									if gamesWhitelist[i] == Global_GameId then
										invalid = false
										break
									end
								end
								if invalid then
									continue
								end
							elseif gamesWhitelist ~= nil then
								warn(`Invalid package at {packagePath}: invalid game whitelist.`)
								continue
							end

							if typeof(gamesBlacklist) == "table" then
								local invalid = false
								for i = 1, #gamesBlacklist do
									if gamesBlacklist[i] == Global_PlaceId then
										invalid = true
									end
								end
								if invalid then
									continue
								end
							elseif gamesBlacklist ~= nil then
								warn(`Invalid package at {packagePath}: invalid game blacklist.`)
								continue
							end

							if typeof(placesWhitelist) == "table" then
								local invalid = true
								for i = 1, #placesWhitelist do
									if placesWhitelist[i] == Global_PlaceId then
										invalid = false
										break
									end
								end
								if invalid then
									continue
								end
							elseif placesWhitelist ~= nil then
								warn(`Invalid package at {packagePath}: invalid place whitelist.`)
								continue
							end

							if typeof(placesBlacklist) == "table" then
								local invalid = false
								for i = 1, #placesBlacklist do
									if placesBlacklist[i] == Global_PlaceId then
										invalid = true
									end
								end
								if invalid then
									continue
								end
							elseif placesBlacklist ~= nil then
								warn(`Invalid package at {packagePath}: invalid place blacklist.`)
								continue
							end

							do
								local valType = typeof(packagePublicKey)
								if valType == "string" then
									local validB64
									validB64, packagePublicKey = pcall(base64decode, packagePublicKey)
									if not (validB64 and #packagePublicKey == 32) then
										warn(`Invalid package at {packagePath}: invalid public key.`)
										continue
									end
								elseif valType ~= "nil" then
									warn(`Invalid package at {packagePath}: public key is not a string.`)
									continue
								end
							end

							if checkVal(updateUrl, "string", "nil") then
								warn(`Invalid package at {packagePath}: invalid update URL.`)
								continue
							end
							if checkVal(downloadUrl, "string", "nil") then
								warn(`Invalid package at {packagePath}: invalid update download URL.`)
								continue
							end

							local package = {
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
								Index = packageFunction,
								Version = packageVersion,
								PublicKey = packagePublicKey,
								UpdateUrl = updateUrl,
								DownloadUrl = downloadUrl
							}
							local ver = updatePackage(package)
							if ver then
								toast_notification({
									Type = 1,
									Title = "Wirus Hub",
									Content = `{packageName} has been updated to version {ver}`
								})
								print(`[Wirus Hub] Updated {packageName} to version {ver}`)
								shouldBreak = false
								table.remove(usedPaths, #usedPaths)
								continue
							end
							packages[packageName] = package
							packageCount += 1
						else
							if not validJson then
								warn(`Invalid package at {packagePath}: invalid package.json.`)
							end
							if not packageFunction then
								warn(`Invalid package at {packagePath}: invalid index.lua.`)
							end
						end
					else
						warn(`Invalid package at {packagePath}: index.lua not found.`)
					end
				else
					warn(`Invalid package at {packagePath}: package.json not found.`)
				end
			end
		end
	end
	if shouldBreak then
		break
	end
end

shared.WirusHub = module

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
											warn(`{packageName} cannot continue. Recursively depended on by {foundDepName}`)
											warn(`{foundDepName} cannot continue. Recursively depended on by {packageName}`)
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
						warn(`{packageName} cannot continue. Missing dependency {depName}.`)
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
					if returned then
						package.Loaded = true
						module[packageName] = returned
						loadedCount += 1
					else
						packages[packageName] = nil
						packageCount -= 1
					end
				else
					warn(`{packageName} cannot continue. Error: {returned}`)
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
