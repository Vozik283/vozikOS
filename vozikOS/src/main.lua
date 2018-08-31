local unicode = require("unicode")

local function test(n, p, ...)
  checkArg(1, n, "string")
  print(...)
end

local function main()
test(1, 2, 3)
end
main()
