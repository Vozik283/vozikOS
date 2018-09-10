local mainserver = {}

local component = require("component")
local event = require("event")
local serverports = require("serverports")
local fileserverapi = require("fileserverapi")
local userapi = require("userapi")

local modem = component.modem

local quiet = false

local function modemMessageHandler(eventName, receiverAddress, senderAddress, port, distance, ...)
  if port == serverports.fileServer then
    local result, reason = pcall(fileserverapi.modemMessageHandler, eventName, receiverAddress, senderAddress, port, distance, ...)

    if not quiet and not result then
      io.stderr:write("File server failed.\n")
      if reason then io.stderr:write(reason .. "\n") end
      return
    end
  elseif port == serverports.userServer then
    local result, reason = pcall(userapi.modemMessageHandler, eventName, receiverAddress, senderAddress, port, distance, ...)

    if not quiet and not result then
      io.stderr:write("User server failed.\n")
      if reason then io.stderr:write(reason .. "\n") end
      return
    end
  end
end

local function networkInit()
  modem.open(serverports.fileServer)
  modem.open(serverports.userServer)
  event.listen("modem_message", modemMessageHandler)
end

function mainserver.init()
  if component.isAvailable("internet") and component.isAvailable("modem") then
    networkInit()
  else
    error("Main server requires an internet and network card to run.")
  end
end

return mainserver
