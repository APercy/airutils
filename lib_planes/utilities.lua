dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "global_definitions.lua")
dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "hud.lua")

function airutils.properties_copy(origin_table)
    local tablecopy = {}
    for k, v in pairs(origin_table) do
      tablecopy[k] = v
    end
    return tablecopy
end

function airutils.get_hipotenuse_value(point1, point2)
    return math.sqrt((point1.x - point2.x) ^ 2 + (point1.y - point2.y) ^ 2 + (point1.z - point2.z) ^ 2)
end

function airutils.dot(v1,v2)
	return v1.x*v2.x+v1.y*v2.y+v1.z*v2.z
end

function airutils.sign(n)
	return n>=0 and 1 or -1
end

function airutils.minmax(v,m)
	return math.min(math.abs(v),m)*airutils.sign(v)
end

function airutils.get_gauge_angle(value, initial_angle)
    initial_angle = initial_angle or 90
    local angle = value * 18
    angle = angle - initial_angle
    angle = angle * -1
	return angle
end

-- attach player
function airutils.attach(self, player, instructor_mode)
    instructor_mode = instructor_mode or false
    local name = player:get_player_name()
    self.driver_name = name

    -- attach the driver
    local eye_y = 0
    if instructor_mode == true then
        eye_y = -2.5
        player:set_attach(self.passenger_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    else
        eye_y = -4
        player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    end
    if airutils.detect_player_api(player) == 1 then
        eye_y = eye_y + 6.5
    end

    player:set_eye_offset({x = 0, y = eye_y, z = 2}, {x = 0, y = 1, z = -30})
    player_api.player_attached[name] = true
    player_api.set_animation(player, "sit")
    -- make the driver sit
    minetest.after(1, function()
        if player then
            --minetest.chat_send_all("okay")
            airutils.sit(player)
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

-- attach passenger
function airutils.attach_pax(self, player)
    local name = player:get_player_name()
    self._passenger = name

    -- attach the driver
    local eye_y = 0
    if self._instruction_mode == true then
        eye_y = -4
        player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    else
        eye_y = -2.5
        player:set_attach(self.passenger_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    end
    if airutils.detect_player_api(player) == 1 then
        eye_y = eye_y + 6.5
    end

    player:set_eye_offset({x = 0, y = eye_y, z = 2}, {x = 0, y = 1, z = -30})
    player_api.player_attached[name] = true
    player_api.set_animation(player, "sit")
    -- make the driver sit
    minetest.after(1, function()
        player = minetest.get_player_by_name(name)
        if player then
            airutils.sit(player)
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

function airutils.dettachPlayer(self, player)
    local name = self.driver_name
    airutils.setText(self, self.infotext)

    airutils.remove_hud(player)

    --self._engine_running = false

    -- driver clicked the object => driver gets off the vehicle
    self.driver_name = nil

    -- detach the player
    --player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
    player:set_detach()
    player_api.player_attached[name] = nil
    player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    player_api.set_animation(player, "stand")
    self.driver = nil
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
end

function airutils.dettach_pax(self, player)
    local name = self._passenger

    -- passenger clicked the object => driver gets off the vehicle
    self._passenger = nil

    -- detach the player
    --player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
    if player then
        player:set_detach()
        player_api.player_attached[name] = nil
        player_api.set_animation(player, "stand")
        player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
    end
end

function airutils.checkAttach(self, player)
    if player then
        local player_attach = player:get_attach()
        if player_attach then
            if player_attach == self.pilot_seat_base or player_attach == self.passenger_seat_base then
                return true
            end
        end
    end
    return false
end

-- destroy the boat
function airutils.destroy(self)
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self._passenger then
        -- detach the passenger
        local passenger = minetest.get_player_by_name(self._passenger)
        if passenger then
            airutils.dettach_pax(self, passenger)
        end
    end

    if self.driver_name then
        -- detach the driver
        local player = minetest.get_player_by_name(self.driver_name)
        airutils.dettachPlayer(self, player)
    end

    local pos = self.object:get_pos()
    if self.fuel_gauge then self.fuel_gauge:remove() end
    if self.power_gauge then self.power_gauge:remove() end
    if self.climb_gauge then self.climb_gauge:remove() end
    if self.speed_gauge then self.speed_gauge:remove() end
    if self.engine then self.engine:remove() end
    if self.pilot_seat_base then self.pilot_seat_base:remove() end
    if self.passenger_seat_base then self.passenger_seat_base:remove() end

    if self.stick then self.stick:remove() end

    airutils.destroy_inventory(self)
    self.object:remove()

    --[[pos.y=pos.y+2
    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'hidroplane:wings')

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:steel_ingot')
    end

    for i=1,2 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'wool:white')
    end

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:mese_crystal')
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:diamond')
    end]]--

    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'hidroplane:hidro')
end

function airutils.testImpact(self, velocity, position)
    local p = position --self.object:get_pos()
    local collision = false
    if self._last_vel == nil then return end
    --lets calculate the vertical speed, to avoid the bug on colliding on floor with hard lag
    if abs(velocity.y - self._last_vel.y) > 2 then
		local noded = airutils.nodeatpos(airutils.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
		    collision = true
	    else
            self.object:set_velocity(self._last_vel)
            --self.object:set_acceleration(self._last_accell)
            self.object:set_velocity(vector.add(velocity, vector.multiply(self._last_accell, self.dtime/8)))
        end
    end
    local impact = abs(airutils.get_hipotenuse_value(velocity, self._last_vel))
    --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
    if impact > 2 then
        --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
        if self.colinfo then
            collision = self.colinfo.collides
        end
    end

    if impact > 1.2  and self._longit_speed > 2 then
        local noded = airutils.nodeatpos(airutils.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
            minetest.sound_play("airutils_touch", {
                --to_player = self.driver_name,
                object = self.object,
                max_hear_distance = 15,
                gain = 1.0,
                fade = 0.0,
                pitch = 1.0,
            }, true)
	    end
    end

    if collision then
        --self.object:set_velocity({x=0,y=0,z=0})
        local damage = impact / 2
        self.hp_max = self.hp_max - damage --subtract the impact value directly to hp meter
        minetest.sound_play(self._collision_sound, {
            --to_player = self.driver_name,
            object = self.object,
            max_hear_distance = 15,
            gain = 1.0,
            fade = 0.0,
            pitch = 1.0,
        }, true)

        if self.driver_name then
            local player_name = self.driver_name
            airutils.setText(self, self.infotext)

            --minetest.chat_send_all('damage: '.. damage .. ' - hp: ' .. self.hp_max)
            if self.hp_max < 0 then --if acumulated damage is greater than 50, adieu
                airutils.destroy(self)
            end

            local player = minetest.get_player_by_name(player_name)
            if player then
		        if player:get_hp() > 0 then
			        player:set_hp(player:get_hp()-(damage/2))
		        end
            end
            if self._passenger ~= nil then
                local passenger = minetest.get_player_by_name(self._passenger)
                if passenger then
		            if passenger:get_hp() > 0 then
			            passenger:set_hp(passenger:get_hp()-(damage/2))
		            end
                end
            end
        end

    end
end

function airutils.checkattachBug(self)
    -- for some engine error the player can be detached from the submarine, so lets set him attached again
    if self.owner and self.driver_name then
        -- attach the driver again
        local player = minetest.get_player_by_name(self.owner)
        if player then
		    if player:get_hp() > 0 then
                airutils.attach(self, player, self._instruction_mode)
            else
                airutils.dettachPlayer(self, player)
		    end
        else
            if self._passenger ~= nil and self._command_is_given == false then
                self._autopilot = false
                airutils.transfer_control(self, true)
            end
        end
    end
end

function airutils.engineSoundPlay(self)
    --sound
    if self.sound_handle then minetest.sound_stop(self.sound_handle) end
    if self.object then
        self.sound_handle = minetest.sound_play({name = self._engine_sound},
            {object = self.object, gain = 2.0,
                pitch = 0.5 + ((self._power_lever/100)/2),
                max_hear_distance = 15,
                loop = true,})
    end
end

function airutils.engine_set_sound_and_animation(self)
    --minetest.chat_send_all('test1 ' .. dump(self._engine_running) )
    if self._engine_running then
        if self._last_applied_power ~= self._power_lever then
            --minetest.chat_send_all('test2')
            self._last_applied_power = self._power_lever
            self.object:set_animation_frame_speed(60 + self._power_lever)
            airutils.engineSoundPlay(self)
        end
    else
        if self.sound_handle then
            minetest.sound_stop(self.sound_handle)
            self.sound_handle = nil
            self.object:set_animation_frame_speed(0)
        end
    end
end


