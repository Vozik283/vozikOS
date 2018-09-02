local component = require("component")
local serial = require("serialization")
local process = require("process")
local fs = require("filesystem")
local shell = require("shell")

local pacmanApi = {}

local internet
local wget
local gitHubBaseAddress = "https://raw.githubusercontent.com/"
local gitHubApiAddress = "https://api.github.com/repos/"

local function getInternet()
  if not component.isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run.\n")
    return false
  end

  internet = require("internet")
  wget = loadfile("wget")

  return true
end

local function getFileContent(url)
  local content = ""
  local result, response, reason = pcall(internet.request, url)

  if not result or not response then
    io.stderr:write(string.format("The file %s can not be downloaded!\n", url))
    if reason then io.stderr:write(reason) end
    return nil
  end

  for chunk in response do
    content = content .. chunk
  end

  return content
end

local function getPacmanConfig()
  local pacmanConfigUrl = gitHubBaseAddress .. "Vozik283/vozikOS/master/vozikOS/packagemanager/etc/pacman.cfg"
  local result, content = pcall(getFileContent, pacmanConfigUrl)

  if not result or not content then
    return nill
  end

  local pacmanConfig = serial.unserialize(content)

  return pacmanConfig
end

local function getRepositories(pacmanConfig)
  return pacmanConfig.repos
end

local function getPackages(repos, filter)
  local packages = {}

  for repoFolder, repo in pairs(repos) do
    for packageName, package in pairs(repo) do
      if not filter or string.find(packageName, filter) then
        package.status = "Not Installed"
        package.repo = repoFolder
        packages[packageName] = package
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

local function getFileFlags(file, forceInstall)
  if string.find(file, "?") == 1 and not forceInstall then
    return string.sub(file, 2), true, false
  elseif string.find(file, ":") == 1 then
    return string.sub(file, 2), false, true
  else
    return file, false, false
  end
end

function pacmanApi.listPackages(filter, installed, notInstalled, obsolate)
  checkArg(1, filter, "string", "nil")
  checkArg(2, installed, "boolean", "nil")
  checkArg(3, notInstalled, "boolean", "nil")
  checkArg(4, obsolate, "boolean", "nil")

  if not getInternet() then
    return nil
  end

  local result, pacmanConfig, reason = pcall(getPacmanConfig)
  if not result or not pacmanConfig then
    io.stderr:write("Could not download the pacman config file. Please ensure you have an Internet connection.\n")
    if reason then io.stderr:write(reason) end
    return nil
  end

  local repositories = getRepositories(pacmanConfig)

  return getPackages(repositories, filter), getFolderPath(pacmanConfig.defaultInstallPath), getFolderPath(pacmanConfig.dataPath)
end

function fileDownload(serverFilePath, localFolderPath, softInstall)
  local fileName = getFileName(serverFilePath)
  local localFilePath = fs.concat(localFolderPath, fileName)

  if softInstall then
    if fs.exists(localFilePath) then
      print(string.format("The file %s already exists and option -f is not enabled.", localFilePath))
    else
      wget("-q", serverFilePath, localFilePath)
      print(string.format("The file %s already is downloaded.", localFilePath))
    end
  else
    wget("-fq", serverFilePath, localFilePath)
    print(string.format("The file %s already is downloaded.", localFilePath))
  end
end

function folderDownload(serverFolderPath, localFolderPath, repositories, softInstall)
  local branch = string.gsub(path, "^(.-)/.+$", "%1")
  local folderPath = string.gsub(path, "^.-/(.-)/?$", "%1")
  local folderURL = gitHubApiAddress .. repositories .. "/contents/" .. folderPath .. "?ref=" .. branch

  local result, folder, reason = pcall(getFileContent, folderURL)

  if not result or not folder then
    io.stderr:write(string.format("Could not download the %s folder.\n", folderURL))
    if reason then io.stderr:write(reason) end
    return
  end

  local folderContents = serial.unserialize(folder)
  --master/vozikOS/packagemanager/
  for _, content in pairs(folderContents) do
    if content.dir == "file" then
      local serverFilePath = serverFolderPath .. content.name
       
      fileDownload(serverFilePath, localFolderPath, softInstall)
    elseif content.dir == "dir" then
      if not fs.exists(fs.path(innerLocalFolderPath)) then
        fs.makeDirectory(fs.path(innerLocalFolderPath))
      end

      local innerServerFolderPath = serverFolderPath .. content.name .. "/"
      local innerLocalFolderPath = fs.concat(localFolderPath,  content.name)
      
      folderDownload(innerServerFolderPath, innerLocalFolderPath, repositories, softInstall)
    end
  end
end

function pacmanApi.install(packageName, forceInstall)
  checkArg(1, packageName, "string")
  checkArg(2, forceInstall, "boolean", "nil")

  print(string.format("Installing package [%s] is starting...", packageName))

  local packages, defaultInstallPath, dataPath = pacmanApi.listPackages(packageName)
  local package = packages[packageName]

  if not package then
    io.stderr:write("Unknown package.\n")
    return
  end

  for sPathNotValidate, lPathNotValidate in pairs(package.files) do
    local serverPath, softInstall, moveDir = getFileFlags(sPathNotValidate, forceInstall)
    local localFolderPath = getFolderPath(lPathNotValidate, defaultInstallPath)
    local fileName = getFileName(serverPath)
    local fileURL = gitHubBaseAddress .. package.repo .. "/" .. serverPath

    if moveDir then
      print(string.format("Installing content of folder %s to %s.", fileURL, localFolderPath))
      folderDownload(serverPath, localFolderPath, package.repo, softInstall)
    else
      print(string.format("Installing file %s to %s.", fileURL, localFolderPath))
      fileDownload(fileURL, localFolderPath, softInstall)
    end
  end
end

return pacmanApi
