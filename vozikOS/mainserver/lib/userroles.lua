local userRoles = {
  [1] = "admin",  
  [2] = "operator",
  [3] = "host"
}

do
  local keys = {}
  for k in pairs(userRoles) do
    table.insert(keys, k)
  end
  for _, k in pairs(keys) do
    userRoles[userRoles[k]] = k
  end
end

return userRoles