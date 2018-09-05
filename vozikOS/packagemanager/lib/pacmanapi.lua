local component = require("component")
local serial = require("serialization")
local process = require("process")
local fs = require("filesystem")
local shell = require("shell")
local unicode = require("unicode")

local pacmanApi = {}

local internet
local wget
local gitHubBaseAddress = "https://raw.githubusercontent.com/"
local gitHubApiAddress = "https://api.github.com/repos/"
local installedPackagesFileName = "installed.svd"

local function isEmpty(table)
  if next(table) == nil then
    return true;
  end

  return false;
end

local function getInternet()
  if not component.isAvailable("internet") then
    error("This program requires an internet card to run.")
  end

  internet = require("internet")
  wget = loadfile("/bin/wget.lua")
end

local function getFileContent(url)
  local content = ""
  local result, response = pcall(internet.request, url)

  if not result or not response then
    error(string.format("File %s can not be downloaded: %s", url, response))
  end

  for chunk in response do
    content = content .. chunk
  end

  return content
end

local function getPacmanConfig()
  local pacmanConfigUrl = gitHubBaseAddress .. "Vozik283/vozikOS/master/vozikOS/packagemanager/etc/pacman.cfg"
  local content = getFileContent(pacmanConfigUrl)

  if not content then
    error(string.format("Config file %s is empty.", pacmanConfigUrl))
  end

  local pacmanConfig = serial.unserialize(content)

  return pacmanConfig
end

local function getRepositories(pacmanConfig)
  return pacmanConfig.repos
end

local function readDataFile(datafolderPath, fileName)
  local dataFilePath = fs.concat(datafolderPath, fileName)

  if fs.exists(dataFilePath) then
    local file, reason = io.open(dataFilePath, "rb")

    if not file then
      error("Error while trying to read file " .. dataFilePath .. ": " .. reason)
    end

    local content = file:read("*a")
    file:close()

    if not content then
      error("Error while trying to read file " .. dataFilePath .. ": " .. reason)
    end

    return serial.unserialize(content)
  else
    return {}
  end
end

local function getPackages(repos, filter, datafolderPath, installed, notInstalled, obsolate)
  local packages = {}
  local installedPackages = readDataFile(datafolderPath, installedPackagesFileName)

  for repoFolder, repo in pairs(repos) do
    for packageName, package in pairs(repo) do
      if not filter or string.find(packageName, filter) then
        local installedPackage = installedPackages[packageName]
        package.repo = repoFolder

        if installedPackage and installedPackage.version ~= package.version then
          package.status = "Obsolate"

          if obsolate then
            packages[packageName] = package
          end
        elseif installedPackage then
          package.status = "Installed"

          if installed then
            packages[packageName] = package
          end
        else
          package.status = "Not Installed"

          if notInstalled then
            packages[packageName] = package
          end
        end
      end
    end
  end

  return packages
end

local function getFileName(path)
  local fileName = string.gsub(path, ".+/(.-)$", "%1")
  return fileName
end

local function getFolderPath(notValidatePath, defaultInstallPath)
  if string.find(notValidatePath, "//") == 1 then
    return string.sub(notValidatePath, 2)
  else
    if defaultInstallPath then
      return fs.concat(defaultInstallPath, notValidatePath)
    else
      return fs.concat(shell.getWorkingDirectory(), notValidatePath)
    end
  end
end

local function getFileFlags(file)
  if string.find(file, "?") == 1 then
    return string.sub(file, 2), true, false
  elseif string.find(file, ":") == 1 then
    return string.sub(file, 2), false, true
  else
    return file, false, false
  end
end

local function checkTargetFolder(folderPath)
  if not fs.exists(folderPath) then
    print(string.format("Folder %s is created.", folderPath))
    fs.makeDirectory(folderPath)
  end
end

local function fileDownloadInternal(serverFilePath, localFilePath, installedFile)
  print(string.format("Download %s starting...", serverFilePath))
  local result, response, reason = pcall(wget, "-qf", serverFilePath, localFilePath)

  if not result or not response then
    error(string.format("File %s can not be downloaded: %s", serverFilePath, reason))
  end

  table.insert(installedFile, localFilePath)
  print(string.format("File %s is downloaded.", localFilePath))
end

local function fileDownload(serverFilePath, localFolderPath, fileName, skipIfExist, forceInstall, fullForceInstall, installedFile)
  local localFilePath = fs.concat(localFolderPath, fileName)
  checkTargetFolder(localFolderPath)

  if fullForceInstall then
    fileDownloadInternal(serverFilePath, localFilePath, installedFile)
  elseif forceInstall then
    if skipIfExist and fs.exists(localFilePath) then
      table.insert(installedFile, localFilePath)
      print(string.format("File %s already exists, download is skipped.", localFilePath))
    else
      fileDownloadInternal(serverFilePath, localFilePath, installedFile)
    end
  else
    if fs.exists(localFilePath) then
      if skipIfExist then
        table.insert(installedFile, localFilePath)
        print(string.format("File %s already exists, download is skipped.", localFilePath))
      else
        error(string.format("File %s already exists and option -f is not enabled.", localFilePath))
      end
    else
      fileDownloadInternal(serverFilePath, localFilePath, installedFile)
    end
  end
end

local function folderDownload(serverFolderPath, localFolderPath, repositories, skipIfExist, forceInstall, fullForceInstall, fileRepoUrl, installedFile)
  local branch = string.gsub(serverFolderPath, "^(.-)/.+$", "%1")
  local folderPath = string.gsub(serverFolderPath, "^.-/(.-)/?$", "%1")
  local folderURL = gitHubApiAddress .. repositories .. "/contents/" .. folderPath .. "?ref=" .. branch

  local folder = getFileContent(folderURL)

  if not folder then
    error(string.format("File %s is empty.", folderURL))
  elseif folder:find('"message": "Not Found"') then
    error(string.format("Folder %s does not exist.", folderURL))
  end

  local folderContents = serial.unserialize(folder:gsub("%[", "{"):gsub("%]", "}"):gsub("(\"[^%s,]-\")%s?:", "[%1] = "), nil)

  for _, content in pairs(folderContents) do
    if content.type == "file" then
      local fileURL = fileRepoUrl .. branch .. "/" .. content.path

      fileDownload(fileURL, localFolderPath, content.name, skipIfExist, forceInstall, fullForceInstall, installedFile)
    elseif content.type == "dir" then
      local innerServerFolderPath = serverFolderPath .. content.name .. "/"
      local innerLocalFolderPath = fs.concat(localFolderPath,  content.name)

      checkTargetFolder(innerLocalFolderPath)
      folderDownload(innerServerFolderPath, innerLocalFolderPath, repositories, skipIfExist, forceInstall, fullForceInstall, fileRepoUrl, installedFile)
    end
  end
end

local function saveDataFile(datafolderPath, fileName, content)
  local dataFilePath = fs.concat(datafolderPath, fileName)
  checkTargetFolder(datafolderPath)

  local file, reason = io.open(dataFilePath, "wb")
  if not file then
    error("Error while trying to save file " .. dataFilePath .. ": " .. reason)
  end

  file:write(serial.serialize(content))
  file:close()
end

function pacmanApi.listPackages(filter, installed, notInstalled, obsolate)
  checkArg(1, filter, "string", "nil")
  checkArg(2, installed, "boolean", "nil")
  checkArg(3, notInstalled, "boolean", "nil")
  checkArg(4, obsolate, "boolean", "nil")

  if not installed and not notInstalled and not obsolate then
    installed, notInstalled, obsolate = true, true, true
  end

  getInternet()

  local result, pacmanConfig = pcall(getPacmanConfig)
  if not result or not pacmanConfig then
    error("Could not download the pacman config file. Please ensure you have an Internet connection: " .. pacmanConfig)
  end

  local repositories = getRepositories(pacmanConfig)
  local defaultInstallPath = getFolderPath(pacmanConfig.defaultInstallPath)
  local dataPath = getFolderPath(pacmanConfig.dataPath, defaultInstallPath)

  return getPackages(repositories, filter, dataPath, installed, notInstalled, obsolate), defaultInstallPath, dataPath
end

local function installInternal(packageName, forceInstall, fullForceInstall, update)
  local packages, defaultInstallPath, datafolderPath = pacmanApi.listPackages(packageName)
  local package = packages[packageName]

  if not package then
    error(string.format("Unknown package [%s]. Please ensure the package name is correct.", packageName))
  elseif update then
    if package.status == "Installed" then
      error(string.format("Package [%s] is already installed in last version.", packageName))
    elseif package.status == "Not Installed" then
      error(string.format("Package [%s] is not installed.", packageName))
    end
  elseif not fullForceInstall and not forceInstall and package.status ~= "Not Installed" then
    error(string.format("Package [%s] is already installed.", packageName))
  end

  local installedPackages = readDataFile(datafolderPath, installedPackagesFileName)

  if package.dependencies and not isEmpty(package.dependencies) then
    print(string.format("Package [%s] has dependencies - Checking if all dependencies are installed...", packageName))

    for _, dependence in pairs(package.dependencies) do
      if not installedPackages[dependence] then
        print(string.format("Package [%s] is not installed.", dependence))
        pacmanApi.install(packageName, forceInstall, fullForceInstall)
      elseif update and installedPackages[dependence].status == "Obsolate" then
        print(string.format("Package [%s] is obsolate.", dependence))
        pacmanApi.update(packageName)
      end
    end

    print("All Dependencies installed.")
  end

  local installedFile = {}

  for sPathNotValidate, lPathNotValidate in pairs(package.files) do
    local serverPath, skipIfExist, moveDir = getFileFlags(sPathNotValidate)
    local localFolderPath = getFolderPath(lPathNotValidate, defaultInstallPath)
    local fileName = getFileName(serverPath)
    local fileURL = gitHubBaseAddress .. package.repo .. "/" .. serverPath

    if moveDir then
      print(string.format("Installing content of folder %s to %s.", fileURL, localFolderPath))
      local fileRepoUrl = gitHubBaseAddress .. package.repo .. "/"
      folderDownload(serverPath, localFolderPath, package.repo, skipIfExist, forceInstall, fullForceInstall, fileRepoUrl, installedFile)
    else
      print(string.format("Installing file %s to %s.", fileURL, localFolderPath))
      fileDownload(fileURL, localFolderPath, fileName, skipIfExist, forceInstall, fullForceInstall, installedFile)
    end
  end

  local installedPackages = readDataFile(datafolderPath, installedPackagesFileName)
  package.installedFile = installedFile
  installedPackages[packageName] = package
  saveDataFile(datafolderPath, installedPackagesFileName, installedPackages)
end

function pacmanApi.install(packageName, forceInstall, fullForceInstall)
  checkArg(1, packageName, "string")
  checkArg(2, forceInstall, "boolean", "nil")
  checkArg(3, fullForceInstall, "boolean", "nil")

  print(string.format("Installing package [%s] is starting...", packageName))
  installInternal(packageName, forceInstall, fullForceInstall, false)
  print(string.format("Package [%s] is successfully installed.", packageName))
end

function pacmanApi.uninstall(packageName)
  checkArg(1, packageName, "string")

  print(string.format("Uninstalling package [%s] is starting...", packageName))

  local result, pacmanConfig = pcall(getPacmanConfig)
  if not result or not pacmanConfig then
    error("Could not download the pacman config file. Please ensure you have an Internet connection: " .. pacmanConfig)
  end

  local repositories = getRepositories(pacmanConfig)
  local defaultInstallPath = getFolderPath(pacmanConfig.defaultInstallPath)
  local datafolderPath = getFolderPath(pacmanConfig.dataPath, defaultInstallPath)

  local installedPackages = readDataFile(datafolderPath, installedPackagesFileName)
  local package = installedPackages[packageName]

  if not package then
    error(string.format("Package [%s] is not installed.", packageName))
  end

  for _, filePath in pairs(package.installedFile) do
    if fs.exists(filePath) then
      fs.remove(filePath)
      print(string.format("File %s removed.", filePath))
    end
  end

  installedPackages[packageName] = nil
  saveDataFile(datafolderPath, installedPackagesFileName, installedPackages)

  print(string.format("Package [%s] is uninstalled.", packageName))
end

function pacmanApi.update(packageName)
  checkArg(1, packageName, "string")

  print(string.format("Updating package [%s] is starting...", packageName))
  installInternal(packageName, true, false, true)
  print(string.format("Package [%s] is successfully updated.", packageName))
end

function pacmanApi.info(packageName)
  checkArg(1, packageName, "string")

  local packages, defaultInstallPath, datafolderPath = pacmanApi.listPackages(packageName)
  local package = packages[packageName]

  if not package then
    error(string.format("Unknown package [%s]. Please ensure the package name is correct.", packageName))
  end

  local result = packageName .. "\n"
  result = result .. string.rep(unicode.char(0x0336), string.len(packageName)) .. "\n"
  result = result .. "Name: " .. package.name .. "\n"
  result = result .. "Version: " .. package.version .. "\n"
  result = result .. "Authors: " .. package.authors .. "\n"
  result = result .. "Description: " .. package.description .. "\n"
  result = result .. "Note: " .. package.note .. "\n"
  result = result .. "Dependencies:"

  local separator = " "

  for _, dependence in pairs(package.dependencies) do
    result = result .. separator .. dependence
    separator = ", "
  end

  result = result .. "\n"
  
  return result
end

return pacmanApi
