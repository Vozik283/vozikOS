

local function test(n, p, ...)
print(string.gsub("master/vozikOS/packagemanager/","^(.-)/.+$","%1"))
print(string.gsub("master/vozikOS/packagemanager/","^.-/(.-)/?$","%1"))

end

local function main()
test(1, 2, 3)
end
main()
