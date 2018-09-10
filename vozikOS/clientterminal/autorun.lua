local clientterminalinit = require("clientterminalinit")

local result, reason = pcall(clientterminalinit.init)

if not result then
  io.stderr:write("Client terminal starting failed.\n")
  if reason then io.stderr:write(reason .. "\n") end
  return
end
