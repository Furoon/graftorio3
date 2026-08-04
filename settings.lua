-- settings.lua
-- Mod startup settings for graftorio3
-- Runs in the data stage where `data:extend()` is the main API

data:extend({
	{
		type = "string-setting",
		name = "graftorio3-train-histogram-buckets",
		setting_type = "startup",
		default_value = "10,30,60,90,120,180,240,300,600",
		allow_blank = false,
	},
	{
		type = "int-setting",
		name = "graftorio3-nth-tick",
		setting_type = "startup",
		default_value = 300,
		allow_blank = false,
	},
	{
		type = "bool-setting",
		name = "graftorio3-server-save",
		setting_type = "startup",
		default_value = true,
		allow_blank = false,
	},
	{
		type = "bool-setting",
		name = "graftorio3-disable-train-stats",
		setting_type = "startup",
		default_value = false,
		allow_blank = false,
	},
})

data:extend({
	{
		type = "string-setting",
		name = "graftorio3-surface-filter",
		setting_type = "startup",
		default_value = "",
		allow_blank = true,
		order = "a-surface-filter",
	},
	{
		type = "bool-setting",
		name = "graftorio3-include-platforms",
		setting_type = "startup",
		default_value = false,
		order = "b-include-platforms",
	},
})

data:extend({
	{
		type = "string-setting",
		setting_type = "startup",
		name = "graftorio3-entity-count-types",
		default_value = "assembling-machine,electric-pole,transport-belt,roboport,unit-spawner,entity-ghost",
		allow_blank = true,
		order = "c-entity-count-types",
	},
	{
		type = "bool-setting",
		setting_type = "startup",
		name = "graftorio3-collect-player-metrics",
		default_value = false,
		order = "d-collect-player-metrics",
	},
})

data:extend({
	{
		type = "string-setting",
		setting_type = "startup",
		name = "graftorio3-instance-label",
		default_value = "",
		allow_blank = true,
		order = "e-instance-label",
	},
	{
		type = "string-setting",
		setting_type = "startup",
		name = "graftorio3-output-filename",
		default_value = "game.prom",
		order = "f-output-filename",
	},
})

data:extend({
	{
		type = "bool-setting",
		setting_type = "startup",
		name = "graftorio3-time-slicing",
		default_value = true,
		order = "g-time-slicing",
	},
})
