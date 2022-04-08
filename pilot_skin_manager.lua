
airutils.pilot_textures = {"pilot_clothes1.png","pilot_clothes2.png","pilot_clothes3.png","pilot_clothes4.png"}
local skinsdb_mod_path = minetest.get_modpath("skinsdb")

minetest.register_chatcommand("au_uniform", {
    func = function(name, param)
        local player = minetest.get_player_by_name(name)

        if player then
            airutils.uniform_formspec(name)
        else
            minetest.chat_send_player(name, "Something isn't working...")
        end
    end,
})

local set_player_textures =
	minetest.get_modpath("player_api") and player_api.set_textures
	or default.player_set_textures

function airutils.set_player_skin(player, skin)
    local backup = "airutils:bcp_last_skin"
    local player_proterties = player:get_properties()
    local texture = player_proterties.textures
    local name = player:get_player_name()
    if texture then
        if skin then
            texture = texture[1]
            if skinsdb_mod_path then
                texture = "character.png"
            end

            if player:get_attribute(backup) == nil or player:get_attribute(backup) == "" then
                player:set_attribute(backup, texture) --texture backup
                --minetest.chat_send_all(dump(player:get_attribute(backup)))
            else
                texture = player:get_attribute(backup)
            end
            texture = texture.."^"..skin
            if texture ~= nil and texture ~= "" then
                if skinsdb_mod_path then
		            player:set_properties({
			            visual = "mesh",
			            visual_size = {x=1, y=1},
			            mesh = "character.b3d",
			            textures = {texture},
		            })
                else
                    set_player_textures(player, { texture })
                end
            end
        else
            local old_texture = player:get_attribute(backup)
            if set_skin then
                if player:get_attribute("set_skin:player_skin") ~= nil and player:get_attribute("set_skin:player_skin") ~= "" then
                    old_texture = player:get_attribute("set_skin:player_skin")
                end
            elseif u_skins then
                if u_skins.u_skins[name] ~= nil then
                    old_texture = u_skins.u_skins[name]
                end
            elseif wardrobe then
                if wardrobe.playerSkins then
                    if wardrobe.playerSkins[name] ~= nil then
                        old_texture = wardrobe.playerSkins[name]
                    end
                end
            end
            --minetest.chat_send_all(dump(old_texture))
            if skinsdb_mod_path then
	            player:set_properties({
		            visual = "mesh",
		            visual_size = {x=1, y=1},
		            mesh = "skinsdb_3d_armor_character_5.b3d",
		            textures = {texture},
	            })
                skins.set_player_skin(player, skins.get_player_skin(player))
            else
                if old_texture ~= nil and old_texture ~= "" then
                    set_player_textures(player, { old_texture })
                end
            end
            player:set_attribute(backup, nil)
        end
    end
end

function airutils.uniform_formspec(name)
    local basic_form = table.concat({
        "formspec_version[5]",
        "size[5,2.9]",
	}, "")

    --minetest.chat_send_all(dump(airutils.pilot_textures))

    local textures = ""
    if airutils.pilot_textures then
        for k, v in pairs( airutils.pilot_textures ) do
            textures = textures .. v .. ","
        end

	    basic_form = basic_form.."dropdown[0.5,0.5;4,0.8;textures;".. textures ..";0;false]"
        basic_form = basic_form.."button[0.5,1.6;4,0.8;set_texture;Set Player Texture]"

        minetest.show_formspec(name, "airutils:change", basic_form)
    else
        minetest.chat_send_player(name, "The isn't activated as secure. Aborting")
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "airutils:change" then
        local name = player:get_player_name()
		if fields.textures or fields.set_texture then
            airutils.set_player_skin(player, fields.textures)
		end
        minetest.close_formspec(name, "airutils:change")
    end
end)
