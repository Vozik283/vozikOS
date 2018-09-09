local component = require("component")

local fileserverapi = {}

local modem = component.modem
local internet
local wget

local function getInternet()
  if not component.isAvailable("internet") then
    error("This program requires an internet card to run.")
  end

  internet = require("internet")
  wget = loadfile("/bin/wget.lua")
end

local function getFileContent(url)
  local content = ""
  local result, response = pcall(internet.request, url)

  if not result or not response then
    error(string.format("File %s can not be downloaded: %s", url, response))
  end

  for chunk in response do
    content = content .. chunk
  end

  return content
end

local function splitByChunk(text, chunkSize)
  local subStrings = {}
  local chunkIndex = 1

  for index=1, text:len(), chunkSize do
    subStrings[chunkIndex] = text:sub(index, index + chunkSize - 1)
    chunkIndex = chunkIndex + 1
  end

  return subStrings, chunkIndex - 1
end

local function filedownload(senderAddress, port, url)
  getInternet()
  local data = getFileContent(url)

  local maxPacketSize = modem.maxPacketSize() - 100
  local dataSize = string.len(maxPacketSize)

  if dataSize > maxPacketSize then
    local chunks, numberOfChunks = splitByChunk(data, maxPacketSize)

    modem.send(senderAddress, port, "START_FILE_DOWNLOAD", numberOfChunks)
    
    for chunkIndex = 1, numberOfChunks do
      local eventName, _, _, _, _, _, _  = event.pull(20, "modem_message", nil, senderAddress, port, nil, "SEND_CHUNK", chunkIndex)
      
      if not eventName then
        error("The client did not respond.")
      end
      
      modem.send(senderAddress, port, "CHUNK_DOWNLOAD", chunkIndex, chunks[chunkIndex])
    end
  else
    modem.send(senderAddress, port, "FILE_DOWNLOAD", data)
  end
end

function fileserverapi.modemMessageHandler(eventName, receiverAddress, senderAddress, port, distance, command, data)
  if "DOWNLOAD" == command then
    filedownload(senderAddress, port, data)
  end
end

return fileserverapi
