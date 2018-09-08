local serial = require("serialization")
local fs = require("filesystem")

local fileutil = {}

function fileutil.readDataFile(datafolderPath, fileName)
  local dataFilePath = fs.concat(datafolderPath, fileName)

  if fs.exists(dataFilePath) then
    local file, reason = io.open(dataFilePath, "rb")

    if not file then
      error("Error while trying to read file " .. dataFilePath .. ": " .. reason)
    end

    local content = file:read("*a")
    file:close()

    if not content then
      error("Error while trying to read file " .. dataFilePath .. ": " .. reason)
    end

    return serial.unserialize(content)
  else
    return {}
  end
end

function fileutil.saveDataFile(datafolderPath, fileName, content)
  local dataFilePath = fs.concat(datafolderPath, fileName)

  local file, reason = io.open(dataFilePath, "wb")
  if not file then
    error("Error while trying to save file " .. dataFilePath .. ": " .. reason)
  end

  file:write(serial.serialize(content))
  file:close()
end

return fileutil