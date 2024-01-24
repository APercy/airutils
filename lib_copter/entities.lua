dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "global_definitions.lua")

local function ground_pitch(self, longit_speed, curr_pitch)
    local newpitch = curr_pitch
    if self._last_longit_speed == nil then self._last_longit_speed = 0 end

    -- Estado atual do sistema
    if self._current_value == nil then self._current_value = 0 end -- Valor atual do sistema
    if self._last_error == nil then self._last_error = 0 end -- Último erro registrado

    -- adjust pitch at ground
    if math.abs(longit_speed) < self._tail_lift_max_speed then
        local speed_range = self._tail_lift_max_speed - self._tail_lift_min_speed
        local percentage = 1-((math.abs(longit_speed) - self._tail_lift_min_speed)/speed_range)
        if percentage > 1 then percentage = 1 end
        if percentage < 0 then percentage = 0 end
        local angle = self._tail_angle * percentage
        local rad_angle = math.rad(angle)

        if newpitch < rad_angle then newpitch = rad_angle end --ja aproveita o pitch atual se ja estiver cerrto
        --[[self._current_value = curr_pitch
        local kp = (longit_speed - self._tail_lift_min_speed)/10
        local output, last_error = airutils.pid_controller(self._current_value, rad_angle, self._last_error, self.dtime, kp)
        self._last_error = last_error
        newpitch = output]]--

        if newpitch > math.rad(self._tail_angle) then newpitch = math.rad(self._tail_angle) end --não queremos arrastar o cauda no chão
    end
    
    return newpitch
end

function airutils.logic_heli(self)
    local velocity = self.object:get_velocity()
    local curr_pos = self.object:get_pos()
    self._curr_pos = curr_pos --shared
    self._last_accel = self.object:get_acceleration()

    self._last_time_command = self._last_time_command + self.dtime

    if self._last_time_command > 1 then self._last_time_command = 1 end

    local player = nil
    if self.driver_name then player = minetest.get_player_by_name(self.driver_name) end
    local co_pilot = nil
    if self.co_pilot and self._have_copilot then co_pilot = minetest.get_player_by_name(self.co_pilot) end

    --test collision
    airutils.testImpact(self, velocity, curr_pos)

    local ctrl = nil
    if player then
        ctrl = player:get_player_control()
        ---------------------
        -- change the driver
        ---------------------
        if co_pilot and self._have_copilot and self._last_time_command >= 1 then
            if self._command_is_given == true then
                if ctrl.sneak or ctrl.jump or ctrl.up or ctrl.down or ctrl.right or ctrl.left then
                    self._last_time_command = 0
                    --take the control
                    airutils.transfer_control(self, false)
                end
            else
                if ctrl.sneak == true and ctrl.jump == true then
                    self._last_time_command = 0
                    --trasnfer the control to student
                    airutils.transfer_control(self, true)
                end
            end
        end
    end


    if not self.object:get_acceleration() then return end
    local accel_y = self.object:get_acceleration().y
    local rotation = self.object:get_rotation()
    local yaw = rotation.y
	local newyaw=yaw
    local pitch = rotation.x
	local roll = rotation.z

    local hull_direction = airutils.rot_to_dir(rotation) --minetest.yaw_to_dir(yaw)
    local nhdir = {x=hull_direction.z,y=0,z=-hull_direction.x}		-- lateral unit vector

    local longit_speed = vector.dot(velocity,hull_direction)
    self._longit_speed = longit_speed

    local longit_drag = vector.multiply(hull_direction,longit_speed*
            longit_speed*self._longit_drag_factor*-1*airutils.sign(longit_speed))
	local later_speed = airutils.dot(velocity,nhdir)
    --minetest.chat_send_all('later_speed: '.. later_speed)
	local later_drag = vector.multiply(nhdir,later_speed*later_speed*
            self._later_drag_factor*-1*airutils.sign(later_speed))
    local accel = vector.add(longit_drag,later_drag)
    local stop = false

    local node_bellow = airutils.nodeatpos(airutils.pos_shift(curr_pos,{y=-1.3}))
    local is_flying = true
    if self.colinfo then
        is_flying = (not self.colinfo.touching_ground) and (self.isinliquid == false)
    end
    --if is_flying then minetest.chat_send_all('is flying') end

    local is_attached = airutils.checkAttach(self, player)
    if self._indicated_speed == nil then self._indicated_speed = 0 end

	if not is_attached then
        -- for some engine error the player can be detached from the machine, so lets set him attached again
        airutils.checkattachBug(self)
    end

    if self._custom_step_additional_function then
        self._custom_step_additional_function(self)
    end

    --landing light
    if self._have_landing_lights then
        airutils.landing_lights_operate(self)
    end

    --smoke and fire
    if self._engine_running then
        local curr_health_percent = (self.hp_max * 100)/self._max_plane_hp
        if curr_health_percent < 20 then
            airutils.add_smoke_trail(self, 2)
        elseif curr_health_percent < 50 then
            airutils.add_smoke_trail(self, 1)
        end
    else
        if self._smoke_spawner and not self._smoke_semaphore then
            self._smoke_semaphore = 1 --to set it only one time
            minetest.after(5, function()
                if self._smoke_spawner then
                    minetest.delete_particlespawner(self._smoke_spawner)
                    self._smoke_spawner = nil
                    self._smoke_semaphore = nil
                end
            end)
        end
    end

    if (math.abs(velocity.x) < 0.1 and math.abs(velocity.z) < 0.1) and is_flying == false and is_attached == false and self._engine_running == false then
        if self._ground_friction then
            if not self.isinliquid then self.object:set_velocity({x=0,y=airutils.gravity*self.dtime,z=0}) end
        end
        return
    end

    --adjust climb indicator
    local y_velocity = 0
    if self._engine_running or is_flying then y_velocity = velocity.y end
    local climb_rate =  y_velocity
    if climb_rate > 5 then climb_rate = 5 end
    if climb_rate < -5 then
        climb_rate = -5
    end

    -- pitch and roll
    local newroll = 0
    local newpitch = 0
    if ctrl and is_flying then
        local command_angle = math.rad(8)
        if ctrl.up then newpitch = -command_angle end
        if ctrl.down then newpitch = command_angle end
        if ctrl.left then newroll = -command_angle end
        if ctrl.right then newroll = command_angle end
    end

    -- new yaw
	if math.abs(self._rudder_angle)>1.5 then
        local turn_rate = math.rad(self._yaw_turn_rate)
        local yaw_turn = self.dtime * math.rad(self._rudder_angle) * turn_rate * 4
		newyaw = yaw + yaw_turn
	end

    ---------------------------------
    -- end roll

    local pilot = player
    if self._have_copilot then
        if self._command_is_given and co_pilot then
            pilot = co_pilot
        else
            self._command_is_given = false
        end
    end

    ------------------------------------------------------
    --accell calculation block
    ------------------------------------------------------
    if is_attached or co_pilot then
        accel, stop = airutils.heli_control(self, self.dtime, hull_direction,
            longit_speed, longit_drag, nhdir, later_speed, later_drag, accel, pilot, is_flying)
    end
    --end accell

    --get disconnected players
    airutils.rescueConnectionFailedPassengers(self)

    if accel == nil then accel = {x=0,y=0,z=0} end

    --lift calculation
    accel.y = accel_y

    --lets apply some bob in water
	if self.isinliquid then
        local bob = airutils.minmax(airutils.dot(accel,hull_direction),0.02)	-- vertical bobbing
        if bob < 0 then bob = 0 end
        accel.y = accel.y + bob
        local max_pitch = 6
        local ref_speed = longit_speed * 20
        if ref_speed < 0 then ref_speed = 0 end
        local h_vel_compensation = ((ref_speed * 100)/max_pitch)/100
        if h_vel_compensation < 0 then h_vel_compensation = 0 end
        if h_vel_compensation > max_pitch then h_vel_compensation = max_pitch end
        --minetest.chat_send_all(h_vel_compensation)
        newpitch = newpitch + (velocity.y * math.rad(max_pitch - h_vel_compensation))
    end

    local ceiling = 5000
    local blade_speed = self._rotor_speed or 15
    local limit = 10
    if self._engine_running == false then blade_speed = self._rotor_idle_speed or 12 end
    local new_accel = airutils.getLiftAccel(self, {x=0, y=velocity.y, z=blade_speed}, {x=0, y=accel.y, z=blade_speed/self.dtime}, blade_speed, roll, curr_pos, self._lift, ceiling, self._wing_span)
    local y_accell = new_accel.y
    new_accel = vector.new(accel)
    new_accel.y = y_accell
    if new_accel.y > limit then new_accel.y = limit end --it isn't a rocket :/

    --wind effects
    if airutils.wind and is_flying == true then
        local wind = airutils.get_wind(curr_pos, 0.1)
        new_accel = vector.add(new_accel, wind)
    end

    if stop ~= true then --maybe == nil
        self._last_accell = new_accel
	    self.object:move_to(curr_pos)
        --airutils.set_acceleration(self.object, new_accel)
        local limit = self._climb_speed
        --if new_accel.y > limit then new_accel.y = limit end --it isn't a rocket :/

    else
        if stop == true then
            self._last_accell = vector.new() --self.object:get_acceleration()
            self.object:set_acceleration({x=0,y=0,z=0})
            self.object:set_velocity({x=0,y=0,z=0})
        end
    end

    if self.wheels then
        if is_flying == false then --isn't flying?
            --animate wheels
            local min_speed_animation = 0.1
            if math.abs(velocity.x) > min_speed_animation or math.abs(velocity.z) > min_speed_animation then
                self.wheels:set_animation_frame_speed(longit_speed * 10)
            else
                self.wheels:set_animation_frame_speed(0)
            end
        else
            --stop wheels
            self.wheels:set_animation_frame_speed(0)
        end
    end

    ------------------------------------------------------
    -- end accell
    ------------------------------------------------------

    ------------------------------------------------------
    -- sound and animation
    ------------------------------------------------------
    airutils.engine_set_sound_and_animation(self)

    ------------------------------------------------------

    --self.object:get_luaentity() --hack way to fix jitter on climb

    --GAUGES
    --minetest.chat_send_all('rate '.. climb_rate)
    local climb_angle = airutils.get_gauge_angle(climb_rate)
    self._climb_rate = climb_rate

    local indicated_speed = longit_speed * 0.9
    if indicated_speed < 0 then indicated_speed = 0 end
    self._indicated_speed = indicated_speed
    local speed_angle = airutils.get_gauge_angle(indicated_speed, -45)

    --adjust power indicator
    local power_indicator_angle = airutils.get_gauge_angle(self._power_lever/10) + 90
    local fuel_in_percent = (self._energy * 1)/self._max_fuel
    local energy_indicator_angle = (180*fuel_in_percent)-180    --(airutils.get_gauge_angle((self._max_fuel - self._energy)*2)) - 90

    if is_attached then
        if self._show_hud then
            airutils.update_hud(player, climb_angle, speed_angle, power_indicator_angle, energy_indicator_angle)
        else
            airutils.remove_hud(player)
        end
    end

    if is_flying == false then
	    newyaw = yaw
    end

    if player and self._use_camera_relocation then
        --minetest.chat_send_all(dump(newroll))
        local new_eye_offset = airutils.camera_reposition(player, newpitch, newroll)
        player:set_eye_offset(new_eye_offset, {x = 0, y = 1, z = -30})
    end

    --apply rotations
    self.object:set_rotation({x=newpitch,y=newyaw,z=newroll})
    --end

    -- calculate energy consumption --
    airutils.consumptionCalc(self, accel)

    --saves last velocity for collision detection (abrupt stop)
    self._last_accel = new_accel
    self._last_vel = self.object:get_velocity()
    self._last_longit_speed = longit_speed
    self._yaw = newyaw
    self._roll = newroll
    self._pitch = newpitch
end
