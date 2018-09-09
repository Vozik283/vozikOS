local serial = require("serialization")
local fs = require("filesystem")
local component = require("component")
local event = require("event")
local serverports = require("serverports")

local fileutil = {}

local modem = component.modem

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

  if not fs.exists(datafolderPath) then
    print(string.format("Folder %s is created.", datafolderPath))
    fs.makeDirectory(datafolderPath)
  end

  local file, reason = io.open(dataFilePath, "wb")
  if not file then
    error("Error while trying to save file " .. dataFilePath .. ": " .. reason)
  end
  
  if type(content) == "string" then
    file:write(content)
  else
    file:write(serial.serialize(content))
  end
  
  file:close()
end

function fileutil.downloadRemoteFile(url)
  modem.open(serverports.fileServer)

  if(fs.exists("/usr/etc/server.cfg")) then
    local serverConfig = fileutil.readDataFile("/usr/etc", "server.cfg")
    local mainServer = serverConfig["mainServer"]
  
     modem.send(mainServer.address, serverports.fileServer, "DOWNLOAD", url)
  else
    modem.broadcast(serverports.fileServer, "DOWNLOAD", url)
  end
  
  local eventName, receiverAddress, senderAddress, port, distance, command, data = event.pull(20, "modem_message", nil, nil, nil, serverports.fileServer)

  local fileContent

  if not eventName then
    modem.close(serverports.fileServer)
    error("The main server did not respond.")
  elseif command == "FILE_DOWNLOAD" then
    fileContent = data
  elseif command == "START_FILE_DOWNLOAD" then
    local numberOfChunks = data
    fileContent = ""

    for chunkIndex = 1, numberOfChunks do
      modem.send(senderAddress, port, "SEND_CHUNK", chunkIndex)
      local _, _, _, _, _, _, _, chunkContent  = event.pull(20, "modem_message", nil, senderAddress, port, nil, "CHUNK_DOWNLOAD", chunkIndex)

      if chunkContent then
        fileContent = fileContent .. chunkContent
      else
        modem.close(serverports.fileServer)
        error("The main server did not respond.")
      end
    end
  end

  modem.close(serverports.fileServer)

  return fileContent
end

return fileutil
