--[[airutils.rudder_limit = 30
airutils.elevator_limit = 40]]--

dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "utilities.lua")

local function floating_auto_correction(self, dtime)
    local factor = 1
    --minetest.chat_send_player(self.driver_name, "antes: " .. self._air_float)
    if self._wing_configuration > self._stable_collective then factor = -1 end
    local time_correction = (dtime/airutils.ideal_step)
    if time_correction < 1 then time_correction = 1 end
    local intensity = 0.01
    local correction = (intensity*factor) * time_correction

    local new_wing_configuration = self._wing_configuration + correction

    self._wing_configuration = new_wing_configuration

    --minetest.chat_send_all(dump(self._wing_configuration))
end

local function set_pitch_by_mouse(self, player)
    local vehicle_rot = self.object:get_rotation()
    local rot_x = player:get_look_vertical()-vehicle_rot.x
	self._elevator_angle = -(rot_x * self._elevator_limit)*(self._pitch_intensity*10)
    if self._elevator_angle > self._elevator_limit then self._elevator_angle = self._elevator_limit end
    if self._elevator_angle < -self._elevator_limit then self._elevator_angle = -self._elevator_limit end
end

function set_pitch(self, dir, dtime)
    local pitch_factor = self._pitch_intensity or 0.6
    local multiplier = pitch_factor*(dtime/airutils.ideal_step)
	if dir == -1 then
        --minetest.chat_send_all("cabrando")
        if self._elevator_angle > 0 then pitch_factor = pitch_factor * 2 end
		self._elevator_angle = math.max(self._elevator_angle-multiplier,-self._elevator_limit)
	elseif dir == 1 then
        --minetest.chat_send_all("picando")
        if self._angle_of_attack < 0 then pitch_factor = 1 end --lets reduce the command power to avoid accidents
		self._elevator_angle = math.min(self._elevator_angle+multiplier,self._elevator_limit)
	end
end

local function set_yaw_by_mouse(self, dir)
    local rotation = self.object:get_rotation()
    local rot_y = math.deg(rotation.y)
    
    local total = math.abs(math.floor(rot_y/360))

    if rot_y < 0 then rot_y = rot_y + (360*total) end
    if rot_y > 360 then rot_y = rot_y - (360*total) end
    if rot_y >= 270 and dir <= 90 then dir = dir + 360 end
    if rot_y <= 90 and dir >= 270 then dir = dir - 360 end

    local intensity = self._yaw_intensity / 10
    local command = (rot_y - dir) * intensity
    if command < -90 then command = -90 
    elseif command > 90 then command = 90 end
    --minetest.chat_send_all("rotation y: "..rot_y.." - dir: "..dir.." - command: "..command)

	self._rudder_angle = (-command * self._rudder_limit)/90
end

local function set_yaw(self, dir, dtime)
    local yaw_factor = self._yaw_intensity or 25
	if dir == 1 then
		self._rudder_angle = math.max(self._rudder_angle-(yaw_factor*dtime),-self._rudder_limit)
	elseif dir == -1 then
		self._rudder_angle = math.min(self._rudder_angle+(yaw_factor*dtime),self._rudder_limit)
	end
end

function airutils.heli_control(self, dtime, hull_direction, longit_speed, longit_drag, nhdir,
                            later_speed, later_drag, accel, player, is_flying)
    --if self.driver_name == nil then return end
    local retval_accel = accel

    local stop = false
    local ctrl = nil

    local time_correction = (dtime/airutils.ideal_step)
    if time_correction < 1 then time_correction = 1 end
    self._vehicle_acc = self._vehicle_acc or 0

	-- player control
	if player then
		ctrl = player:get_player_control()

        if self._last_time_command > 0.5 then
            self._last_time_command = 0.5
        end

        self._acceleration = 0
        self._lat_acceleration = 0
        local acc = 0
        if self._engine_running then
            --engine acceleration calc

            local factor = 1

            --control lift
            local collective_up_max = 1.2
            local min_angle = self._min_collective
            local collective_up = collective_up_max -- / 10
		    if ctrl.jump then
                self._wing_configuration = self._wing_configuration + collective_up
                --end
                self._is_going_up = true
		    elseif ctrl.sneak then
                self._wing_configuration = self._wing_configuration - collective_up
                --end
            else
                self._wing_configuration = self._stable_collective
		    end
            if self._wing_configuration < min_angle then self._wing_configuration = min_angle end
            local up_limit = (self._wing_angle_of_attack+collective_up_max)
            if self._wing_configuration > up_limit then self._wing_configuration = up_limit end
            --end lift
        else
            self._wing_configuration = self._stable_collective or 1
        end

        if is_flying or self.wheels then
            local acc_fraction = (self._max_engine_acc / 10)*time_correction
            if ctrl.up then
                if longit_speed < self._max_speed then self._acceleration = self._acceleration + acc_fraction end
            elseif ctrl.down then
                if longit_speed > -1.0 then self._acceleration = self._acceleration + (-acc_fraction) end
            else
                acc = 0
            end
            self._acceleration = math.min(self._acceleration,self._max_engine_acc)

            if is_flying then --why double check? because I dont want lateral movement when landed
                if ctrl.right then
                    if later_speed < self._max_speed then self._lat_acceleration = self._lat_acceleration + acc_fraction end
                elseif ctrl.left then
                    if later_speed > -self._max_speed then self._lat_acceleration = self._lat_acceleration + (-acc_fraction) end
                end
                --set_yaw(self, yaw_cmd, dtime)
            end
        else
            self._acceleration = 0
            self._lat_acceleration = 0
            self.object:set_velocity({x=0,y=self.object:get_velocity().y,z=0})
        end

        self._vehicle_acc = math.min(self._acceleration, self._max_engine_acc)
        self._lat_acc = math.min(self._lat_acceleration, self._max_engine_acc)

        local hull_acc = vector.multiply(hull_direction,self._vehicle_acc)
        local lat_hull_acc = vector.multiply(nhdir,self._lat_acc)
        --colocar aceleração lateral aqui
        retval_accel=vector.add(retval_accel,hull_acc)
        retval_accel=vector.add(retval_accel,lat_hull_acc)

        --pitch
        local pitch_cmd = 0
        if self._yaw_by_mouse == true then
            set_pitch_by_mouse(self, player)
        else
            if ctrl.up then pitch_cmd = 1 elseif ctrl.down then pitch_cmd = -1 end
            set_pitch(self, pitch_cmd, dtime)
        end

		-- yaw
        local rot_y = math.deg(player:get_look_horizontal())
        set_yaw_by_mouse(self, rot_y)


        --I'm desperate, center all!
        if ctrl.right and ctrl.left then
            self._wing_configuration = self._stable_collective
            --self._elevator_angle = 0
            --self._rudder_angle = 0
        end

        if ctrl.up and ctrl.down and self._last_time_command > 0.5 then
            self._last_time_command = 0
            local name = player:get_player_name()
            if self._yaw_by_mouse == true then
                minetest.chat_send_player(name, core.colorize('#0000ff', " >>> Mouse control disabled."))
                self._yaw_by_mouse = false
            else
                minetest.chat_send_player(name, core.colorize('#0000ff', " >>> Mouse control enabled."))
                self._yaw_by_mouse = true
            end
        end
	end
    
    if is_flying then
        --floating_auto_correction(self, self.dtime)
    end
    --minetest.chat_send_all(dump(self._wing_configuration))

    return retval_accel, stop
end


