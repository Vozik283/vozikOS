local userStatuses = {
  [0] = "created",  
  [1] = "login",
  [2] = "logout"
}

do
  local keys = {}
  for k in pairs(userStatuses) do
    table.insert(keys, k)
  end
  for _, k in pairs(keys) do
    userStatuses[userStatuses[k]] = k
  end
end

return userStatuses