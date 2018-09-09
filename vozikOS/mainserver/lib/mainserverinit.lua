local mainserver = {}

local component = require("component")
local event = require("event")
local serverports = require("serverports")
local fileserverapi = require("fileserverapi")

local modem = component.modem

local quit = false

local function modemMessageHandler(eventName, receiverAddress, senderAddress, port, distance, ...)
  if port == serverports.fileServer then
    local result, reason = pcall(fileserverapi.modemMessageHandler, eventName, receiverAddress, senderAddress, port, distance, ...)

    if not quit and not result then
      io.stderr:write("File server failed.\n")
      if reason then io.stderr:write(reason .. "\n") end
      return
    end
  end
end

local function fileServerInit()
  modem.open(serverports.fileServer)
  event.listen("modem_message", modemMessageHandler)
end

function mainserver.init()
  if component.isAvailable("internet") and component.isAvailable("modem") then
    fileServerInit()
  else
    error("Main server requires an internet and network card to run.")
  end
end

return mainserver
