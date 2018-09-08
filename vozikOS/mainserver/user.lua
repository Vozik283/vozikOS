local shell = require("shell")
local userapi = require("userapi")
local userroles = require("userroles")
local unicode = require("unicode")
local term = require("term")

local gpu

local args, options = shell.parse(...)
local action = args[1]

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

    print(string.format(" %-25.25s   %-10s   %-10s", userName, user.role, user.status))
    row = row + 1

    if row >= maxRows then
      firstRow = true
      row = 0

      term.write("\n << Press Enter >>")
      term.pull("key_down", nil, nil, keyboard.keys.enter)
    end
  end
end

local function addUser(userName)
  checkArg(1, userName, "string")
  
  term.clear()
  print(string.format("Adding user %s ...", userName))
  term.write("Password: ")
  local password = text.trim(term.read(nil, false, nil, "*"))
  term.write("Role: ")
  local role = text.trim(term.read(userroles, false, nil, nil))

  local result, reason = pcall(userapi.createUser, userName, password, role)

  if not result then
    io.stderr:write("Creating user failed.\n")
    if users then io.stderr:write(reason .. "\n") end
    return
  end
  
  print(string.format("User %s is added.", userName))
end

local function removeUser(userName)
  print(string.format("Removing user %s ...", userName))

  local result, reason = pcall(userapi.removeUser, userName, password, role)

  if not result then
    io.stderr:write("Removing user failed.\n")
    if users then io.stderr:write(reason .. "\n") end
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