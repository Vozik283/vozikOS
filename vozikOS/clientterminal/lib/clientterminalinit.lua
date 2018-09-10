local clientTerminal = {}

local component = require("component")
local event = require("event")
local doorsystemapi = require("doorsystemapi")

local modem = component.modem

local quiet = false

local function modemMessageHandler(eventName, address, relativeX, relativeY, relativeZ, entityName, ...)
  local result, served = pcall(doorsystemapi.motionHandler, eventName, address, relativeX, relativeY, relativeZ, entityName, ...)

  if not quiet and not result then
    io.stderr:write("Motion event handler failed.\n")
    if served then io.stderr:write(served .. "\n") end
    return
  end
end

local function motionSensorInit()
  event.listen("motion", modemMessageHandler)
end

function clientTerminal.init()
  if not component.isAvailable("modem") then
    error("Terminal requires a network card to run.")
  elseif doorsystemapi then
    doorsystemapi.closeAllDoors()
    motionSensorInit()
  end
end

return clientTerminal
