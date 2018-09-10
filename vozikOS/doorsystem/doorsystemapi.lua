local fileutil = require("fileutil")
local sides = require("sides")
local component = require("component")
local userapi = require("userapi")

local doorsystemapi = {}

function doorsystemapi.motionHandler(eventName, address, relativeX, relativeY, relativeZ, entityName, ...)
  local doorConfig = fileutil.readDataFile("/usr/etc", "door.cfg")

  local redstoneAddress = doorConfig[address].address

  if not redstoneAddress then
    return false
  end
  
  local red = component.proxy(redstoneAddress)
  if red.getOutput(sides.top) > 0 then
    return
  end

  local serverConfig = fileutil.readDataFile("/usr/etc", "server.cfg")
  local serverAddress = serverConfig["mainServer"].address

  if not serverAddress then
    error("Unknown main server address")
  end

  if userapi.canUseClient(serverAddress, entityName) then
    red.setOutput(sides.top, 1)
    os.sleep(5)
    red.setOutput(sides.top, 0)
  end

  return true
end

function doorsystemapi.closeAllDoors()
  local doorConfig = fileutil.readDataFile("/usr/etc", "door.cfg")

  for address, _  in pairs(doorConfig) do
    if component.type(address) == "redstone" then
      local red = component.proxy(address)
      red.setOutput(sides.top, 0)
    end
  end
end

return doorsystemapi
