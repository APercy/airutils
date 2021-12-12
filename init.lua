-- Minetest 5.4.1 : airutils

airutils = {}

dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "airutils_papi.lua")
dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "airutils_tug.lua")
dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "airutils_repair.lua")

function airutils.remove(pos)
	local meta = core.get_meta(pos)
	if meta:get_string("dont_destroy") == "true" then
		-- when swapping it
		return
	end
end

function airutils.canDig(pos, player)
	local meta = core.get_meta(pos)
	return meta:get_string("dont_destroy") ~= "true"
		and player:get_player_name() == meta:get_string("owner")
end



