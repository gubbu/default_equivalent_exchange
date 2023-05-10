-- TODO: water => ice, Lava => obsidian, Flowers => Other Flowers
local philosophers_stone_node_conversion_table = {
    ["default:stone"] = "default:cobble",
    ["default:cobble"] = "default:stone",
    ["default:dirt_with_grass"] = "default:sand",
    ["default:dirt"] = "default:sand",
    ["default:sand"] = "default:dirt_with_grass",
    ["default:gravel"] = "default:sandstone",
    ["default:sandstone"] = "default:gravel",
    ["default:water_source"] = "default:ice",
    ["default:lava_source"] = "default:obsidian",
    ["default:silver_sand"] = "default:sand"
}

local philosophers_stone_node_conversion_table_sneak = {
    ["default:stone"] = "default:dirt_with_grass",
    ["default:cobble"] = "default:dirt_with_grass",
    ["default:sand"] = "default:cobble",
    ["default:glass"] = "default:sand",
}

local function show_philosphers_stone_formspec(itemstack, placer, _pointed_thing)
    if placer:is_player() then
        local the_formspec = [[
            formspec_version[6]
            size[10.5,5]
            label[0.4,0.6; Philosopher's Stone]
            dropdown[5.1,1.6;4.3,0.8;mode_select;Cube,Panel,Line;1;false]
            label[0.8,2;Selected Mode:]
            dropdown[5.1,2.6;4.3,0.8;charge_drop_down;1,2,3,4,5;1;false]
            label[0.9,3;Radius of effect (max 3 for cube):]
        ]]

        minetest.show_formspec(placer:get_player_name(), "equivalent_exchange:philosophers_stone_formspec", the_formspec)
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "equivalent_exchange:philosophers_stone_formspec" then
        return
    end
    local philosophers_stone_item_stack = player:get_wielded_item()
    local philosophers_stone_meta = philosophers_stone_item_stack:get_meta()
    if fields.charge_drop_down then
        philosophers_stone_meta:set_string("charge", fields.charge_drop_down)
        --minetest.chat_send_player(player:get_player_name(), " you selected, type:" ..type(fields.charge_drop_down) .. ", value: " .. minetest.serialize(fields.charge_drop_down))
        player:set_wielded_item(philosophers_stone_item_stack)
    end
    if fields.mode_select then
        philosophers_stone_meta:set_string("mode_select", fields.mode_select)
        minetest.chat_send_player(player:get_player_name(), " you selected, type:" .. type(fields.mode_select) .. ", value: " .. minetest.serialize(fields.mode_select))
        player:set_wielded_item(philosophers_stone_item_stack)
    end
end)

local function calculate_orthogonal_to_standard_basis_vector(unit_vector)
    local orthogonal = { x = 0, y = 0, z = 0 }
    if unit_vector.x ~= 0 then
        orthogonal.x = 0
        orthogonal.y = 1
        orthogonal.z = 1
    end

    if unit_vector.y ~= 0 then
        orthogonal.x = 1
        orthogonal.y = 0
        orthogonal.z = 1
    end

    if unit_vector.z ~= 0 then
        orthogonal.x = 1
        orthogonal.y = 1
        orthogonal.z = 0
    end

    return orthogonal
end

minetest.register_tool("equivalent_exchange:philosophers_stone",
    {
    description = "Convert Items using the crafting grid, and convert nodes to other nodes.",
    inventory_image = "equivalent_exchange_philosophers_stone.png",
    liquids_pointable = true,
    on_use = function(item_stack, user, pointed_thing)
        local charge = item_stack:get_meta():get_string("charge")
        local charge_int = 0
        local mode = item_stack:get_meta():get_string("mode_select")
        -- get if player is shift clicking
        local is_sneaking = user:get_player_control().sneak
        local conversion_table_to_use = philosophers_stone_node_conversion_table
        if is_sneaking then
            conversion_table_to_use = philosophers_stone_node_conversion_table_sneak
        end
        if user:is_player() and pointed_thing.type == "node" then
            if charge == "" or charge == "1" then
                charge_int = 0
            elseif charge == "2" then
                charge_int = 1
            elseif charge == "3" then
                charge_int = 2
            elseif charge == "4" then
                charge_int = 3
            elseif charge == "5" then
                charge_int = 4
            end

            local pos1 = pointed_thing.under
            local pos2 = pointed_thing.under

            local pointed_velocity = {
                x = pointed_thing.under.x - pointed_thing.above.x,
                y = pointed_thing.under.y - pointed_thing.above.y,
                z = pointed_thing.under.z - pointed_thing.above.z
            }

            if mode == "Line" or mode == "" or charge_int == 0 then
                pos1 = pointed_thing.under
                pos2 = {
                    x = pointed_thing.under.x + pointed_velocity.x * charge_int,
                    y = pointed_thing.under.y + pointed_velocity.y * charge_int,
                    z = pointed_thing.under.z + pointed_velocity.z * charge_int
                }
            elseif mode == "Panel" then
                local ortho = calculate_orthogonal_to_standard_basis_vector(pointed_velocity)
                pos1 = {
                    x = pointed_thing.under.x + ortho.x * charge_int,
                    y = pointed_thing.under.y + ortho.y * charge_int,
                    z = pointed_thing.under.z + ortho.z * charge_int
                }
                pos2 = {
                    x = pointed_thing.under.x - ortho.x * charge_int,
                    y = pointed_thing.under.y - ortho.y * charge_int,
                    z = pointed_thing.under.z - ortho.z * charge_int
                }

            elseif mode == "Cube" then
                -- note ... due to abuse concerns:
                charge_int = math.min(charge_int, 3)
                local ortho = calculate_orthogonal_to_standard_basis_vector(pointed_velocity)
                pos1 = {
                    x = pointed_thing.under.x + ortho.x * charge_int,
                    y = pointed_thing.under.y + ortho.y * charge_int,
                    z = pointed_thing.under.z + ortho.z * charge_int
                }
                pos2 = {
                    x = pointed_thing.under.x - ortho.x * charge_int + pointed_velocity.x * charge_int,
                    y = pointed_thing.under.y - ortho.y * charge_int + pointed_velocity.y * charge_int,
                    z = pointed_thing.under.z - ortho.z * charge_int + pointed_velocity.z * charge_int
                }
            end

            --[[minetest.chat_send_player(user:get_player_name(), minetest.serialize({
                ["charge_int"] = charge_int,
                ["mode"] = mode,
                ["pos1"] = pos1,
                ["pos2"] = pos2,
            }))]]

            for x = math.min(pos1.x, pos2.x), math.max(pos1.x, pos2.x) do
                for y = math.min(pos1.y, pos2.y), math.max(pos1.y, pos2.y) do
                    for z = math.min(pos1.z, pos2.z), math.max(pos1.z, pos2.z) do
                        local name = minetest.get_node({ x = x, y = y, z = z }).name
                        if name ~= "air" then
                            local convert_to = conversion_table_to_use[name]
                            if convert_to ~= nil then
                                minetest.set_node({ x = x, y = y, z = z }, { name = convert_to })
                            end
                        end
                    end
                end
            end
        end
    end,

    on_secondary_use = show_philosphers_stone_formspec,
    on_place = show_philosphers_stone_formspec
}
)

-- philosphers stone recipes
minetest.register_craft({
    type = "shapeless",
    output = "default:gold_ingot",
    recipe = {
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        "default:steel_ingot",
        "equivalent_exchange:philosophers_stone"
    },
    replacements = {
        { "equivalent_exchange:philosophers_stone", "equivalent_exchange:philosophers_stone" }
    }
})

minetest.register_craft({
    type = "shapeless",
    output = "default:diamond",
    recipe = {
        "default:gold_ingot",
        "default:gold_ingot",
        "default:gold_ingot",
        "default:gold_ingot",
        "equivalent_exchange:philosophers_stone"
    },
    replacements = {
        { "equivalent_exchange:philosophers_stone", "equivalent_exchange:philosophers_stone" }
    }
})

minetest.register_craft({
    type = "shapeless",
    output = "default:dirt_with_grass",
    recipe = {
        "default:dirt",
        "equivalent_exchange:philosophers_stone"
    },
    replacements = {
        { "equivalent_exchange:philosophers_stone", "equivalent_exchange:philosophers_stone" }
    }
})


minetest.register_craft({
    type = "shaped",
    output = "equivalent_exchange:philosophers_stone 1",
    recipe = {
        { "default:gold_ingot", "default:mese_crystal_fragment", "default:gold_ingot" },
        { "default:mese_crystal_fragment", "default:diamond", "default:mese_crystal_fragment" },
        { "default:gold_ingot", "default:mese_crystal_fragment", "default:gold_ingot" },

    }
})
