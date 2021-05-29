equivalent_exchange = {}
-- support for MT game translation.
local S = default.get_translator

local emc_values = {
	["default:gravel"] = 4,
	["default:flint"] = 4,
	["default:furnace"] = 8,
	["default:cactus"] = 8,
	["default:papyrus"] = 32,
	["default:paper"] = 3*32,
	["default:book"] = 3*3*32,
	["default:copper_ingot"] = 85,
	["default:tin_ingot"] = 85,
	["default:bronze_ingot"] = 85,
	["default:steel_ingot"] = 256,
	["default:mese_crystal"] = 1024,
	["default:gold_ingot"] = 2048,
	["default:diamond"] = 8192,
}

local group_emc_values = {
	["stone"] = 1, --group:stone
	["leaves"] = 1,
	["sand"] = 1,
	["soil"] = 1,
	["stick"] = 2,
	["wood"] = 8, 
	["dye"] = 8,
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
function equivalent_exchange.get_furnace_active_formspec(item_percent, stored_emc)
	return "size[8,8.5]"..
		"list[context;src;2.75,0.5;1,1;]"..
		"list[context;fuel;0.75,1.5;3,2;]"..
		"image[2.75,0.5;1,1;exchange_table.png]"..
		"label[0.375,0.5; EMC:" .. tostring(stored_emc) .. " ]"..
		"image[3.75,1.5;1,1;gui_furnace_arrow_bg.png^[lowpart:"..
		(item_percent)..":gui_furnace_arrow_fg.png^[transformR270]"..
		"list[context;dst;4.75,0.96;3,3;]"..
		"list[current_player;main;0,4.25;8,1;]"..
		"list[current_player;main;0,5.5;8,3;8]"..
		"listring[context;dst]"..
		"listring[current_player;main]"..
		"listring[context;fuel]"..
		"listring[current_player;main]"..
		"listring[context;src]"..
		"listring[current_player;main]"..
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
		local emc_value =  get_itemstack_emc_value(item_stack)
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
			local max_stack_size = ItemStack({name = src_name, count = potential_products}):get_stack_max()
			emc_storage_int = emc_storage_int - potential_products * src_value
			local dstlist = inv:get_list("dst")
			-- put > max_stack items into the dst inventory TODO: simplify this?
			for i, item_stack in ipairs(dstlist) do
				if item_stack:is_empty() then
					if potential_products >= max_stack_size then
						potential_products = potential_products - max_stack_size
						local full_stack = ItemStack({name = src_name, count = max_stack_size})
						inv:set_stack("dst", i, full_stack)
					else
						local last_stack = ItemStack({name = src_name, count = potential_products})
						inv:set_stack("dst", i, last_stack)
						potential_products = 0
						break
					end
				elseif item_stack:get_name() == src_name then
					local put_on =  max_stack_size - item_stack:get_count()
					if put_on == 0 then --if this condition is removed: this does not work and a bug shows, where stacksizes >6000 in the next loop
						::continue::
					elseif put_on >= potential_products then
						local new_stack_size = potential_products + item_stack:get_count()
						potential_products = 0
						local last_stack = ItemStack({name = src_name, count = new_stack_size})
						inv:set_stack("dst", i, last_stack)
						break						
					else
						potential_products = potential_products - put_on
						local full_stack = ItemStack({name = src_name, count = max_stack_size})
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
	local formspec = equivalent_exchange.get_furnace_active_formspec(
		item_percent,
		emc_storage_int
	)

	local infotext = "EMC Table: "..tostring(emc_storage_int)
	--
	-- Set meta values
	--
	meta:set_string("formspec", formspec)
	meta:set_string("infotext", infotext)
	meta:set_int("emc_storage", emc_storage_int)

	return false
end

--
-- Node definitions
--
minetest.register_node("equivalent_exchange:transmutationtable", {
	description = S("Transmute Materials"),
	tiles = {
		"exchange_table.png"
	},
	paramtype2 = "facedir",
	groups = {cracky=2},
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
		drops[#drops+1] = "equivalent_exchange:transmutationtable"
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
		{"default:diamond", "default:diamond", "default:diamond"},
		{"default:diamond", "default:diamond", "default:diamond"},
		{"default:diamond", "group:stone", "default:diamond"},
	}
})
