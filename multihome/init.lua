-- multihome/init.lua

multihome = {}

max = 10


---
--- Load old homes from the homes file
---

local homes_file = minetest.get_worldpath() .. "/homes"
local oldhomes   = {}

local function old_loadhomes()
	local input = io.open(homes_file, "r")
	if not input then
		return -- no longer an error
	end

	-- Iterate over all stored positions in the format "x y z player" for each line
	for pos, name in input:read("*a"):gmatch("(%S+ %S+ %S+)%s([%w_-]+)[\r\n]") do
		oldhomes[name] = minetest.string_to_pos(pos)
	end
	input:close()
end

old_loadhomes()

---
--- API
---

-- [local function] Check attribute
local function check_attr(player)
	if not player:get_attribute("multihome") then
		player:set_attribute("multihome", minetest.serialize({}))
	end
end

-- [local function] Count homes
local function count_homes(list)
	local count = 0
	for _, h in pairs(list) do
		count = count + 1
	end
	return count
end

-- [function] Set home
function multihome.set(player, name, pos)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local pos   = pos or vector.round(player:getpos())
	local homes = minetest.deserialize(player:get_attribute("multihome"))

	local max = 10
	
	-- if home doesn't already exist (i.e. a new home is being created), check for space
	if not homes[name] and count_homes(homes) >= max then
		return false, "Too many homes. Remove one with /multihome del <name> or /delhome <name>"
	end

	homes[name] = pos
	player:set_attribute("multihome", minetest.serialize(homes))

	return true, "Set home \""..name.."\" to "..minetest.pos_to_string(pos)
end

-- [function] Remove home
function multihome.remove(player, name)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local homes = minetest.deserialize(player:get_attribute("multihome"))
	if homes[name] then
		homes[name] = nil
		player:set_attribute("multihome", minetest.serialize(homes))
		return true, "Removed home \""..name.."\""
	else
		return false, "Home \""..name.."\" does not exist!"
	end
end

-- [function] Get home position
function multihome.get(player, name)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local homes = minetest.deserialize(player:get_attribute("multihome"))
	return homes[name]
end

-- [function] Get player's default home
function multihome.get_default(player)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local default
	local count = 0
	local homes = minetest.deserialize(player:get_attribute("multihome"))
	for home, pos in pairs(homes) do
		count = count + 1
		default = home
	end

	if count == 1 then
		return default
	end
end

-- [function] List homes
function multihome.list(player)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local homes = minetest.deserialize(player:get_attribute("multihome"))
	if homes then
		local list = "None"
		for name, h in pairs(homes) do
			if list == "None" then
				list = name.." "..minetest.pos_to_string(h)
			else
				list = list..", "..name.." "..minetest.pos_to_string(h)
			end
		end
		return true, "Your Homes ("..count_homes(homes).."/"..max.."): "..list
	end
end

-- [function] Go to home
function multihome.go(player, name)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local pos = multihome.get(player, name)
	if pos then
		player:setpos(pos)
		return true, "Teleported to home \""..name.."\""
	else
		local homes = minetest.deserialize(player:get_attribute("multihome"))
		if not homes then
			return false, "Set a home using /multihome set <name> or /sethome <name>"
		else
			return false, "Invalid home \""..name.."\""
		end
	end
end

---
--- Registrations
---

-- [event] On join player
minetest.register_on_joinplayer(function(player)
	-- Check attributes
	check_attr(player)

	-- Check if homes need to be imported
	if import == "true" and (compat == "deprecate" or compat == "override")
			and player:get_attribute("multihome:imported") ~= "true" then
		local name = player:get_player_name()
		local pos = minetest.string_to_pos(player:get_attribute("sethome:home")) or oldhomes[name]
		if pos then
			-- Set multihome entry
			multihome.set(player, "default", pos)
			-- Set imported attribute
			player:set_attribute("multihome:imported", "true")
		end
	end
end)

-- Compatibility mode: none or deprecate
if compat == "none" or compat == "deprecate" then

	-- [privilege] Multihome
	minetest.register_privilege("home", {
		description = "Can use homes",
		give_to_singleplayer = true,
	})




end

	minetest.register_chatcommand("home", {
		description = "Teleport you to one of your home points (related: /sethome, /delhome, /listhomes)",
		params = "<home name>",
		func = function(name, param)
			if param and param ~= "" then
				return multihome.go(name, param)
			else
				local home = multihome.get_default(name)
				if home then
					return multihome.go(name, home)
				end

				return false, "Invalid parameters (see /help home or /listhomes)"
			end
		end,
	})

	minetest.register_chatcommand("sethome", {
		description = "Set or update one of your home points (related: /home, /delhome, /listhomes)",
		params = "<home name>",
		func = function(name, param)
			if param and param ~= "" then
				return multihome.set(name, param)
			else
				return false, "Invalid parameters (see /help sethome)"
			end
		end,
	})

	minetest.register_chatcommand("delhome", {
		description = "Delete one of your home points (related: /home, /sethome, /listhomes)",
		params = "<home name>",
		privs = {home=true},
		func = function(name, param)
			if param and param ~= "" then
				return multihome.remove(name, param)
			else
				return false, "Invalid parameters (see /help delhome or /listhomes)"
			end
		end,
	})

	minetest.register_chatcommand("listhomes", {
		description = "List all of your home points (related: /home, /sethome, /delhome)",
		privs = {home=true},
		func = function(name)
			return multihome.list(name)
		end,
	})

