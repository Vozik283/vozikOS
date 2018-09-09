local function a()
  error("error \n error")
  return true
end

local function b()
  a(a)
  print(123)
  return true
end

local function test(n, p, ...)
local q, w, e = pcall(b)
print(q, w, "aqa", e)

end

local function isEmpty(table)
  if next(table) == nil then
    return true;
  end
  
  return false;
end

local function testa(b)
  b[123]=5
end

local function splitByChunk(text, chunkSize)
    local subStrings = {}    
    local chunkIndex = 1
    
    for index=1, text:len(), chunkSize do
        subStrings[chunkIndex] = text:sub(index, index + chunkSize - 1)
        chunkIndex = chunkIndex + 1
    end
    return subStrings
end

local function main()
  local t = "012345678911"
  local st = splitByChunk("012345678911", 5)
for i,v in ipairs(st) do
   print(i, v)
end
end
main()
