local component = require("component")
local fs = require("filesystem")

local internet
local wget

local function getInternet()
  if not component.isAvailable("internet") then
    error("This program requires an internet card to run.")
  end

  internet = require("internet")
  wget = loadfile("/bin/wget.lua")
end

getInternet()

local result, response, reason = pcall(wget, "-f", "https://raw.githubusercontent.com/Vozik283/vozikOS/master/vozikOS/packagemanager/lib/pacmanapi.lua")

if not result or not response then
  error(string.format("File %s can not be downloaded: %s", "https://git.io/fA4ZU", reason))
end

local pacmanApi = require("pacmanapi")

local result, reason = pcall(pacmanApi.install, 'pacman', false, true)

if not result then
  io.stderr:write("Installation failed.\n")
  if reason then io.stderr:write(reason .. "\n") end
  return
end

fs.remove("pacmanapi.lua")
