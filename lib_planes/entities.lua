dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "global_definitions.lua")

function lib_change_color(self, colstr)
    airutils.param_paint(self, colstr)
end

function airutils.get_staticdata(self) -- unloaded/unloads ... is now saved
    return minetest.serialize({
        --stored_sound_handle = self.sound_handle,
        stored_energy = self._energy,
        stored_owner = self.owner,
        stored_hp = self.hp_max,
        stored_color = self._color,
        stored_power_lever = self._power_lever,
        stored_driver_name = self.driver_name,
        stored_last_accell = self._last_accell,
        stored_engine_running = self._engine_running,
        stored_inv_id = self._inv_id,
    })
end

function airutils.on_deactivate(self)
    airutils.save_inventory(self)
end

function airutils.on_activate(self, staticdata, dtime_s)
    airutils.actfunc(self, staticdata, dtime_s)
    if staticdata ~= "" and staticdata ~= nil then
        local data = minetest.deserialize(staticdata) or {}
        self._energy = data.stored_energy
        self.owner = data.stored_owner
        self.hp_max = data.stored_hp
        self._color = data.stored_color
        self._power_lever = data.stored_power_lever
        self.driver_name = data.stored_driver_name
        self._last_accell = data.stored_last_accell
        self._engine_running = data.stored_engine_running
        self._inv_id = data.stored_inv_id
        --self.sound_handle = data.stored_sound_handle
        --minetest.debug("loaded: ", self._energy)
        if self._engine_running then
            self._last_applied_power = -1 --signal to start
        end
    end
    
    if self._register_parts_method then
        self._register_parts_method(self)
    end

    airutils.param_paint(self, self._color)

	self.object:set_armor_groups({immortal=1})

    self.object:set_animation({x = 1, y = self._anim_frames}, 0, 0, true)
    if self.wheels then
        self.wheels:set_animation({x = 1, y = self._anim_frames}, 0, 0, true)
    end

	local inv = minetest.get_inventory({type = "detached", name = self._inv_id})
	-- if the game was closed the inventories have to be made anew, instead of just reattached
	if not inv then
        airutils.create_inventory(self, self._trunk_slots)
	else
	    self.inv = inv
    end
end

function airutils.on_step(self,dtime,colinfo)
    self.dtime = math.min(dtime,0.2)
    self.colinfo = colinfo
    self.height = airutils.get_box_height(self)
    
--  physics comes first
    local vel = self.object:get_velocity()
    
    if colinfo then 
	    self.isonground = colinfo.touching_ground
    else
	    if self.lastvelocity.y==0 and vel.y==0 then
		    self.isonground = true
	    else
		    self.isonground = false
	    end
    end
    
    self:physics()

    if self.logic then
	    self:logic()
    end
    
    self.lastvelocity = self.object:get_velocity()
    self.time_total=self.time_total+self.dtime
end

function airutils.logic(self)
    local velocity = self.object:get_velocity()
    local curr_pos = self.object:get_pos()

    self._last_time_command = self._last_time_command + self.dtime

    if self._last_time_command > 1 then self._last_time_command = 1 end

    local player = nil
    if self.driver_name then player = minetest.get_player_by_name(self.driver_name) end
    local passenger = nil
    if self._passenger then passenger = minetest.get_player_by_name(self._passenger) end

    if player then
        local ctrl = player:get_player_control()
        ---------------------
        -- change the driver
        ---------------------
        if passenger and self._last_time_command >= 1 and self._instruction_mode == true then
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
        -----------
        --autopilot
        -----------
        if self._instruction_mode == false and self._last_time_command >= 1 then
            if self._autopilot == true then
                if ctrl.sneak or ctrl.jump or ctrl.up or ctrl.down or ctrl.right or ctrl.left then
                    self._last_time_command = 0
                    self._autopilot = false
                    minetest.chat_send_player(self.driver_name," >>> Autopilot deactivated")
                end
            else
                if ctrl.sneak == true and ctrl.jump == true then
                    self._last_time_command = 0
                    self._autopilot = true
                    self._auto_pilot_altitude = curr_pos.y
                    minetest.chat_send_player(self.driver_name,core.colorize('#00ff00', " >>> Autopilot on"))
                end
            end
        end
        ----------------------------------
        -- shows the hud for the player
        ----------------------------------
        if ctrl.up == true and ctrl.down == true and self._last_time_command >= 1 then
            self._last_time_command = 0
            if self._show_hud == true then
                self._show_hud = false
            else
                self._show_hud = true
            end
        end
    end

    local accel_y = self.object:get_acceleration().y
    local rotation = self.object:get_rotation()
    local yaw = rotation.y
	local newyaw=yaw
    local pitch = rotation.x
	local roll = rotation.z
	local newroll=roll
    newroll = math.floor(newroll/360)
    newroll = newroll * 360

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
        is_flying = not self.colinfo.touching_ground
    end
    --if is_flying then minetest.chat_send_all('is flying') end

    local is_attached = airutils.checkAttach(self, player)

	if not is_attached then
        -- for some engine error the player can be detached from the machine, so lets set him attached again
        airutils.checkattachBug(self)
    end

    if longit_speed == 0 and is_flying == false and is_attached == false and self._engine_running == false then
        return
    end

    --adjust climb indicator
    local climb_rate = velocity.y
    if climb_rate > 5 then climb_rate = 5 end
    if climb_rate < -5 then
        climb_rate = -5
    end

    -- pitch
    local newpitch = math.rad(0)
    if airutils.get_plane_pitch then
        newpitch = airutils.get_plane_pitch(velocity, longit_speed, self._min_speed, self._angle_of_attack)
    end

    --is an stall, force a recover
    if longit_speed < (self._min_speed+0.5) and climb_rate < -1.5 and is_flying then
        if player and self.driver_name then
            minetest.chat_send_player(self.driver_name,core.colorize('#ff0000', " >>> STALL"))
        end
        self._elevator_angle = 0
        self._angle_of_attack = -1
        newpitch = math.rad(self._angle_of_attack)
    else
        --ajustar angulo de ataque
        if longit_speed > (self._min_speed) then
            local percentage = math.abs(((longit_speed * 100)/(self._min_speed + 5))/100)
            if percentage > 1.5 then percentage = 1.5 end
            self._angle_of_attack = self._wing_angle_of_attack - ((self._elevator_angle / 10)*percentage)

            --set the plane on level
            if airutils.adjust_attack_angle_by_speed then
                --airutils.adjust_attack_angle_by_speed(angle_of_attack, min_angle, max_angle, limit, longit_speed, ideal_step, dtime)
                self._angle_of_attack = airutils.adjust_attack_angle_by_speed(self._angle_of_attack, self._min_attack_angle, self._max_attack_angle, 40, longit_speed, airutils.ideal_step, self.dtime)
            end

            if self._angle_of_attack < self._min_attack_angle then
                self._angle_of_attack = self._min_attack_angle
                self._elevator_angle = self._elevator_angle - 0.2
            end --limiting the negative angle]]--
            --[[if self._angle_of_attack > self._max_attack_angle then
                self._angle_of_attack = self._max_attack_angle
                self._elevator_angle = self._elevator_angle + 0.2
            end --limiting the very high climb angle due to strange behavior]]--]]--
        end
    end

    --minetest.chat_send_all(self._angle_of_attack)

    -- adjust pitch at ground
    if math.abs(longit_speed) > self._tail_lift_min_speed then
        if math.abs(longit_speed) < self._tail_lift_max_speed then
            --minetest.chat_send_all(math.abs(longit_speed))
            local speed_range = self._tail_lift_max_speed - self._tail_lift_min_speed
            percentage = 1-((math.abs(longit_speed) - self._tail_lift_min_speed)/speed_range)
            if percentage > 1 then percentage = 1 end
            if percentage < 0 then percentage = 0 end
            local angle = self._tail_angle * percentage
            local calculated_newpitch = math.rad(angle)
            if newpitch < calculated_newpitch then newpitch = calculated_newpitch end --ja aproveita o pitch atual se ja estiver cerrto
            if newpitch > math.rad(self._tail_angle) then newpitch = math.rad(self._tail_angle) end --não queremos arrastar o cauda no chão
        end
    else
        if math.abs(longit_speed) < self._tail_lift_min_speed then
            newpitch = math.rad(self._tail_angle)
        end
    end

    -- new yaw
	if math.abs(self._rudder_angle)>1.5 then
        local turn_rate = math.rad(14)
        local yaw_turn = self.dtime * math.rad(self._rudder_angle) * turn_rate *
                airutils.sign(longit_speed) * math.abs(longit_speed/2)
		newyaw = yaw + yaw_turn
	end

    --roll adjust
    ---------------------------------
    local delta = 0.002
    if is_flying then
        local roll_reference = newyaw
        local sdir = minetest.yaw_to_dir(roll_reference)
        local snormal = {x=sdir.z,y=0,z=-sdir.x}	-- rightside, dot is negative
        local prsr = airutils.dot(snormal,nhdir)
        local rollfactor = -90
        local roll_rate = math.rad(10)
        newroll = (prsr*math.rad(rollfactor)) * (later_speed * roll_rate) * airutils.sign(longit_speed)

        --[[local rollRotation = -self._rudder_angle * 0.1
        newroll = rollRotation]]--

        --minetest.chat_send_all('newroll: '.. newroll)
    else
        delta = 0.2
        if roll > 0 then
            newroll = roll - delta
            if newroll < 0 then newroll = 0 end
        end
        if roll < 0 then
            newroll = roll + delta
            if newroll > 0 then newroll = 0 end
        end
    end

    ---------------------------------
    -- end roll

    local pilot = player
    if self._command_is_given and passenger then
        pilot = passenger
    else
        self._command_is_given = false
    end

    ------------------------------------------------------
    --accell calculation block
    ------------------------------------------------------
    if is_attached or passenger then
        if self._autopilot ~= true then
            accel, stop = airutils.control(self, self.dtime, hull_direction,
                longit_speed, longit_drag, later_speed, later_drag, accel, pilot, is_flying)
        else
            accel = airutils.autopilot(self, self.dtime, hull_direction, longit_speed, accel, curr_pos)
        end
    end

    --end accell

    if accel == nil then accel = {x=0,y=0,z=0} end

    --lift calculation
    accel.y = accel_y

    --lets apply some bob in water
	if self.isinliquid then
        self._engine_running = false
        local bob = airutils.minmax(airutils.dot(accel,hull_direction),0.2)	-- vertical bobbing
        accel.y = accel.y + bob
        local max_pitch = 6
        local h_vel_compensation = (((longit_speed * 2) * 100)/max_pitch)/100
        if h_vel_compensation < 0 then h_vel_compensation = 0 end
        if h_vel_compensation > max_pitch then h_vel_compensation = max_pitch end
        newpitch = newpitch + (velocity.y * math.rad(max_pitch - h_vel_compensation))
    end

    local new_accel = accel
    if longit_speed > 1.5 then
        new_accel = airutils.getLiftAccel(self, velocity, new_accel, longit_speed, roll, curr_pos, self._lift, 15000)
    end
    -- end lift

    --wind effects
    if longit_speed > 1.5 and airutils.wind then
        local wind = airutils.get_wind(curr_pos, 0.1)
        new_accel = vector.add(new_accel, wind)
    end

    if stop ~= true then --maybe == nil
        self._last_accell = new_accel
	    self.object:move_to(curr_pos)
        --self.object:set_velocity(velocity)
        --[[if player then 
            airutils.attach(self, player, self._instruction_mode)
        end]]--
        airutils.set_acceleration(self.object, new_accel)
    else
        if stop == true then
            self.object:set_acceleration({x=0,y=0,z=0})
            self.object:set_velocity({x=0,y=0,z=0})
        end
    end

    if self.wheels then
        if is_flying == false then --isn't flying?
            --animate wheels
            if math.abs(longit_speed) > 0.1 then
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
    --self.climb_gauge:set_attach(self.object,'',ALBATROS_D5_GAUGE_CLIMBER_POSITION,{x=0,y=0,z=climb_angle})

    local indicated_speed = longit_speed * 0.9
    if indicated_speed < 0 then indicated_speed = 0 end
    local speed_angle = airutils.get_gauge_angle(indicated_speed, -45)
    --self.speed_gauge:set_attach(self.object,'',ALBATROS_D5_GAUGE_SPEED_POSITION,{x=0,y=0,z=speed_angle})

    --adjust power indicator
    local power_indicator_angle = airutils.get_gauge_angle(self._power_lever/10)
    --self.power_gauge:set_attach(self.object,'',ALBATROS_D5_GAUGE_POWER_POSITION,{x=0,y=0,z=power_indicator_angle})

    if is_attached then
        if self._show_hud then
            airutils.update_hud(player, climb_angle, speed_angle)
        else
            airutils.remove_hud(player)
        end
    end

    if is_flying == false then
        -- new yaw
        local turn_rate = math.rad(30)
        local yaw_turn = self.dtime * math.rad(self._rudder_angle) * turn_rate *
                    airutils.sign(longit_speed) * math.abs(longit_speed/2)
	    newyaw = yaw + yaw_turn
    end

    --apply rotations
    self.object:set_rotation({x=newpitch,y=newyaw,z=newroll})
    --end

    --adjust elevator pitch (3d model)
    self.object:set_bone_position("elevator", self._elevator_pos, {x=-self._elevator_angle*2 - 90, y=0, z=0})
    --adjust rudder
    self.object:set_bone_position("rudder", self._rudder_pos, {x=0,y=self._rudder_angle,z=0})
    --adjust ailerons
    if self._aileron_r_pos and self._aileron_l_pos then
        self.object:set_bone_position("aileron.r", self._aileron_r_pos, {x=-self._rudder_angle - 90,y=0,z=0})
        self.object:set_bone_position("aileron.l", self._aileron_l_pos, {x=self._rudder_angle - 90,y=0,z=0})
    end
    --set stick position
    if self.stick then
        self.stick:set_attach(self.object,'',self._stick_pos,{x=self._elevator_angle/2,y=0,z=self._rudder_angle})
    end

    -- calculate energy consumption --
    airutils.consumptionCalc(self, accel)

    --test collision
    airutils.testImpact(self, velocity, curr_pos)

    --saves last velocity for collision detection (abrupt stop)
    self._last_vel = self.object:get_velocity()
end

function airutils.on_punch(self, puncher, ttime, toolcaps, dir, damage)
    if self.hp_max <= 0 then
        airutils.destroy(self, true)
    end

    if not puncher or not puncher:is_player() then
		return
	end

    local is_admin = false
    is_admin = minetest.check_player_privs(puncher, {server=true})
	local name = puncher:get_player_name()
    if self.owner and self.owner ~= name and self.owner ~= "" then
        if is_admin == false then return end
    end
    if self.owner == nil then
        self.owner = name
    end
    	
    if self.driver_name and self.driver_name ~= name then
		-- do not allow other players to remove the object while there is a driver
		return
	end
    
    local is_attached = false
    local player_attach = puncher:get_attach()
    if player_attach then
        if player_attach ~= self.object then
            local slot_attach = player_attach:get_attach()
            if slot_attach == self.object then is_attached = true end
        else
            is_attached = true
        end
    end
    
    if puncher:get_attach() == self.object then is_attached = true end
    --if puncher:get_attach() == self.pilot_seat_base then is_attached = true end

    local itmstck=puncher:get_wielded_item()
    local item_name = ""
    if itmstck then item_name = itmstck:get_name() end

    if is_attached == false then
        if airutils.loadFuel(self, puncher:get_player_name()) then
            return
        end

        --repair
        if (item_name == "airutils:repair_tool")
                and self._engine_running == false  then
            if self.hp_max < self._max_plane_hp then
                local inventory_item = "default:steel_ingot"
                local inv = puncher:get_inventory()
                if inv:contains_item("main", inventory_item) then
                    local stack = ItemStack(inventory_item .. " 1")
                    inv:remove_item("main", stack)
                    self.hp_max = self.hp_max + 10
                    if self.hp_max > self._max_plane_hp then self.hp_max = self._max_plane_hp end
                    airutils.setText(self, self.infotext)
                else
                    minetest.chat_send_player(puncher:get_player_name(), "You need steel ingots in your inventory to perform this repair.")
                end
            end
            return
        end

        -- deal with painting or destroying
	    if itmstck then
		    if airutils.set_param_paint(self, puncher, itmstck) == false then
			    if not self.driver and toolcaps and toolcaps.damage_groups
                        and toolcaps.damage_groups.fleshy and item_name ~= airutils.fuel then
				    --airutils.hurt(self,toolcaps.damage_groups.fleshy - 1)
				    --airutils.make_sound(self,'hit')
                    self.hp_max = self.hp_max - 10
                    minetest.sound_play(self._collision_sound, {
                        object = self.object,
                        max_hear_distance = 5,
                        gain = 1.0,
                        fade = 0.0,
                        pitch = 1.0,
                    })
                    airutils.setText(self, self.infotext)
			    end
		    end
        end

        if self.hp_max <= 0 then
            airutils.destroy(self)
        end
    else
        if self._custom_punch_when_attached then self._custom_punch_when_attached(self, puncher) end
    end
end

function airutils.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end

    local name = clicker:get_player_name()

    if self.owner == "" then
        self.owner = name
    end

    local passenger_name = nil
    if self._passenger then
        passenger_name = self._passenger
    end

    local touching_ground, liquid_below = airutils.check_node_below(self.object, 1.3)
    local is_on_ground = self.isinliquid or touching_ground or liquid_below
    local is_under_water = airutils.check_is_under_water(self.object)

    --minetest.chat_send_all('name '.. dump(name) .. ' - pilot: ' .. dump(self.driver_name) .. ' - pax: ' .. dump(passenger_name))
    --=========================
    --  detach pilot
    --=========================
    if name == self.driver_name then
        airutils.pilot_formspec(name)
    --=========================
    --  detach passenger
    --=========================
    elseif name == passenger_name then
        if is_on_ground or clicker:get_player_control().sneak then
            airutils.dettach_pax(self, clicker)
        else
            minetest.chat_send_player(name, "Hold sneak and right-click to disembark while flying")
        end

    --=========================
    --  attach pilot
    --=========================
    elseif not self.driver_name then
        if self.owner == name or minetest.check_player_privs(clicker, {protection_bypass=true}) then
            if clicker:get_player_control().aux1 == true then --lets see the inventory
                airutils.show_vehicle_trunk_formspec(self, clicker, airutils.trunk_slots)
            else
                if is_under_water then return end
                --remove pax to prevent bug
                if self._passenger then 
                    local pax_obj = minetest.get_player_by_name(self._passenger)
                    airutils.dettach_pax(self, pax_obj)
                end

                --attach player
                if clicker:get_player_control().sneak == true then
                    -- flight instructor mode
                    self._instruction_mode = true
                    airutils.attach(self, clicker, true)
                else
                    -- no driver => clicker is new driver
                    self._instruction_mode = false
                    airutils.attach(self, clicker)
                end
                self._elevator_angle = 0
                self._rudder_angle = 0
                self._command_is_given = false
            end
        else
            minetest.chat_send_player(name, core.colorize('#ff0000', " >>> You aren't the owner of this machine."))
        end

    --=========================
    --  attach passenger
    --=========================
    elseif self.driver_name and not self._passenger then
        airutils.attach_pax(self, clicker)
    
    else
        minetest.chat_send_player(name, core.colorize('#ff0000', " >>> Can't enter airplane."))
    end
end
