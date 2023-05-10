equivalent_exchange = {}
-- support for MT game translation.
local S = default.get_translator

local emc_values = {
	-- items EMC Values
	["default:stick"] = 2,
	["default:flint"] = 4,
	["default:furnace"] = 8,
	["default:cactus"] = 8,
	["default:papyrus"] = 32,
	["default:coal_lump"] = 128,
	["default:paper"] = 3 * 32,
	["default:book"] = 3 * 3 * 32,
	["default:copper_ingot"] = 85,
	["default:tin_ingot"] = 85,
	["default:bronze_ingot"] = 85,
	["default:steel_ingot"] = 256,
	["default:mese_crystal"] = 64 * 9,
	["default:mese"] = 64 * 9 * 9,
	["default:mese_crystal_fragment"] = 64, -- basically redstone in mc
	["default:gold_ingot"] = 2048,
	["default:diamond"] = 8192,
	["equivalent_exchange:covalence_dust_low"] = 1,
	["equivalent_exchange:covalence_dust_medium"] = 8,
	["farming:seed_wheat"] = 16,
	["farming:wheat"] = 24,
	["bucket:bucket_empty"] = 768,
	["bucket:bucket_water"] = 769,
	["bucket:bucket_lava"] = 832,
	["default:torch"] = 32,
	["default:meselamp"] = 64*9+1,
	-- Node EMC Values
	["default:stone_with_coal"] = 128,
	["default:stone_with_copper"] = 85,
	["default:stone_with_tin"] = 85,
	["default:stone_with_iron"] = 256,
	["default:stone_with_gold"] = 2048,
	["default:stone_with_mese"] = 64,
	["default:stone_with_diamond"] = 8192,
	["default:gravel"] = 4,
	["default:sandstone"] = 4,
	["default:obsidian"] = 64,
	["default:clay"] = 256,
	["default:clay_lump"] = 64,
	["default:clay_brick"] = 64,
	["default:diamondblock"] = 9*8192,
}

local group_emc_values = {
	["stone"] = 1, --group:stone
	["leaves"] = 1,
	["sand"] = 1,
	["soil"] = 1,
	["stick"] = 2,
	["wood"] = 8,
	["dye"] = 8,
	["flora"] = 16, -- flowers and shrubs
	["sapling"] = 32,
	["tree"] = 32,
	["coal"] = 32,
	["wool"] = 48,
	["water_bucket"] = 769,
	["glass"] = 1,
	["grass"] = 1,
}



-- returns 0 if the emc value for the item is not defined
local function get_item_emc_value(item_stack)
	local stack_name = item_stack:get_name()

	for group_name, value in pairs(group_emc_values) do
		local in_group = minetest.get_item_group(stack_name, group_name)
		if in_group > 0 then
			return value
		end
	end

	if emc_values[stack_name] == nil then
		return 0
	end
	return emc_values[stack_name]
end

-- returns 0 if the emc value for the item is not defined
local function get_itemstack_emc_value(item_stack)
	return get_item_emc_value(item_stack) * item_stack:get_count()
end

--
-- Formspecs
--
-- basically a modified copy of default/furnace.lua , but listrings [https://forum.minetest.net/viewtopic.php?t=12629] where modified for ease of use
function equivalent_exchange.transmutation_active_formspec(item_percent, stored_emc)
	return "size[8,8.5]" ..
			"list[context;src;2.75,0.5;1,1;]" ..
			"list[context;fuel;0.75,1.5;3,2;]" ..
			"image[2.75,0.5;1,1;exchange_table.png]" ..
			"label[0.8,1.1;Input]" ..
			"label[0.375,0.5; EMC:" .. minetest.formspec_escape(stored_emc) .. " ]" ..
			"image[3.75,1.5;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
			(item_percent) .. ":gui_furnace_arrow_fg.png^[transformR270]" ..
			"list[context;dst;4.75,0.6;3,3;]" ..
			"list[current_player;main;0,4.25;8,1;]" ..
			"list[current_player;main;0,5.5;8,3;8]" ..
			"listring[context;dst]" ..
			"listring[current_player;main]" ..
			"listring[context;fuel]" ..
			"listring[current_player;main]" ..
			"listring[context;src]" ..
			"listring[current_player;main]" ..
			default.get_hotbar_bg(0, 4.25)
end

--
-- Node callback functions that are the same for active and inactive furnace
--

local function can_dig(pos, player)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("fuel") and inv:is_empty("dst") and inv:is_empty("src")
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "dst" then
		return 0
	end
	if stack == nil then
		return 0
	end
	if get_itemstack_emc_value(stack) > 0 then
		return stack:get_count()
	end

	return 0
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

local function furnace_node_timer(pos, elapsed)
	--
	-- Initialize metadata
	--
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local srclist = inv:get_list("src")
	local fuellist = inv:get_list("fuel")
	local emc_storage_int = meta:get_int("emc_storage")

	-- convert all contents of fuel into emc
	for i, item_stack in ipairs(fuellist) do
		local emc_value = get_itemstack_emc_value(item_stack)
		item_stack:set_count(0)
		inv:set_stack("fuel", i, item_stack)
		emc_storage_int = emc_value + emc_storage_int
	end

	-- if an item cant be converted right away, because not enough emc is stored in the device: show progressbar
	local item_percent = 0
	if srclist and not srclist[1]:is_empty() then
		local src_stack = srclist[1]
		local src_name = src_stack:get_name()
		local src_value = get_item_emc_value(src_stack)
		item_percent = math.min(100, math.floor(emc_storage_int / src_value * 100))
		if src_value > 0 and emc_storage_int >= src_value then
			local potential_products = math.floor(emc_storage_int / src_value)
			local max_stack_size = ItemStack({ name = src_name, count = potential_products }):get_stack_max()
			emc_storage_int = emc_storage_int - potential_products * src_value
			local dstlist = inv:get_list("dst")
			-- put > max_stack items into the dst inventory TODO: simplify this?
			for i, item_stack in ipairs(dstlist) do
				if item_stack:is_empty() then
					if potential_products >= max_stack_size then
						potential_products = potential_products - max_stack_size
						local full_stack = ItemStack({ name = src_name, count = max_stack_size })
						inv:set_stack("dst", i, full_stack)
					else
						local last_stack = ItemStack({ name = src_name, count = potential_products })
						inv:set_stack("dst", i, last_stack)
						potential_products = 0
						break
					end
				elseif item_stack:get_name() == src_name then
					local put_on = max_stack_size - item_stack:get_count()
					if put_on == 0 then --if this condition is removed: this does not work and a bug shows, where stacksizes >6000 in the next loop
						::continue::
					elseif put_on >= potential_products then
						local new_stack_size = potential_products + item_stack:get_count()
						potential_products = 0
						local last_stack = ItemStack({ name = src_name, count = new_stack_size })
						inv:set_stack("dst", i, last_stack)
						break
					else
						potential_products = potential_products - put_on
						local full_stack = ItemStack({ name = src_name, count = max_stack_size })
						inv:set_stack("dst", i, full_stack)
					end
				end
			end
			local leftovers_emc_value = potential_products * src_value
			--convert leftovers back to emc:
			emc_storage_int = leftovers_emc_value + emc_storage_int
			item_percent = math.min(100, math.floor(emc_storage_int / src_value * 100))
		end

	end
	--
	-- Update formspec, infotext and node
	--
	local formspec = equivalent_exchange.transmutation_active_formspec(
		item_percent,
		emc_storage_int
	)

	-- local infotext = "EMC Table: " .. tostring(emc_storage_int)
	--
	-- Set meta values
	--
	meta:set_string("formspec", formspec)
	-- meta:set_string("infotext", infotext)
	meta:set_int("emc_storage", emc_storage_int)

	return false
end

local function collector_timer(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local emc_storage_int = meta:get_int("emc_storage") or 0
	local emc_table_level = meta:get_int("level") or 1
	local inv = meta:get_inventory()
	local srclist = inv:get_list("src")
	emc_storage_int = emc_storage_int + emc_table_level

	local item_percent = 0
	if srclist and not srclist[1]:is_empty() then
		local src_stack = srclist[1]
		local src_name = src_stack:get_name()
		local src_value = get_item_emc_value(src_stack)
		item_percent = math.min(100, math.floor(emc_storage_int / src_value * 100))
		local potential_products = 0
		if src_value > 0 and emc_storage_int >= src_value then
			potential_products = math.floor(emc_storage_int / src_value)
			local max_stack_size = ItemStack({ name = src_name, count = potential_products }):get_stack_max()
			emc_storage_int = emc_storage_int - potential_products * src_value
			local dstlist = inv:get_list("dst")
			-- put > max_stack items into the dst inventory TODO: simplify this?
			for i, item_stack in ipairs(dstlist) do
				if item_stack:is_empty() then
					if potential_products >= max_stack_size then
						potential_products = potential_products - max_stack_size
						local full_stack = ItemStack({ name = src_name, count = max_stack_size })
						inv:set_stack("dst", i, full_stack)
					else
						local last_stack = ItemStack({ name = src_name, count = potential_products })
						inv:set_stack("dst", i, last_stack)
						potential_products = 0
						break
					end
				elseif item_stack:get_name() == src_name then
					local put_on = max_stack_size - item_stack:get_count()
					if put_on == 0 then --if this condition is removed: this does not work and a bug shows, where stacksizes >6000 in the next loop
						::continue::
					elseif put_on >= potential_products then
						local new_stack_size = potential_products + item_stack:get_count()
						potential_products = 0
						local last_stack = ItemStack({ name = src_name, count = new_stack_size })
						inv:set_stack("dst", i, last_stack)
						break
					else
						potential_products = potential_products - put_on
						local full_stack = ItemStack({ name = src_name, count = max_stack_size })
						inv:set_stack("dst", i, full_stack)
					end
				end
			end
		end
		local leftovers_emc_value = potential_products * src_value
		--convert leftovers back to emc:
		emc_storage_int = leftovers_emc_value + emc_storage_int
		item_percent = math.min(100, math.floor(emc_storage_int / src_value * 100))
	end

	meta:set_int("emc_storage", emc_storage_int)
	meta:set_string("infotext", "current_emc:" .. tostring(emc_storage_int))
	meta:set_string("formspec", equivalent_exchange.energy_collector_formspec(item_percent, emc_storage_int, emc_table_level))
	return true
end

--
-- Node definitions
--

function equivalent_exchange.energy_collector_formspec(item_percent, stored_emc, level)
	return "size[8,8.5]" ..
			"list[context;src;2.75,1.5;1,1;]" ..
			"image[2.75,1.5;1,1;exchange_table.png]" ..
			"label[0.8,0.1;Energy Collector Level: ".. minetest.formspec_escape(level) .."]" ..
			"label[0.375,0.5; EMC:  " .. minetest.formspec_escape(stored_emc) .. " ]" ..
			"image[3.75,1.5;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
			(item_percent) .. ":gui_furnace_arrow_fg.png^[transformR270]" ..
			"list[context;dst;4.75,0.6;3,3;]" ..
			"list[current_player;main;0,4.25;8,1;]" ..
			"list[current_player;main;0,5.5;8,3;8]" ..
			"listring[context;dst]" ..
			"listring[current_player;main]" ..
			"listring[context;fuel]" ..
			"listring[current_player;main]" ..
			"listring[context;src]" ..
			"listring[current_player;main]" ..
			default.get_hotbar_bg(0, 4.25)
end

minetest.register_node("equivalent_exchange:energy_collector", {
	description = "Energy Collector",
	tiles = {
		"equivalent_exchange_emc_collector.png"
	},
	groups = { cracky = 2 },
	on_timer = collector_timer,
	on_construct = function(pos)
		minetest.get_node_timer(pos):start(1.0)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('src', 1)
		inv:set_size('dst', 9)
		meta:set_string("formspec", equivalent_exchange.energy_collector_formspec(0.5, 0, 1))
	end,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	on_punch = function (pos, node, puncher, pointed_thing)
	 -- upgrade the energy collector:
	 if puncher ~= nil and puncher:is_player() and puncher:get_wielded_item():get_name() == "equivalent_exchange:energy_collector" then
		local inv_ref = puncher:get_inventory()
		inv_ref:remove_item("main", ItemStack({name = "equivalent_exchange:energy_collector", count = 1}))
		local meta = minetest.get_meta(pos)
		local level = meta:get_int("level")
		level = level + 1
		meta:set_int("level", level)
	end
	end
})

minetest.register_node("equivalent_exchange:transmutationtable", {
	description = S("Transmute Materials"),
	tiles = {
		"exchange_table.png"
	},
	paramtype2 = "facedir",
	groups = { cracky = 2 },
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),

	can_dig = can_dig,

	on_timer = furnace_node_timer,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("emc_storage", 0)
		local inv = meta:get_inventory()
		inv:set_size('src', 1)
		inv:set_size('fuel', 6)
		inv:set_size('dst', 9)
		furnace_node_timer(pos, 0)
	end,

	on_metadata_inventory_move = function(pos)
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_metadata_inventory_put = function(pos)
		-- start timer function, it will sort out whether furnace can burn or not.
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_metadata_inventory_take = function(pos)
		-- start timer function, it will sort out whether furnace can burn or not.
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_blast = function(pos)
		local drops = {}
		default.get_inventory_drops(pos, "src", drops)
		default.get_inventory_drops(pos, "fuel", drops)
		default.get_inventory_drops(pos, "dst", drops)
		drops[#drops + 1] = "equivalent_exchange:transmutationtable"
		minetest.remove_node(pos)
		return drops
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
})



minetest.register_craft({
	output = "equivalent_exchange:transmutationtable",
	recipe = {
		{ "default:obsidian", "group:stone", "default:obsidian" },
		{ "group:stone", "equivalent_exchange:philosophers_stone", "group:stone" },
		{ "default:obsidian", "group:stone", "default:obsidian" },
	},
	replacements = {
		{"equivalent_exchange:philosophers_stone", "equivalent_exchange:philosophers_stone"}
	}
})

minetest.register_craftitem("equivalent_exchange:covalence_dust_low",
	{ description = "Low covalence dust allows for crafting other items.",
		inventory_image = "equivalent_exchange_covalence_dust.png^[colorize:#0cf058:128" })

minetest.register_craft({
	type = "shapeless",
	output = "equivalent_exchange:covalence_dust_low 40",
	recipe = {
		"default:cobble",
		"default:cobble",
		"default:cobble",
		"default:cobble",
		"default:cobble",
		"default:cobble",
		"default:cobble",
		"default:cobble",
		"default:coal_lump",
	}
}
)

local function get_node_value(node_name)
	local lookup = emc_values[node_name]
	if lookup == nil then
		return 1
	end
	return lookup
end

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

minetest.register_tool("equivalent_exchange:divining_rod_low",
	{ description = "Low Diviningrod",
		inventory_image = "equivalent_exchange_low_divining_rod.png^[colorize:#0cf058:128",
		on_use = function(item_stack, user, pointed_thing)

			if pointed_thing.type == "node" and user:is_player() then
				local pointed_velocity = {
					x = pointed_thing.under.x - pointed_thing.above.x,
					y = pointed_thing.under.y - pointed_thing.above.y,
					z = pointed_thing.under.z - pointed_thing.above.z
				}

				-- construct 2 points 3D cubes around the target
				local pos1 = {
					x = pointed_thing.under.x + pointed_velocity.x + 1,
					y = pointed_thing.under.y + pointed_velocity.y + 1,
					z = pointed_thing.under.z + pointed_velocity.z + 1
				}

				local pos2 = {
					x = pointed_thing.under.x + pointed_velocity.x - 1,
					y = pointed_thing.under.y + pointed_velocity.y - 1,
					z = pointed_thing.under.z + pointed_velocity.z - 1
				}


				local block_count = 0
				local total_sum = 0
				for x = math.min(pos1.x, pos2.x), math.max(pos1.x, pos2.x) do
					for y = math.min(pos1.y, pos2.y), math.max(pos1.y, pos2.y) do
						for z = math.min(pos1.z, pos2.z), math.max(pos1.z, pos2.z) do
							local name = minetest.get_node({ x = x, y = y, z = z }).name
							if name ~= "air" then
								block_count = block_count + 1
								total_sum = total_sum + get_node_value(name)
							end
						end
					end
				end


				local average = "no blocks here"

				if block_count ~= 0 then
					local average_number = math.ceil(total_sum / block_count)
					average = tostring(average_number)
				end

				minetest.chat_send_player(user:get_player_name(),
					"Scanned Blocks: " ..
					minetest.colorize("#34ebab", tostring(block_count)) ..
					"Calculated average Block EMC in Area: " .. minetest.colorize("#d483fc", average))
			end
		end })

function equivalent_exchange.charge_medium(itemstack, placer, pointed_thing)
	if placer:is_player() then
		local meta = itemstack:get_meta()
		local charge = meta:get_int("charge") -- if charge is not initalized: neutral value 0
		charge = math.fmod(charge + 1, 2)
		meta:set_int("charge", charge)
		if charge == 0 then
			charge = "16x3x3"
		else
			charge = "3x3x3"
		end
		minetest.chat_send_player(placer:get_player_name(), "Charge set to: " .. charge)
	end
	return itemstack
end

minetest.register_tool("equivalent_exchange:divining_rod_medium",
	{ description = "Medium Diviningrod",
		inventory_image = "equivalent_exchange_low_divining_rod.png^[colorize:#0ce8f0:128",
		on_use = function(item_stack, user, pointed_thing)
			if pointed_thing.type == "node" and user:is_player() then

				local charge_multiplier = 15
				-- charge can be either 0 or 1 for the medium divining rod.
				if item_stack:get_meta():get_int("charge") == 1 then
					charge_multiplier = 2
				end

				local pointed_velocity = {
					x = pointed_thing.under.x - pointed_thing.above.x,
					y = pointed_thing.under.y - pointed_thing.above.y,
					z = pointed_thing.under.z - pointed_thing.above.z
				}

				local orthogonal = calculate_orthogonal_to_standard_basis_vector(pointed_velocity)

				-- construct 2 points 3D cubes around the target
				local pos1 = {
					x = pointed_thing.under.x - orthogonal.x,
					y = pointed_thing.under.y - orthogonal.y,
					z = pointed_thing.under.z - orthogonal.z
				}

				local pos2 = {
					x = pointed_thing.under.x + orthogonal.x + pointed_velocity.x * charge_multiplier,
					y = pointed_thing.under.y + orthogonal.y + pointed_velocity.y * charge_multiplier,
					z = pointed_thing.under.z + orthogonal.z + pointed_velocity.z * charge_multiplier
				}


				local block_count = 0
				local total_sum = 0
				local max_emc = 0
				for x = math.min(pos1.x, pos2.x), math.max(pos1.x, pos2.x) do
					for y = math.min(pos1.y, pos2.y), math.max(pos1.y, pos2.y) do
						for z = math.min(pos1.z, pos2.z), math.max(pos1.z, pos2.z) do
							local name = minetest.get_node({ x = x, y = y, z = z }).name
							if name ~= "air" then
								block_count = block_count + 1
								local current_emc_value = get_node_value(name)
								total_sum = total_sum + current_emc_value
								max_emc = math.max(max_emc, current_emc_value)
							end
						end
					end
				end


				local average = "no blocks here"

				if block_count ~= 0 then
					local average_number = math.ceil(total_sum / block_count)
					average = tostring(average_number)
				end

				minetest.chat_send_player(user:get_player_name(),
					"Scanned Blocks: " ..
					minetest.colorize("#34ebab", tostring(block_count)) ..
					"Calculated average Block EMC in Area: " .. minetest.colorize("#d483fc", average) .. ". Max EMC: " .. max_emc)
			end
		end,

		on_secondary_use = equivalent_exchange.charge_medium,
		on_place = equivalent_exchange.charge_medium
	})

minetest.register_craft({
	type = "shaped",
	output = "equivalent_exchange:divining_rod_low 1",
	recipe = {
		{ "equivalent_exchange:covalence_dust_low", "equivalent_exchange:covalence_dust_low",
			"equivalent_exchange:covalence_dust_low" },
		{ "equivalent_exchange:covalence_dust_low", "", "equivalent_exchange:covalence_dust_low" },
		{ "equivalent_exchange:covalence_dust_low", "equivalent_exchange:covalence_dust_low",
			"equivalent_exchange:covalence_dust_low" }
	}
}
)

minetest.register_craft({
	type = "shaped",
	output = "equivalent_exchange:divining_rod_medium 1",
	recipe = {
		{ "equivalent_exchange:covalence_dust_medium", "equivalent_exchange:covalence_dust_medium",
			"equivalent_exchange:covalence_dust_medium" },
		{ "equivalent_exchange:covalence_dust_medium", "equivalent_exchange:divining_rod_low",
			"equivalent_exchange:covalence_dust_medium" },
		{ "equivalent_exchange:covalence_dust_medium", "equivalent_exchange:covalence_dust_medium",
			"equivalent_exchange:covalence_dust_medium" },
	}
})

minetest.register_craftitem("equivalent_exchange:covalence_dust_medium",
	{ description = "Medium covalence dust allows for crafting other items.",
		inventory_image = "equivalent_exchange_covalence_dust.png^[colorize:#0ce8f0:128" })

minetest.register_craftitem("equivalent_exchange:covalence_dust_high",
	{ description = "Medium covalence dust allows for crafting other items.",
		inventory_image = "equivalent_exchange_covalence_dust.png^[colorize:#1c5cff:128" })

minetest.register_craft({
	type = "shapeless",
	output = "equivalent_exchange:covalence_dust_medium 40",
	recipe = {
		"default:steel_ingot", "default:mese_crystal_fragment"
	}
}
)

minetest.register_craft({
	type = "shaped",
	output = "equivalent_exchange:divining_rod_medium 1",
	recipe = {
		{ "equivalent_exchange:covalence_dust_medium", "equivalent_exchange:covalence_dust_medium",
			"equivalent_exchange:covalence_dust_medium" },
		{ "equivalent_exchange:covalence_dust_medium", "equivalent_exchange:divining_rod_low",
			"equivalent_exchange:covalence_dust_medium" },
		{ "equivalent_exchange:covalence_dust_medium", "equivalent_exchange:covalence_dust_medium",
			"equivalent_exchange:covalence_dust_medium" }
	}
}
)


-- Load files
local default_path = minetest.get_modpath("equivalent_exchange")

dofile(default_path .. "/philosophers_stone.lua")
