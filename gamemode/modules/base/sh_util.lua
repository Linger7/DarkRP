-----------------------------------------------------------------------------[[
/*---------------------------------------------------------------------------
Utility functions
---------------------------------------------------------------------------*/
-----------------------------------------------------------------------------]]

local vector = FindMetaTable("Vector")
local meta = FindMetaTable("Player")
local config = GM.Config

/*---------------------------------------------------------------------------
Decides whether the vector could be seen by the player if they were to look at it
---------------------------------------------------------------------------*/
function vector:isInSight(filter, ply)
	ply = ply or LocalPlayer()
	local trace = {}
	trace.start = ply:EyePos()
	trace.endpos = self
	trace.filter = filter
	trace.mask = -1
	local TheTrace = util.TraceLine(trace)

	return not TheTrace.Hit, TheTrace.HitPos
end

/*---------------------------------------------------------------------------
Turn a money amount into a pretty string
---------------------------------------------------------------------------*/
local function attachCurrency(str)
	return config.currencyLeft and config.currency .. str or str .. config.currency
end

function DarkRP.formatMoney(n)
	if not n then return attachCurrency("0") end

	if n >= 1e14 then return attachCurrency(tostring(n)) end

	n = tostring(n)
	local sep = sep or ","
	local dp = string.find(n, "%.") or #n+1

	for i=dp-4, 1, -3 do
		n = n:sub(1, i) .. sep .. n:sub(i+1)
	end

	return attachCurrency(n)
end

/*---------------------------------------------------------------------------
Find a player based on given information
---------------------------------------------------------------------------*/
function DarkRP.findPlayer(info)
	if not info or info == "" then return nil end
	local pls = player.GetAll()

	for k = 1, #pls do -- Proven to be faster than pairs loop.
		local v = pls[k]
		if tonumber(info) == v:UserID() then
			return v
		end

		if info == v:SteamID() then
			return v
		end

		if string.find(string.lower(v:SteamName()), string.lower(tostring(info)), 1, true) ~= nil then
			return v
		end

		if string.find(string.lower(v:Name()), string.lower(tostring(info)), 1, true) ~= nil then
			return v
		end
	end
	return nil
end

/*---------------------------------------------------------------------------
Find multiple players based on a string criterium
Taken from FAdmin
---------------------------------------------------------------------------*/
function DarkRP.findPlayers(info)
	if not info then return nil end
	local pls = player.GetAll()
	local found = {}
	local players

	if string.lower(info) == "*" or string.lower(info) == "<all>" then return pls end

	local InfoPlayers = {}
	for A in string.gmatch(info..";", "([a-zA-Z0-9:_.]*)[;(,%s)%c]") do
		if A ~= "" then table.insert(InfoPlayers, A) end
	end

	for _, PlayerInfo in pairs(InfoPlayers) do
		-- Playerinfo is always to be treated as UserID when it's a number
		-- otherwise people with numbers in their names could get confused with UserID's of other players
		if tonumber(PlayerInfo) then
			if IsValid(Player(PlayerInfo)) and not found[Player(PlayerInfo)] then
				found[Player(PlayerInfo)] = true
				players = players or {}
				table.insert(players, Player(PlayerInfo))
			end
			continue
		end

		for k, v in pairs(pls) do
			-- Prevend duplicates
			if found[v] then continue end

			-- Find by Steam ID
			if (PlayerInfo == v:SteamID() or v:SteamID() == "UNKNOWN") or
			-- Find by Partial Nick
			string.find(string.lower(v:Name()), string.lower(tostring(PlayerInfo)), 1, true) ~= nil or
			-- Find by steam name
			(v.SteamName and string.find(string.lower(v:SteamName()), string.lower(tostring(PlayerInfo)), 1, true) ~= nil) then
				found[v] = true
				players = players or {}
				table.insert(players, v)
			end
		end
	end

	return players
end

/*---------------------------------------------------------------------------
Custom error function.
Because the default error function doesn't allow levels anymore apparently
---------------------------------------------------------------------------*/
function DarkRP.error(err, level)
	if not tonumber(level) then return DarkRP.error("The second parameter to DarkRP.error must be a number", 2) end

	level = level + 1 -- Ignore this level
	local info = debug.getinfo(2, "Sln")
	local txt = {string.format("\n[ERROR] %s:%i: %s", info.short_src, info.currentline, err)}
	local i = 1

	info = debug.getinfo(level, "Sln")
	while info do
		local name = info.name ~= nil and info.name or "unknown"
		txt[#txt + 1] = string.format("%s%i. %s - %s:%i", string.rep(" ", i), i, name, info.short_src, info.currentline)
		i = i + 1
		level = level + 1
		info = debug.getinfo(level, "Sln")
	end

	Error(table.concat(txt, "\n") .. "\n")
	error("THIS IS A DUMMY ERROR.\nError handling is fucked because of a bug in gmod.\nThere's an error right above this one.\nThat's the one you need.\nThis error is to be IGNORED.\nDon't start whining about this dummy error on the GitHub issue tracker or I'll fucking hurt you.\nThe error above this one is the one you need.")
end

function meta:getEyeSightHitEntity(searchDistance, hitDistance, filter)
	searchDistance = searchDistance or 100
	hitDistance = hitDistance or 15
	filter = filter or function(p) return p:IsPlayer() and p ~= self end

	local shootPos = self:GetShootPos()
	local entities = ents.FindInSphere(shootPos, searchDistance)
	local aimvec = self:GetAimVector()
	local eyeVector = shootPos + aimvec * searchDistance

	local smallestDistance = math.huge
	local foundEnt

	for k, ent in pairs(entities) do
		if not IsValid(ent) or filter(ent) == false then continue end

		local center = ent:GetPos()

		-- project the center vector on the aim vector
		local projected = shootPos + (center - shootPos):Dot(aimvec) * aimvec

		-- the point on the model that has the smallest distance to your line of sight
		local nearestPoint = ent:NearestPoint(projected)
		local distance = nearestPoint:Distance(projected)

		if distance < smallestDistance then
			local trace = {
				start = self:GetShootPos(),
				endpos = nearestPoint,
				filter = {self, ent}
			}
			local traceLine = util.TraceLine(trace)
			if traceLine.Hit then continue end

			smallestDistance = distance
			foundEnt = ent
		end
	end

	if smallestDistance < hitDistance then
		return foundEnt, smallestDistance
	end

	return nil
end

/*---------------------------------------------------------------------------
Print the currently available vehicles
---------------------------------------------------------------------------*/
local function GetAvailableVehicles(ply)
	if SERVER and IsValid(ply) and not ply:IsAdmin() then return end
	local print = SERVER and ServerLog or Msg

	print(DarkRP.getPhrase("rp_getvehicles") .. "\n")
	for k,v in pairs(DarkRP.getAvailableVehicles()) do
		print("\""..k.."\"" .. "\n")
	end
end
if SERVER then
	concommand.Add("rp_getvehicles_sv", GetAvailableVehicles)
else
	concommand.Add("rp_getvehicles", GetAvailableVehicles)
end

/*---------------------------------------------------------------------------
Whether a player has a DarkRP privilege
---------------------------------------------------------------------------*/
function meta:hasDarkRPPrivilege(priv)
	if FAdmin then
		return FAdmin.Access.PlayerHasPrivilege(self, priv)
	end
	return self:IsAdmin()
end

/*---------------------------------------------------------------------------
Convenience function to return the players sorted by name
---------------------------------------------------------------------------*/
function DarkRP.nickSortedPlayers()
	local plys = player.GetAll()
	table.sort(plys, function(a,b) return a:Nick() < b:Nick() end)
	return plys
end
