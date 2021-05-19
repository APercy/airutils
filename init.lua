-- Minetest 5.4.1 : light_systems

light_systems = {}

function light_systems.PAPIplace(player,pos)
	local dir = minetest.dir_to_facedir(player:get_look_dir())
	local pos1 = vector.new(pos)
	core.set_node(pos, {name="light_systems:papi", param2=dir})
	local player_name = player:get_player_name()
	local meta = core.get_meta(pos)
	meta:set_string("infotext", "PAPI\rOwned by: "..player_name)
	meta:set_string("owner", player_name)
	meta:set_string("dont_destroy", "false")
	return true
end

function light_systems.remove(pos)
	local meta = core.get_meta(pos)
	if meta:get_string("dont_destroy") == "true" then
		-- when swapping it
		return
	end
end

function light_systems.canDig(pos, player)
	local meta = core.get_meta(pos)
	return meta:get_string("dont_destroy") ~= "true"
		and player:get_player_name() == meta:get_string("owner")
end

light_systems.collision_box = {
	type = "fixed",
	fixed={{-0.5,-0.5,-0.5,0.5,-0.42,0.5},},
}

light_systems.selection_box = {
	type = "fixed",
	fixed={{-0.5,-0.5,-0.5,0.5,1.5,0.5},},
}

light_systems.groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2}


minetest.register_node("light_systems:papi",{
	description = "PAPI",
	inventory_image = "papi.png",
	wield_image = "papi.png",
	tiles = {"light_systems_black.png", "light_systems_u_black.png", "light_systems_white.png",
	"light_systems_metal.png", {name = "light_systems_red.png", backface_culling = true},},
	groups = light_systems.groups,
	paramtype2 = "facedir",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "papi.b3d",
	visual_scale = 1.0,
	light_source = 13,
    backface_culling = true,
	selection_box = light_systems.selection_box,
	collision_box = light_systems.collision_box,
	can_dig = light_systems.canDig,
    _color = "",
	on_destruct = light_systems.remove,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if light_systems.PAPIplace(placer,pos)==true then
			itemstack:take_item(1)
			return itemstack
		else
			return
		end
	end,
	--on_rightclick=light_systems.gateFormspecHandler,
    on_punch = function(pos, node, puncher, pointed_thing)
	    local player_name = puncher:get_player_name()
        local meta = core.get_meta(pos)
	    if player_name ~= meta:get_string("owner") then
		    return
	    end

        local itmstck=puncher:get_wielded_item()
        local item_name = ""
        if itmstck then item_name = itmstck:get_name() end

    end,
})





