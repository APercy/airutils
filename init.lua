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

function airutils.check_node_below(obj)
    local pos_below = obj:get_pos()
    if pos_below then
        pos_below.y = pos_below.y - 2.5
        local node_below = minetest.get_node(pos_below).name
        local nodedef = minetest.registered_nodes[node_below]
        local touching_ground = not nodedef or -- unknown nodes are solid
		        nodedef.walkable or false
        local liquid_below = not touching_ground and nodedef.liquidtype ~= "none"
        return touching_ground, liquid_below
    end
    return nil, nil
end

function airutils.check_is_under_water(obj)
	local pos_up = obj:get_pos()
	pos_up.y = pos_up.y + 0.1
	local node_up = minetest.get_node(pos_up).name
	local nodedef = minetest.registered_nodes[node_up]
	local liquid_up = nodedef.liquidtype ~= "none"
	return liquid_up
end

function airutils.setText(self, vehicle_name)
    local properties = self.object:get_properties()
    local formatted = ""
    if self.hp_max then
        formatted = " Current hp: " .. string.format(
           "%.2f", self.hp_max
        )
    end
    if properties then
        properties.infotext = "Nice ".. vehicle_name .." of " .. self.owner .. "." .. formatted
        self.object:set_properties(properties)
    end
end

function airutils.transfer_control(self, status)
    if status == false then
        self._command_is_given = false
        if self._passenger then
            minetest.chat_send_player(self._passenger,
                core.colorize('#ff0000', " >>> The captain got the control."))
        end
        if self.driver_name then
            minetest.chat_send_player(self.driver_name,
                core.colorize('#00ff00', " >>> The control is with you now."))
        end
    else
        self._command_is_given = true
        if self._passenger then
            minetest.chat_send_player(self._passenger,
                core.colorize('#00ff00', " >>> The control is with you now."))
        end
        if self.driver_name then minetest.chat_send_player(self.driver_name," >>> The control was given.") end
    end
end

--returns 0 for old, 1 for new
function airutils.detect_player_api(player)
    local player_proterties = player:get_properties()
    local mesh = "character.b3d"
    if player_proterties.mesh == mesh then
        local models = player_api.registered_models
        local character = models[mesh]
        if character then
            if character.animations.sit.eye_height then
                return 1
            else
                return 0
            end
        end
    end

    return 0
end

--lift
local function pitchroll2pitchyaw(aoa,roll)
	if roll == 0.0 then return aoa,0 end
	-- assumed vector x=0,y=0,z=1
	local p1 = math.tan(aoa)
	local y = math.cos(roll)*p1
	local x = math.sqrt(p1^2-y^2)
	local pitch = math.atan(y)
	local yaw=math.atan(x)*math.sign(roll)
	return pitch,yaw
end

function airutils.getLiftAccel(self, velocity, accel, longit_speed, roll, curr_pos, lift, max_height)
    --lift calculations
    -----------------------------------------------------------
    max_height = max_height or 20000
    local wing_config = 0
    if self._wing_configuration then wing_config = self._wing_configuration end --flaps!
    
    local retval = accel
    if longit_speed > 1 then
        local angle_of_attack = math.rad(self._angle_of_attack + wing_config)
        --local acc = 0.8
        local daoa = deg(angle_of_attack)

        --to decrease the lift coefficient at hight altitudes
        local curr_percent_height = (100 - ((curr_pos.y * 100) / max_height))/100

	    local rotation=self.object:get_rotation()
	    local vrot = mobkit.dir_to_rot(velocity,rotation)
	    
	    local hpitch,hyaw = pitchroll2pitchyaw(angle_of_attack,roll)

	    local hrot = {x=vrot.x+hpitch,y=vrot.y-hyaw,z=roll}
	    local hdir = mobkit.rot_to_dir(hrot) --(hrot)
	    local cross = vector.cross(velocity,hdir)
	    local lift_dir = vector.normalize(vector.cross(cross,hdir))

        local lift_coefficient = (0.24*abs(daoa)*(1/(0.025*daoa+3))^4*math.sign(angle_of_attack))
        local lift_val = math.abs((lift*(vector.length(velocity)^2)*lift_coefficient)*curr_percent_height)
        --minetest.chat_send_all('lift: '.. lift_val)

        local lift_acc = vector.multiply(lift_dir,lift_val)
        --lift_acc=vector.add(vector.multiply(minetest.yaw_to_dir(rotation.y),acc),lift_acc)

        retval = vector.add(retval,lift_acc)
    end
    -----------------------------------------------------------
    -- end lift
    return retval
end
