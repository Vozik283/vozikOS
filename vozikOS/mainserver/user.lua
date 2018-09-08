local shell = require("shell")
local component = require("component")
local userapi = require("userapi")
local userroles = require("userroles")
local userstatuses = require("userstatuses")
local unicode = require("unicode")
local term = require("term")
local text = require("text")
local keyboard = require("keyboard")

local gpu

local args, options = shell.parse(...)
local action = args[1]

if not term.isAvailable() then
  io.stderr:write("This program requires a terminal to run.\n")
  return
end

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

local function tableLength(table)
  local count = 0

  for _ in pairs(table) do
    count = count + 1
  end

  return count
end

local function listUsers()
  local w, h = gpu.getResolution()
  local result, users = pcall(userapi.getUserList)

  if not result or not users then
    io.stderr:write("Loading users failed.\n")
    if users then io.stderr:write(users .. "\n") end
    return
  end

  if tableLength(users) < 1 then
    io.stderr:write("The user list is empty.\n")
    return
  end

  local maxRows = h - 4
  local firstRow = true
  local row = 0

  for userName, user in pairs(users) do
    if firstRow then
      firstRow = false

      term.clear()
      print(string.format(" %-25.25s   %-10s   %-10s", "User Name", "Role", "Status"))
      print(string.rep(unicode.char(0x0336), w))
    end

    print(string.format(" %-25.25s   %-10s   %-10s", userName, userroles[user.role], userstatuses[user.status]))
    row = row + 1

    if row >= maxRows then
      firstRow = true
      row = 0

      term.write("\n << Press Enter >>")
      term.pull("key_down", nil, nil, keyboard.keys.enter)
    end
  end
end

local function getUserRolesList()
  local roles = {}
  local index = 1
  
  while true do
    local role = userroles[index]
    index = index + 1
    
    if not role then
      return roles
    else
      table.insert(roles, role)
    end
  end
  
  return roles
end

local function addUser(userName)
  checkArg(1, userName, "string")
  
  term.clear()
  print(string.format("Adding user %s ...", userName))
  term.write("Password: ")
  local password = text.trim(term.read(nil, false, nil, "*"))
  print("")
  term.write("Role: ")
  local history = getUserRolesList()
  local role = text.trim(term.read(history, false, nil, nil))
  print("")

  local result, reason = pcall(userapi.createUser, userName, password, role)

  if not result then
    io.stderr:write("Creating user failed.\n")
    if reason then io.stderr:write(reason .. "\n") end
    return
  end
  
  print(string.format("User %s is added.", userName))
end

local function removeUser(userName)
  print(string.format("Removing user %s ...", userName))

  local result, reason = pcall(userapi.removeUser, userName)

  if not result then
    io.stderr:write("Removing user failed.\n")
    if reason then io.stderr:write(reason .. "\n") end
    return
  end
  
  print(string.format("User %s is removed.", userName))
end


if action == "list" then
  listUsers()
elseif action == "add" then
  local userName = args[2]
  addUser(userName)
elseif action == "remove" then
  local userName = args[2]
  removeUser(userName)
else
  io.stderr:write("Unknown option.\n")
  io.stderr:write("Write \"man pacman\" for help.\n")
end