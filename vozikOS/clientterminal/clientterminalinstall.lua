local component = require("component")
local fs = require("filesystem")
local pacmanApi = require("pacmanapi")
local fileutil = require("fileutil")
local serial = require("serialization")

local modem
local diskDriver

local function getModem()
  if not component.isAvailable("modem") then
    error("This program requires an network card to run.")
  end

  modem = component.modem
end

local function getFileSystem()
  local w, h = gpu.getResolution()
  local allFS = {}
  local fsHint = {}

  term.clear()
  print("Creating an install diskette..")
  print("")
  print(string.format(" %-25.25s   %-10s   %-25s", "Label", "Slot", "Address"))
  print(string.rep(unicode.char(0x0336), w))

  for address, type in pairs(component.list("file")) do
    local fs = component.proxy(address)
    print(string.format(" %-25.25s   %-10s   %-25s",fs.getLabel(), fs.slot, fs.address))
    table.insert(fsHint, fs.address)
    allFS[fs.address] = fs
  end

  print("")
  term.write("Select Target file system address: ")
  local address = text.trim(term.read(fsHint, false, nil, nil))
  print("")

  if not address or not allFS[address] then
    error("Unknown file system.\n")
  end

  diskDriver = allFS[address];
end

local function getFileSystem()
  for address, type in pairs(component.list("file")) do
    local comp = component.proxy(address)

    if "TerminalInstal" == comp.getLabel() then
      diskDriver = comp
      return
    end
  end

  if not diskDriver then
    error("The installation diskette does not found.\n")
  end
end

getModem()
getFileSystem()


local function readFile(path, fileName)
  local filePath = fs.concat(path, fileName)

  if diskDriver.exists(filePath) then
    local file, reason = diskDriver.open(filePath, "rb")

    if not file then
      error("Error while trying to read file " .. filePath .. ": " .. reason)
    end

    local content = ""
    
    repeat
      local chunk = diskDriver.read(file, 500)

      if chunk then
        content = content .. chunk
      end
    until( chunk ~= nil )
    
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
