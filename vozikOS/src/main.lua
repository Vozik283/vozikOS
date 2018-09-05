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

local function main()
test(1, 2, 3)
print(isEmpty({1}))

local b = {}
testa(b)
print(b[123])
end
main()
