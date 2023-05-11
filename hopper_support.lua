
if minetest.get_modpath("hopper") then
    -- Add (optional) support for the hopper mod https://github.com/minetest-mods/hopper/blob/master/api.lua
	hopper:add_container({
		{"top", "equivalent_exchange:transmutationtable", "dst"},
		{"bottom", "equivalent_exchange:transmutationtable", "fuel"},
		{"side", "equivalent_exchange:transmutationtable", "fuel"},
		{"top", "equivalent_exchange:energy_collector", "dst"},
	})
end
