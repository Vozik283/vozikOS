local pacmanApi = require("lib.pacmanapi")
local shell = require("shell")
local unicode = require("unicode")
local component = require("component")
local term = require("term")
local keyboard = require("keyboard")

local gpu

local args, options = shell.parse(...)
local action = args[1]

local function getGpu()
  if not component.isAvailable("gpu") then
    io.stderr:write("This program requires a graphics cards to run.\n")
    return false
  end

  gpu = component.gpu

  return true
end

if not getGpu() then
  return
end

if not term.isAvailable() then
  io.stderr:write("This program requires a terminal to run.\n")
  return
end

local function tableLength(table)
  local count = 0

  for _ in pairs(table) do
    count = count + 1
  end

  return count
end

local function listPackages(filter, installed, notInstalled, obsolate)
  local w, h = gpu.getResolution()
  local result, packages, reason = pcall(pacmanApi.listPackages, filter, installed, notInstalled, obsolate)

  if not result or not packages then
    io.stderr:write("Loading package failed.\n")
    if reason then io.stderr:write(reason) end
    return
  end

  if tableLength(packages) < 1 then
    io.stderr:write("The package list is empty.\n")
    return
  end

  local maxRows = h - 4
  local firstRow = true
  local row = 0

  for packageName, package in pairs(packages) do
    if firstRow then
      firstRow = false

      term.clear()
      print(string.format(" %-25.25s   %-10s   %-15s   %s", "Package Name", "Version", "Status", "Description"))
      print(string.rep(unicode.char(0x0336), w))
    end

    print(string.format(" %-25.25s   %-10s   %-15s   %s", packageName, package.version, package.status, package.description))
    row = row + 1

    if row >= maxRows then
      firstRow = true
      row = 0

      term.write("\n << Press Enter >>")
      term.pull("key_down", nil, nil, keyboard.keys.enter)
    end
  end
end

local function install(packageName, forceInstall)
  local result, reason = pcall(pacmanApi.install, packageName, forceInstall)

  if not result then
    io.stderr:write("Installation failed.\n")
    if reason then io.stderr:write(reason) end
    return
  end
end

if action == "list" then
  local filter = args[2]
  listPackages(filter, options.i, options.n, options.o)
elseif action == "install" then
  local packageName = args[2]
  install(packageName, options.f)
else
  io.stderr:write("Unknown options.\n")
end
