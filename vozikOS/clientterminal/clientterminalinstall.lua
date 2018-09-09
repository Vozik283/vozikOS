local component = require("component")
local fs = require("filesystem")
local pacmanApi = require("pacmanapi")
local fileutil = require("fileutil")

local modem
local diskDriver

local function getModem()
  if not component.isAvailable("modem") then
    error("This program requires an network card to run.")
  end

  modem = component.modem
end

local function getFileSystem()
  local diskDriver = component.proxy("TerminalInstaller")

  if not diskDriver then
    error("The installation diskette does not found.\n")
  end
end

getModem()
getFileSystem()


local function readFile(path, fileName)
  local filePath = fs.concat(path, fileName)

  if fs.exists(filePath) then
    local file, reason = diskDriver.open(filePath, "rb")

    if not file then
      error("Error while trying to read file " .. filePath .. ": " .. reason)
    end

    local content = diskDriver.read(file, "*a")
    diskDriver.close(file)

    if not content then
      error("Error while trying to read file " .. filePath .. ": " .. reason)
    end

    return serial.unserialize(content)
  else
    error("The file " .. filePath .. " does not exist.")
  end
end

local serverCFG = readFile("/", "server.cfg")

local serverConfig = {}
serverConfig["mainServer"] = serverCFG

fileutil.saveDataFile("/usr/etc", "server.cfg", serverConfig)

local result, reason = pcall(pacmanApi.install, 'pacman', false, true)

if not result then
  io.stderr:write("Installation failed.\n")
  if reason then io.stderr:write(reason .. "\n") end
  return
end
