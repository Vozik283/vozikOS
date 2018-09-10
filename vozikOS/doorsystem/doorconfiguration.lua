local component = require("component")
local term = require("term")
local unicode = require("unicode")
local text = require("text")
local event = require("event")
local keyboard = require("keyboard")
local fileutil = require("fileutil")

local gpu
local redstone
local motionSensors = {}

local function getGpu()
  if not component.isAvailable("gpu") then
    error("This program requires a graphics cards to run.\n")
  end

  gpu = component.gpu
end

getGpu()

local function getRedstone()
  if not component.isAvailable("redstone") then
    error("This program requires a redstone component to run.\n")
  end

  if not component.isAvailable("motion_sensor") then
    error("This program requires a motion sensor to run.\n")
  end

  local w, h = gpu.getResolution()
  term.clear()

  print("Door configuration starting...")
  print("")

  print(string.format(" %-25.25s   %-10s   %-25s", "Label", "Slot", "Address"))
  print(string.rep(unicode.char(0x0336), w))

  local redstoneHint = {}
  local redstones = {}

  for address, type in pairs(component.list("redstone")) do
    local red = component.proxy(address)
    print(string.format(" %-25.25s   %-10s   %-25s",red.getLabel(), red.slot, red.address))
    table.insert(redstoneHint, red.address)
    redstones[red.address] = red
  end

  print("")
  term.write("Select redstone component address: ")
  local address = text.trim(term.read(redstoneHint, false, nil, nil))
  print("")

  if not address or not redstones[address] then
    error("Unknown redstone component.\n")
  end

  redstone = redstones[address];
end

local function getMotionSensors()
  print("Approach to motion sensors and then press <Enter>: ")
  print("")
  print(string.format(" %-25.25s   %-10s   %-10s   %-10s   %-25s", "Sensor Address", "RelativeX", "RelativeY", "RelativeZ", "Entity Name"))
  print(string.rep(unicode.char(0x0336), w))
  local next = true

  while next do
    local eventName, address, relativeX, relativeY, relativeZ, entityName = event.pullMultiple("key_up", "motion")

    if eventName == "key_up" and keyboard.keys.enter == relativeY then
      next = false
    elseif eventName == "motion" and not motionSensors[address]  then
      print(string.format(" %-25.25s   %-10s   %-10s   %-10s   %-25s", address, relativeX, relativeY, relativeZ, entityName))
      motionSensors[address] = component.proxy(address)
    end
  end

  if #motionSensors == 0 then
    error("No motion sensor was selected.\n")
  end
end

getRedstone()
getMotionSensors()

local sensorAddresses = {}

for address, sensor in pairs(motionSensors) do
  table.insert(sensorAddresses, address)
end

print("")
term.write("Write door name: ")
local doorName = text.trim(term.read())

if doorName:len() < 1 then
  error("Invalid door name: " .. doorName)
end

redstone.setLabel(doorName)

print("")
print("Adding door configuration to door.cfg")
local doorConfig = fileutil.readDataFile("/usr/etc", "door.cfg")

local door = doorConfig[redstone.address] or {}
door.address = redstone.address
door.name = doorName
door.motionSensors = sensorAddresses

doorConfig[redstone.address] = door

for _, address in pairs(sensorAddresses) do
  doorConfig[address] = door
end

fileutil.saveDataFile("/usr/etc", "door.cfg", doorConfig)

print("Door configuration is complete")