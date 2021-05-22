local function try_raycast(pos, look_dir)
	local raycast = minetest.raycast(pos, look_dir, true, false)
	local pointed = raycast:next()
    while pointed do
	    if pointed and pointed.type == "object" and pointed.ref and not pointed.ref:is_player() then
            return pointed.ref
	    end
        pointed = raycast:next()
    end
end

minetest.register_tool("airutils:tug", {
	description = "Tug tool for airport",
	inventory_image = "airutils_tug.png",
	stack_max=1,
	on_use = function(itemstack, player, pointed_thing)
		if not player then
			return
		end

	    --[[local pos = player:get_pos()
	    local pname = player:get_player_name()

        local look_dir = player:get_look_dir()
        local object = try_raycast(pos, look_dir)
        if object then
            if object:get_attach() then
                local dir = player:get_look_dir()
                minetest.chat_send_all('detach')
                object:set_detach()
                object:set_rotation(dir)
            else
                minetest.chat_send_all('object found')
                object:set_attach(player, "", {x=0, y=0, z=20})
            end
        end]]--
	end,

    --[[on_secondary_use = function(itemstack, user, pointed_thing)
        local object = user:get_attach()
        if object then user:set_detach() end
    end,]]--

	sound = {breaks = "default_tool_breaks"},
})
