-- Minetest 5.4.1 : airutils

airutils = {}

function airutils.PAPIplace(player,pos)
	local dir = minetest.dir_to_facedir(player:get_look_dir())
	local pos1 = vector.new(pos)
	core.set_node(pos, {name="airutils:papi", param2=dir})
	local player_name = player:get_player_name()
	local meta = core.get_meta(pos)
	meta:set_string("infotext", "PAPI\rOwned by: "..player_name)
	meta:set_string("owner", player_name)
	meta:set_string("dont_destroy", "false")
	return true
end

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

function airutils.togglePapiSide(pos, node, clicker, itemstack)
	local player_name = clicker:get_player_name()
	local meta = core.get_meta(pos)

    if player_name ~= meta:get_string("owner") then
	    return
    end

    local dir=node.param2
    if node.name == "airutils:papi_right" then
        core.set_node(pos, {name="airutils:papi", param2=dir})
    	meta:set_string("infotext", "PAPI - left side\rOwned by: "..player_name)
    elseif node.name == "airutils:papi" then
        core.set_node(pos, {name="airutils:papi_right", param2=dir})
        meta:set_string("infotext", "PAPI - right side\rOwned by: "..player_name)
    end

	meta:set_string("owner", player_name)
	meta:set_string("dont_destroy", "false")
end

airutils.collision_box = {
	type = "fixed",
	fixed={{-0.5,-0.5,-0.5,0.5,-0.42,0.5},},
}

airutils.selection_box = {
	type = "fixed",
	fixed={{-0.5,-0.5,-0.5,0.5,1.5,0.5},},
}

airutils.groups_right = {snappy=2,choppy=2,oddly_breakable_by_hand=2,not_in_creative_inventory=1}
airutils.groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2}

minetest.register_node("airutils:papi",{
	description = "PAPI",
	inventory_image = "papi.png",
	wield_image = "papi.png",
	tiles = {"airutils_black.png", "airutils_u_black.png", "airutils_white.png",
	"airutils_metal.png", {name = "airutils_red.png", backface_culling = true},},
	groups = airutils.groups,
	paramtype2 = "facedir",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "papi.b3d",
	visual_scale = 1.0,
	light_source = 13,
    backface_culling = true,
	selection_box = airutils.selection_box,
	collision_box = airutils.collision_box,
	can_dig = airutils.canDig,
    _color = "",
	on_destruct = airutils.remove,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if airutils.PAPIplace(placer,pos)==true then
			itemstack:take_item(1)
			return itemstack
		else
			return
		end
	end,
	on_rightclick=airutils.togglePapiSide,
    on_punch = function(pos, node, puncher, pointed_thing)
	    local player_name = puncher:get_player_name()
        local meta = core.get_meta(pos)
	    if player_name ~= meta:get_string("owner") then
            local privs = minetest.get_player_privs(player_name)
            if privs.server == false then
		        return
            end
	    end

        local itmstck=puncher:get_wielded_item()
        local item_name = ""
        if itmstck then item_name = itmstck:get_name() end

    end,
})

minetest.register_node("airutils:papi_right",{
    description = "PAPI_right_side",
	tiles = {"airutils_black.png", "airutils_u_black.png", "airutils_white.png",
	"airutils_metal.png", {name = "airutils_red.png", backface_culling = true},},
	groups = airutils.groups_right,
	paramtype2 = "facedir",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "papi_right.b3d",
	visual_scale = 1.0,
	light_source = 13,
    backface_culling = true,
	selection_box = airutils.selection_box,
	collision_box = airutils.collision_box,
	can_dig = airutils.canDig,
    _color = "",
	on_destruct = airutils.remove,
	on_rightclick=airutils.togglePapiSide,
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



