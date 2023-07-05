dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "global_definitions.lua")

--------------
-- Manual --
--------------

function airutils.getPlaneFromPlayer(player)
    local seat = player:get_attach()
    if seat then
        local plane = seat:get_attach()
        return plane
    end
    return nil
end

function airutils.pilot_formspec(name)
    local player = minetest.get_player_by_name(name)
    local plane_obj = airutils.getPlaneFromPlayer(player)
    if plane_obj == nil then
        return
    end
    local ent = plane_obj:get_luaentity()

    local extra_height = 0

    local flap_is_down = "false"
    local have_flaps = false
    if ent._wing_angle_extra_flaps then
        if ent._wing_angle_extra_flaps > 0 then
            have_flaps = true
        end
    end
    if have_flaps then
        if ent._flap then flap_is_down = "true" end
        extra_height = extra_height + 0.5
    end

    local light = "false"
    if ent._have_landing_lights then
        if ent._land_light then light = "true" end
        extra_height = extra_height + 0.5
    end

    if ent._have_copilot then extra_height = extra_height + 1.1 end

    local yaw = "false"
    if ent._yaw_by_mouse then yaw = "true" end

    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6.0,"..(7.0+extra_height).."]",
	}, "")

    local ver_pos = 1.0
	basic_form = basic_form.."button[1,"..ver_pos..";4,1;turn_on;Start/Stop Engines]"
    ver_pos = ver_pos + 1.1
	basic_form = basic_form.."button[1,"..ver_pos..";4,1;hud;Show/Hide Gauges]"
    ver_pos = ver_pos + 1.1
	basic_form = basic_form.."button[1,"..ver_pos..";4,1;inventory;Show Inventory]"
    ver_pos = ver_pos + 1.5

    if have_flaps then
        basic_form = basic_form.."checkbox[1,"..ver_pos..";flap_is_down;Flaps down;"..flap_is_down.."]"
        ver_pos = ver_pos + 0.5
    end

    if ent._have_landing_lights then
        basic_form = basic_form.."checkbox[1,"..ver_pos..";light;Landing Light;"..light.."]"
        ver_pos = ver_pos + 0.5
    end

    basic_form = basic_form.."checkbox[1,"..ver_pos..";yaw;Yaw by mouse;"..yaw.."]"
    ver_pos = ver_pos + 0.5

    if ent._have_copilot then
        basic_form = basic_form.."button[1,"..ver_pos..";4,1;copilot_form;Co-pilot Manage]"
        ver_pos = ver_pos + 1.1
    end

	basic_form = basic_form.."button[1,"..ver_pos..";4,1;go_out;Go Out!]"

    minetest.show_formspec(name, "lib_planes:pilot_main", basic_form)
end

function airutils.manage_copilot_formspec(name)
    local player = minetest.get_player_by_name(name)
    local plane_obj = airutils.getPlaneFromPlayer(player)
    if plane_obj == nil then
        return
    end
    local ent = plane_obj:get_luaentity()

    local pass_list = ""
    for k, v in pairs(ent._passengers) do
        pass_list = pass_list .. v .. ","
    end

    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,4.5]",
	}, "")

    basic_form = basic_form.."label[1,1.0;Bring a copilot:]"
    basic_form = basic_form.."dropdown[1,1.5;4,0.6;copilot;"..pass_list..";0;false]"
    basic_form = basic_form.."button[1,2.5;4,1;pass_control;Pass the Control]"

    minetest.show_formspec(name, "lib_planes:manage_copilot", basic_form)
end

function airutils.pax_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,5]",
	}, "")

	basic_form = basic_form.."button[1,1.0;4,1;new_seat;Change Seat]"
	basic_form = basic_form.."button[1,2.5;4,1;go_out;Go Offboard]"

    minetest.show_formspec(name, "lib_planes:passenger_main", basic_form)
end

function airutils.go_out_confirmation_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[7,2.2]",
	}, "")

    basic_form = basic_form.."label[0.5,0.5;Do you really want to go offboard now?]"
	basic_form = basic_form.."button[1.3,1.0;2,0.8;no;No]"
	basic_form = basic_form.."button[3.6,1.0;2,0.8;yes;Yes]"

    minetest.show_formspec(name, "lib_planes:go_out_confirmation_form", basic_form)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "lib_planes:go_out_confirmation_form" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "lib_planes:go_out_confirmation_form")
            return
        end
        local ent = plane_obj:get_luaentity()
        if ent then
		    if fields.yes then
                airutils.dettach_pax(ent, player)
		    end
        end
        minetest.close_formspec(name, "lib_planes:go_out_confirmation_form")
    end
	if formname == "lib_planes:passenger_main" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "lib_planes:passenger_main")
            return
        end
        local ent = plane_obj:get_luaentity()
        if ent then
		    if fields.new_seat then
                airutils.dettach_pax(ent, player)
                airutils.attach_pax(ent, player)
		    end
		    if fields.go_out then
                local touching_ground, liquid_below = airutils.check_node_below(plane_obj, 2.5)
                if ent.isinliquid or touching_ground then --isn't flying?
                    airutils.dettach_pax(ent, player)
                else
                    airutils.go_out_confirmation_formspec(name)
                end
		    end
        end
        minetest.close_formspec(name, "lib_planes:passenger_main")
	end
	if formname == "lib_planes:pilot_main" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj then
            local ent = plane_obj:get_luaentity()
		    if fields.turn_on then
                airutils.start_engine(ent)
		    end
            if fields.hud then
                if ent._show_hud == true then
                    ent._show_hud = false
                else
                    ent._show_hud = true
                end
            end
		    if fields.go_out then
                local touching_ground, liquid_below = airutils.check_node_below(plane_obj, 1.3)
                local is_on_ground = ent.isinliquid or touching_ground or liquid_below

                if is_on_ground then --or clicker:get_player_control().sneak then
                    if ent._passenger then --any pax?
                        local pax_obj = minetest.get_player_by_name(ent._passenger)
                        airutils.dettach_pax(ent, pax_obj)
                    end
                    ent._instruction_mode = false
                    --[[ sound and animation
                    if ent.sound_handle then
                        minetest.sound_stop(ent.sound_handle)
                        ent.sound_handle = nil
                    end
                    ent.engine:set_animation_frame_speed(0)]]--
                else
                    -- not on ground
                    if ent._passenger then
                        --give the control to the pax
                        ent._autopilot = false
                        airutils.transfer_control(ent, true)
                        ent._command_is_given = true
                        ent._instruction_mode = true
                    end
                end

                airutils.dettachPlayer(ent, player)
		    end
            if fields.inventory then
                if ent._trunk_slots then
                    airutils.show_vehicle_trunk_formspec(ent, player, ent._trunk_slots)
                end
            end
            if fields.flap_is_down then
                if fields.flap_is_down == "true" then
                    ent._flap = true
                else
                    ent._flap = false
                end
                minetest.sound_play("airutils_collision", {
                    object = ent.object,
                    max_hear_distance = 15,
                    gain = 1.0,
                    fade = 0.0,
                    pitch = 0.5,
                }, true)
            end
            if fields.light then
                if ent._land_light == true then
                    ent._land_light = false
                else
                    ent._land_light = true
                end
            end
            if fields.yaw then
                if ent._yaw_by_mouse == true then
                    ent._yaw_by_mouse = false
                else
                    ent._yaw_by_mouse = true
                end
            end
            if fields.copilot_form then
                airutils.manage_copilot_formspec(name)
            end
        end
        minetest.close_formspec(name, "lib_planes:pilot_main")
    end
    if formname == "lib_planes:manage_copilot" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "lib_planes:manage_copilot")
            return
        end
        local ent = plane_obj:get_luaentity()

	    if fields.copilot then
            --look for a free seat first
            local is_there_a_free_seat = false
            for i = 2,1,-1 
            do 
                if ent._passengers[i] == nil then
                    is_there_a_free_seat = true
                    break
                end
            end
            --then move the current copilot to a free seat
            if ent.co_pilot and is_there_a_free_seat then
                local copilot_player_obj = minetest.get_player_by_name(ent.co_pilot)
                if copilot_player_obj then
                    airutils.dettach_pax(ent, copilot_player_obj)
                    airutils.attach_pax(ent, copilot_player_obj)
                else
                    ent.co_pilot = nil
                end
            end
            --so bring the new copilot
            if ent.co_pilot == nil then
                local new_copilot_player_obj = minetest.get_player_by_name(fields.copilot)
                if new_copilot_player_obj then
                    airutils.dettach_pax(ent, new_copilot_player_obj)
                    airutils.attach_pax(ent, new_copilot_player_obj, true)
                end
            end
	    end
	    if fields.pass_control then
            if ent._command_is_given == true then
			    --take the control
			    airutils.transfer_control(ent, false)
            else
			    --trasnfer the control to student
			    airutils.transfer_control(ent, true)
            end
	    end
        minetest.close_formspec(name, "lib_planes:manage_copilot")
    end


end)
