local mainserverinit = require("mainserverinit")

local result, reason = pcall(mainserverinit.init)

if not result then
  io.stderr:write("Main server starting failed.\n")
  if reason then io.stderr:write(reason .. "\n") end
  return
end
