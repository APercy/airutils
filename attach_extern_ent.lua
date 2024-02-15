local S = airutils.S

local function attach_entity(self, target_obj, dest_pos, relative_pos, entity_name, inv_id)
    if not target_obj then return end
    if self.object then
        local ent = target_obj:get_luaentity()
        if self._vehicle_custom_data then
            target_obj:set_pos(dest_pos)
            target_obj:set_attach(self.object,'',relative_pos,{x=0,y=0,z=0})
            self._vehicle_custom_data.simple_external_attach_entity = entity_name
            self._vehicle_custom_data.simple_external_attach_pos = relative_pos
            self._vehicle_custom_data.simple_external_attach_invid = inv_id --why?! Because I can identify the target entity by it's inventory ;)
        end
    end
end

function airutils.dettach_entity(self)
    if not self._vehicle_custom_data then return end
    if not self._vehicle_custom_data.simple_external_attach_entity then return end
    local entity_name = self._vehicle_custom_data.simple_external_attach_entity
    local relative_pos = self._vehicle_custom_data.simple_external_attach_pos
    local inv_id = self._vehicle_custom_data.simple_external_attach_invid

    local pos = self.object:get_pos()
    local velocity = self.object:get_velocity()
    local nearby_objects = minetest.get_objects_inside_radius(pos, 32)
	for i,obj in ipairs(nearby_objects) do	
        local ent = obj:get_luaentity()
        if ent then
            if ent._inv_id then
                if ent._inv_id == inv_id then
                    local rotation = self.object:get_rotation()
                    local direction = rotation.y

                    local move = -1*relative_pos.z/10
                    pos.x = pos.x + move * math.sin(direction)
                    pos.z = pos.z + move * math.cos(direction)
                    pos.y = pos.y + self.initial_properties.collisionbox[2] - ent.initial_properties.collisionbox[2]
                    obj:set_detach()
                    obj:set_pos(pos)
                    obj:set_rotation(rotation)
                    obj:set_velocity(velocity)
                    --clear
                    self._vehicle_custom_data.simple_external_attach_entity = nil
                    self._vehicle_custom_data.simple_external_attach_pos = nil
                    self._vehicle_custom_data.simple_external_attach_invid = nil
                    break
                end
            end
        end
	end
end

function airutils.simple_external_attach(self, relative_pos, entity_name, radius)
    radius = radius or 12
    if self.object then
        local pos = self.object:get_pos()
        local nearby_objects = minetest.get_objects_inside_radius(pos, radius)
		for i,obj in ipairs(nearby_objects) do	
			if obj == self.object then
				table.remove(nearby_objects,i)
			end
            local ent = obj:get_luaentity()
            if ent then
                if ent.name == entity_name then
                    local dest_pos = vector.new(pos)
                    dest_pos = vector.add(dest_pos, relative_pos)
                    attach_entity(self, nearby_objects[i], dest_pos, relative_pos, entity_name, ent._inv_id)
                    return
                end
            end
		end
    end
end

--execute on load
function airutils.restore_external_attach(self)
    if not self._vehicle_custom_data then return end
    if not self._vehicle_custom_data.simple_external_attach_invid then return end
    
    local pos = self.object:get_pos()
    local dest_pos = vector.new(pos)
    local entity_name = self._vehicle_custom_data.simple_external_attach_entity
    local relative_pos = self._vehicle_custom_data.simple_external_attach_pos
    local inv_id = self._vehicle_custom_data.simple_external_attach_invid
    dest_pos = vector.add(dest_pos, relative_pos)

    minetest.after(0.3, function()
        local nearby_objects = minetest.get_objects_inside_radius(pos, 32)
        local ent
	    for i,obj in ipairs(nearby_objects) do
            ent = obj:get_luaentity()
            if ent then
                --minetest.chat_send_all(dump(ent.name))
                if ent._inv_id then
                    --minetest.chat_send_all(">> "..dump(ent._inv_id).." >> "..dump(inv_id))
                    if ent._inv_id == inv_id then
                        --minetest.chat_send_all("++ "..dump(ent._inv_id).." ++ "..dump(inv_id))
                        local target_obj = nearby_objects[i]
                        target_obj:set_pos(dest_pos)
                        target_obj:set_attach(self.object,'',relative_pos,{x=0,y=0,z=0})
                        --attach_entity(self, nearby_objects[i], dest_pos, relative_pos, entity_name, inv_id)
                        return
                    end
                end
            end
	    end
    end)

    --clear
    --self._vehicle_custom_data.simple_external_attach_entity = nil
    --self._vehicle_custom_data.simple_external_attach_pos = nil
    --self._vehicle_custom_data.simple_external_attach_invid = nil
end

minetest.register_chatcommand("remove_hook", {
    params = "",
    description = S("Dettach current vehicle from another"),
    privs = {interact=true},
	func = function(name, param)
        local colorstring = core.colorize('#ff0000', S(" >>> you are not inside a plane"))
        local player = minetest.get_player_by_name(name)
        local attached_to = player:get_attach()

		if attached_to ~= nil then
            local seat = attached_to:get_attach()
            if seat ~= nil then
                local entity = seat:get_luaentity()
                if entity then
                    if entity.on_step == airutils.on_step then
                        local rem_obj = entity.object:get_attach()
                        if not rem_obj then
                            minetest.chat_send_player(name,core.colorize('#ff0000', S(" >>> no hook found")))
                            return
                        end
                        local rem_ent = rem_obj:get_luaentity()

                        local pos = rem_ent.object:get_pos()
                        local rotation = rem_ent.object:get_rotation()
                        local direction = rotation.y
                        local velocity = rem_ent.object:get_velocity()

                        local move = -1*rem_ent._vehicle_custom_data.simple_external_attach_pos.z/10
                        pos.x = pos.x + move * math.sin(direction)
                        pos.z = pos.z + move * math.cos(direction)
                        pos.y = pos.y + rem_ent.initial_properties.collisionbox[2] - entity.initial_properties.collisionbox[2]
                        entity.object:set_detach()
                        entity.object:set_pos(pos)
                        entity.object:set_rotation(rotation)
                        entity.object:set_velocity(velocity)
                        --clear
                        rem_ent._vehicle_custom_data.simple_external_attach_entity = nil
                        rem_ent._vehicle_custom_data.simple_external_attach_pos = nil
                        rem_ent._vehicle_custom_data.simple_external_attach_invid = nil
                    else
			            minetest.chat_send_player(name,colorstring)
                    end
                end
            end
		else
			minetest.chat_send_player(name,colorstring)
		end
	end
})
