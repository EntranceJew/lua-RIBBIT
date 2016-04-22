local math_random = math.random
if love and love.math and love.math.random then
	math_random = love.math.random
end

local http = require("socket.http")
local ltn12 = require("ltn12")
local function simple_request( args )
	local url = tostring(args.gateway) .. "/" .. tostring(args.endpoint)
	
	local resp = {}
	local client, code, headers, status = http.request({
		url=url,
		sink=ltn12.sink.table(resp),
		method="GET",
		headers=args.headers,
	})
	return {
		code = code,
		headers = headers,
		status = status,
		resp = resp
	}
end

--[[
	RIBBITClient is a frog.tips API client
	RIBBITClient is a client for making requests against the frog.tips API and
	parsing the responses returned via the RIBBIT messaging protocol:
	http://frog.tips/api/1/
]]
local RIBBITClient = {
	DEFAULT_GATEWAY = 'http://frog.tips/api/1',
	DEFAULT_ENDPOINT = 'tips',
	DEFAULT_HEADERS = {
		['Accept'] = 'application/der-stream',
	},
}
RIBBITClient.__index = RIBBITClient
setmetatable(RIBBITClient, {
	__call = function (class, ...)
		return class.new(...)
	end,
})

---
-- Create a new RIBBIT client.
-- @name RIBBITClient.new
-- @param gateway The server to aim at, plus api version.
-- @param endpoint The endpoint on the API to use.
-- @param headers A table of headers to supply with each request.
function RIBBITClient.new(gateway, endpoint, headers)
	local self = setmetatable({}, RIBBITClient)
	self.gateway = gateway or RIBBITClient.DEFAULT_GATEWAY
	self.endpoint = endpoint or RIBBITClient.DEFAULT_ENDPOINT
	self.headers = headers or RIBBITClient.DEFAULT_HEADERS
	
	self._croak_dict = nil
	self._croak_unordered = nil
	
	return self
end

-- not to be mistaken with 'dacoda-fy'
local function decodify(str, len, pos)
	local seq = seq or {}
	local sPos = 1
	while (sPos < len) do
		local newSeq, itemType, itemSize
		itemType = string.byte(str, sPos, sPos)
		sPos = sPos + 1
		itemSize = string.byte(str, sPos, sPos)
		sPos = sPos + 1
		if (itemSize > 128) then
			itemSize = itemSize - 128
			local itemSizeCalc = 0
			local itemSizeNext
			for i = 1, itemSize do
				itemSizeCalc = itemSizeCalc * 256
				itemSizeNext = string.byte(str, sPos, sPos)
				sPos = sPos + 1
				itemSizeCalc = itemSizeCalc + itemSizeNext
			end
			itemSize = itemSizeCalc
		end
		
		if itemType then
			if itemType == 0x02 then
				local hexStr
				hexStr = {string.byte(str, sPos, sPos + itemSize)}
				sPos = sPos + itemSize
				
				hexStr = string.format(string.rep("%X", itemSize), unpack(hexStr))
				newSeq = tonumber(hexStr, 16)
				if ( newSeq >= math.pow(256, itemSize)/2) then
					newSeq = newSeq - math.pow(256, itemSize)
				end
				table.insert(seq, newSeq)
			elseif itemType == 0x0C then
				newSeq = string.sub(str, sPos, sPos + itemSize)
				sPos = sPos + itemSize
				table.insert(seq, newSeq)
			elseif itemType == 0x30 then
				newSeq = decodify(string.sub(str, sPos, sPos+itemSize-1), itemSize, sPos)
				sPos = sPos + itemSize
				table.insert(seq, newSeq)
			end
		end
	end
	return seq
end

---
-- Take in a CROAK of data and return a lua object.
-- @name RIBBITClient.decode_CROAK
-- @param croak A JSON encoded CROAK.
-- @return The decoded CROAK tips object.
function RIBBITClient.decode_CROAK(croak)
	local deCROAK = decodify(croak, string.len(croak))[1]
	
	local formattedCROAK = {}
	for k,v in ipairs(deCROAK) do
		table.insert(formattedCROAK, {
			number = v[1],
			tip = v[2]
		})
	end
	
	return formattedCROAK
end

---
-- Retrieve a CROAK of FROG tips, caching any new tips.
-- @name RIBBITClient.croak
-- @param refresh_cache Flushes cache when provided.
-- @return The decoded CROAK tips object.
function RIBBITClient:croak(refresh_cache)
	local croak_resp = simple_request({
		gateway = self.gateway,
		endpoint = self.endpoint,
		headers = self.headers
	})

	if croak_resp.resp == nil then
		assert(false, "Error during CROAK request: " .. tostring(croak_resp.status))
	else
		local CROAK = RIBBITClient.decode_CROAK(table.concat(croak_resp.resp,''))
		if self._croak_dict == nil or	 refresh_cache then
			self._croak_dict = {}
			self._croak_unordered = {}
		end
		
		for k,v in pairs(CROAK) do
			if not self._croak_dict[v.number] then
				self._croak_dict[v.number] = v.tip
				table.insert(self._croak_unordered, v)
			end
		end
		
		return CROAK
	end
end

---
-- Retrieve a single cached FROG tip.
-- @name RIBBITClient.frog_tip
-- @return A string containing a FROG tip.
function RIBBITClient:frog_tip()
	if self._croak_dict == nil then
		self:croak(true)
	end
	return self._croak_unordered[math_random(1,#self._croak_unordered)].tip
end

return RIBBITClient