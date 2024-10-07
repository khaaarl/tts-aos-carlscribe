require('aos-carlscribe')
local json = require('json')

--[[]]
local f = assert(io.open(arg[1], "r"))
local xml = f:read("*all")
f:close()
local data = ParseBSData(xml)
f = assert(io.open(arg[1] .. ".json", "w"))
f:write(json.encode(data))
f:close()
--]]
