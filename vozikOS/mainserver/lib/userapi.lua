local userroles = require("userroles")
local userstatuses = require("userstatuses")
local fileutil = require("fileutil")
local component = require("component")

local userapi = {}

local workingDirectory = "/usr/etc/"
local usersDB = "users.svd"

local function getData()
  if not component.isAvailable("data") then
    error("This program requires an data card to run.")
  end

  return component.data
end

local data = getData()

local function getPasswordHash(password)
  return data.sha256(password)
end

function userapi.getUserList()
  local result, users = pcall(fileutil.readDataFile, workingDirectory, usersDB)

  if not result then
    error("Error while trying to read file " .. usersDB)
  end
  
  return users
end

function userapi.getUserInfo(userName, users)
  if not users then
    users = userapi.getUserList()
  end
  
  local user = users[userName]

  if not user then
    error(string.format("User %s does not exist.", userName))
  end
  
  return user
end

local function isPasswordValid(userName, password, users)
  local user = userapi.getUserInfo(userName, users)

  if user.password == getPasswordHash(password) then
    return true
  end

  return false
end

function userapi.createUser(userName, password, role)
  checkArg(1, userName, "string")
  checkArg(2, password, "string")
  checkArg(3, role, "string")

  local users = userapi.getUserList()

  local user = users[userName]

  if user then
    error(string.format("User %s already exists.", userName))
  end
  
  if not userroles[role] then
    error(string.format("Invalid user role %s.", role))
  end
  
  user = {}
  user.name = userName
  user.password = getPasswordHash(password)
  user.role = userroles[role]
  user.status = userstatuses.created

  users[userName] = user

  local result, reason = pcall(fileutil.saveDataFile, workingDirectory, usersDB, users)

  if not result then
    error("Error while trying to save to file " .. usersDB .. ". \n" .. reason)
  end
end

function userapi.changeUserPassword(userName, oldPasspord, newPassword)
  checkArg(1, userName, "string")
  checkArg(2, oldPasspord, "string")
  checkArg(3, newPassword, "string")

  local users = userapi.getUserList()

  if isPasswordValid(userName, oldPasspord, users) then
    local user = userapi.getUserInfo(userName, users)
    user.password = getPasswordHash(newPassword)

    users[userName] = user

    local result, reason = pcall(fileutil.saveDataFile, workingDirectory, usersDB, users)
  else
    error("Old password is not correct.")
  end
end

function userapi.removeUser(userName)
  local users = userapi.getUserList()
  local user = userapi.getUserInfo(userName, users)

  users[userName] = nil

  local result, reason = pcall(fileutil.saveDataFile, workingDirectory, usersDB, users)
end



function userapi.logIn(userName, password)
  checkArg(1, userName, "string")
  checkArg(2, password, "string")
  
  local users = userapi.getUserList()

  if isPasswordValid(userName, password, users) then
    local user = userapi.getUserInfo(userName, users)
    user.status = userstatuses.login
  end
end

function userapi.logOut(userName)
  local user = userapi.getUserInfo(userName)
  user.status = userstatuses.logout
end

function userapi.canUse(userName)

end

return userapi
