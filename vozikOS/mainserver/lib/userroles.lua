local userRoles = {
  [0] = "admin",  
  [1] = "operator",
  [2] = "host"
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