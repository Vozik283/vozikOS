local component = require("component")
local term = require("term")
local unicode = require("unicode")
local text = require("text")
local serverports = require("serverports")
local serial = require("serialization")
local fs = require("filesystem")
local fileutil = require("fileutil")

local internet
local wget
local diskDriver
local gpu
local modem

local function getInternet()
  if not component.isAvailable("internet") then
    error("This program requires an internet card to run.")
  end

  internet = require("internet")
  wget = loadfile("/bin/wget.lua")
end

getInternet()

local function getGpu()
  if not component.isAvailable("gpu") then
    error("This program requires a graphics cards to run.\n")
  end

  gpu = component.gpu
end

getGpu()

local function getModem()
  if not component.isAvailable("modem") then
    error("This program requires a network cards to run.\n")
  end

  modem = component.modem
end

getModem()

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

local function saveFile(path, fileName, content)
  local filePath = fs.concat(path, fileName)

  if not diskDriver.exists(path) then
    print(string.format("Folder %s is created.", path))
    diskDriver.makeDirectory(path)
  end

  local file, reason = diskDriver.open(filePath, "wb")
  if not file then
    error("Error while trying to save file " .. filePath .. ": " .. reason)
  end

  if type(content) == "string" then
    diskDriver.write(file, content)
  else
    diskDriver.write(file, serial.serialize(content))
  end

  diskDriver.close(file)
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


getFileSystem()
diskDriver.setLabel("TerminalInstaller")

local serverConfig = {}
serverConfig.address = modem.address

saveFile("/", "server.cfg", serverConfig)
saveFile("/", "clientterminalinstall.lua", getFileContent("https://raw.githubusercontent.com/Vozik283/vozikOS/master/vozikOS/clientterminal/clientterminalinstall.lua"))
saveFile("/", "pacmanapi.lua", getFileContent("https://raw.githubusercontent.com/Vozik283/vozikOS/master/vozikOS/packagemanager/lib/pacmanapi.lua"))
saveFile("/", "fileutil.lua", getFileContent("https://raw.githubusercontent.com/Vozik283/vozikOS/master/vozikOS/basiclib/fileutil.lua"))
saveFile("/", "serverports.lua", getFileContent("https://raw.githubusercontent.com/Vozik283/vozikOS/master/vozikOS/mainserver/lib/serverports.lua"))




