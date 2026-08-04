--- @type PrometheusModule
prometheus = require("prometheus/prometheus")
require("utils")
require("train")
require("yarm")
require("events")
require("power")
require("research")
require("circuit-network")
require("env")
require("counters")
require("diagnostics")
require("ext")
require("entity_status")

--- @type number[] Parsed histogram bucket boundaries for train metrics
bucket_settings = train_buckets(settings.startup["graftorio3-train-histogram-buckets"].value --[[@as string]])

--- @type integer Number of ticks between metric collection cycles
nth_tick = settings.startup["graftorio3-nth-tick"].value --[[@as integer]]

--- @type boolean Whether to write the .prom file in server-save mode (player 0)
server_save = settings.startup["graftorio3-server-save"].value --[[@as boolean]]

--- @type boolean Whether train statistics collection is disabled
disable_train_stats = settings.startup["graftorio3-disable-train-stats"].value --[[@as boolean]]

-- Surface filtering (2.1 port). Parsed once at load; startup settings cannot change at runtime.
surface_allowlist = parse_surface_filter(settings.startup["graftorio3-surface-filter"].value --[[@as string]])
include_platforms = settings.startup["graftorio3-include-platforms"].value --[[@as boolean]]

-- Environment/state metrics settings (env.lua)
entity_count_types = parse_entity_count_types(settings.startup["graftorio3-entity-count-types"].value --[[@as string]])
collect_player_metrics = settings.startup["graftorio3-collect-player-metrics"].value --[[@as boolean]]

-- Multi-server support (1.3.0): optional instance label on every series and
-- configurable output filename so several servers can share one textfile dir.
instance_label = settings.startup["graftorio3-instance-label"].value --[[@as string]]
output_filename = sanitize_output_filename(settings.startup["graftorio3-output-filename"].value --[[@as string]])
time_slicing = settings.startup["graftorio3-time-slicing"].value --[[@as boolean]]
entity_status_types = parse_entity_count_types(settings.startup["graftorio3-entity-status-types"].value --[[@as string]])
entity_status_max_entities = settings.startup["graftorio3-entity-status-max-entities"].value --[[@as integer]]
train_include_id = settings.startup["graftorio3-train-include-id"].value --[[@as boolean]]
train_max_series = settings.startup["graftorio3-train-max-series"].value --[[@as integer]]
production_quality_labels = settings.startup["graftorio3-production-quality-labels"].value --[[@as boolean]]

-- ============================================================================
-- Gauge metrics (no labels)
-- ============================================================================

--- @type Gauge
gauge_tick = prometheus.gauge("factorio_tick", "game tick")
--- @type Gauge
gauge_connected_player_count = prometheus.gauge("factorio_connected_player_count", "connected players")
--- @type Gauge
gauge_total_player_count = prometheus.gauge("factorio_total_player_count", "total registered players")

-- ============================================================================
-- Gauge metrics (with labels)
-- ============================================================================

--- @type Gauge
gauge_seed = prometheus.gauge("factorio_seed", "seed", { "surface" })
--- @type Gauge
gauge_mods = prometheus.gauge("factorio_mods", "mods", { "name", "version" })

--- @type Gauge
gauge_item_production_input =
	prometheus.gauge("factorio_item_production_input", "items produced", { "force", "name", "surface", "quality" })
--- @type Gauge
gauge_item_production_output =
	prometheus.gauge("factorio_item_production_output", "items consumed", { "force", "name", "surface", "quality" })

--- @type Gauge
gauge_fluid_production_input =
	prometheus.gauge("factorio_fluid_production_input", "fluids produced", { "force", "name", "surface" })
--- @type Gauge
gauge_fluid_production_output =
	prometheus.gauge("factorio_fluid_production_output", "fluids consumed", { "force", "name", "surface" })

--- @type Gauge
gauge_kill_count_input = prometheus.gauge("factorio_kill_count_input", "kills", { "force", "name", "surface" })
--- @type Gauge
gauge_kill_count_output = prometheus.gauge("factorio_kill_count_output", "losses", { "force", "name", "surface" })

--- @type Gauge
gauge_entity_build_count_input =
	prometheus.gauge("factorio_entity_build_count_input", "entities placed", { "force", "name", "surface" })
--- @type Gauge
gauge_entity_build_count_output =
	prometheus.gauge("factorio_entity_build_count_output", "entities removed", { "force", "name", "surface" })

--- @type Gauge
gauge_pollution_production_input =
	prometheus.gauge("factorio_pollution_production_input", "pollutions produced", { "name", "surface" })
--- @type Gauge
gauge_pollution_production_output =
	prometheus.gauge("factorio_pollution_production_output", "pollutions consumed", { "name", "surface" })

--- @type Gauge
gauge_evolution = prometheus.gauge("factorio_evolution", "evolution", { "force", "type", "surface" })

--- @type Gauge
gauge_research_queue = prometheus.gauge("factorio_research_queue", "research", { "force", "name", "level", "index" })

--- @type Gauge
gauge_items_launched =
	prometheus.gauge("factorio_items_launched", "items launched in rockets", { "force", "name", "quality" })

--- @type Gauge
gauge_yarm_site_amount =
	prometheus.gauge("factorio_yarm_site_amount", "YARM - site amount remaining", { "force", "name", "type" })
--- @type Gauge
gauge_yarm_site_ore_per_minute =
	prometheus.gauge("factorio_yarm_site_ore_per_minute", "YARM - site ore per minute", { "force", "name", "type" })
--- @type Gauge
gauge_yarm_site_remaining_permille = prometheus.gauge(
	"factorio_yarm_site_remaining_permille",
	"YARM - site permille remaining",
	{ "force", "name", "type" }
)

-- ============================================================================
-- Train metrics (gauges + histograms)
-- ============================================================================

--- @type Gauge
gauge_train_trip_time = prometheus.gauge("factorio_train_trip_time", "train trip time", { "from", "to", "train_id" })
--- @type Gauge
gauge_train_wait_time = prometheus.gauge("factorio_train_wait_time", "train wait time", { "from", "to", "train_id" })

--- @type Histogram
histogram_train_trip_time = prometheus.histogram(
	"factorio_train_trip_time_groups",
	"train trip time",
	{ "from", "to", "train_id" },
	bucket_settings
)
--- @type Histogram
histogram_train_wait_time = prometheus.histogram(
	"factorio_train_wait_time_groups",
	"train wait time",
	{ "from", "to", "train_id" },
	bucket_settings
)

--- @type Gauge
gauge_train_direct_loop_time =
	prometheus.gauge("factorio_train_direct_loop_time", "train direct loop time", { "a", "b" })
--- @type Histogram
histogram_train_direct_loop_time = prometheus.histogram(
	"factorio_train_direct_loop_time_groups",
	"train direct loop time",
	{ "a", "b" },
	bucket_settings
)

--- @type Gauge
gauge_train_arrival_time = prometheus.gauge("factorio_train_arrival_time", "train arrival time", { "station" })
--- @type Histogram
histogram_train_arrival_time =
	prometheus.histogram("factorio_train_arrival_time_groups", "train arrival time", { "station" }, bucket_settings)

-- ============================================================================
-- Logistic network metrics
-- ============================================================================

--- @type Gauge
gauge_logistic_network_all_construction_robots = prometheus.gauge(
	"factorio_logistic_network_all_construction_robots",
	"the total number of construction robots in the network (idle and active + in roboports)",
	{ "force", "surface", "network" }
)
--- @type Gauge
gauge_logistic_network_available_construction_robots = prometheus.gauge(
	"factorio_logistic_network_available_construction_robots",
	"the number of construction robots available for a job",
	{ "force", "surface", "network" }
)

--- @type Gauge
gauge_logistic_network_all_logistic_robots = prometheus.gauge(
	"factorio_logistic_network_all_logistic_robots",
	"the total number of logistic robots in the network (idle and active + in roboports)",
	{ "force", "surface", "network" }
)
--- @type Gauge
gauge_logistic_network_available_logistic_robots = prometheus.gauge(
	"factorio_logistic_network_available_logistic_robots",
	"the number of logistic robots available for a job",
	{ "force", "surface", "network" }
)

--- @type Gauge
gauge_logistic_network_robot_limit = prometheus.gauge(
	"factorio_logistic_network_robot_limit",
	"the maximum number of robots the network can work with",
	{ "force", "surface", "network" }
)

--- @type Gauge
gauge_logistic_network_items = prometheus.gauge(
	"factorio_logistic_network_items",
	"the number of items in a logistic network",
	{ "force", "surface", "network", "name", "quality" }
)

-- ============================================================================
-- Circuit network metrics
-- ============================================================================

--- @type Gauge
gauge_circuit_network_signal = prometheus.gauge(
	"factorio_circuit_network_signal",
	"the value of a signal in a circuit network",
	{ "force", "surface", "network", "name", "quality" }
)

--- @type Gauge
gauge_circuit_network_monitored = prometheus.gauge(
	"factorio_circuit_network_monitored",
	"whether a circuit network with given ID is being monitored",
	{ "force", "surface", "network" }
)

-- ============================================================================
-- Power metrics
-- ============================================================================

--- @type Gauge
gauge_power_production_input =
	prometheus.gauge("factorio_power_production_input", "power produced", { "force", "name", "network", "surface" })
--- @type Gauge
gauge_power_production_output =
	prometheus.gauge("factorio_power_production_output", "power consumed", { "force", "name", "network", "surface" })

-- ============================================================================
-- Space Age platform metrics
-- ============================================================================

--- @type Gauge
gauge_platform_count = prometheus.gauge("factorio_platforms", "number of space platforms", { "force" })
gauge_rockets_launched = prometheus.gauge("factorio_rockets_launched", "rockets launched per force", { "force" })
counter_collector_errors =
	prometheus.counter("factorio_collector_errors_total", "collector stages that raised an error", { "module" })
gauge_exporter_series = prometheus.gauge("factorio_exporter_series", "metric series written in the previous cycle")
gauge_exporter_output_bytes =
	prometheus.gauge("factorio_exporter_output_bytes", "bytes written in the previous cycle")
gauge_exporter_last_collection_tick =
	prometheus.gauge("factorio_exporter_last_collection_tick", "game tick of the last completed collection")
gauge_surface_pollution = prometheus.gauge("factorio_surface_pollution", "total pollution on the surface", { "surface" })

-- Event counters (counters.lua): true counters for rate() queries
counter_events = prometheus.counter("factorio_events_total", "game events observed since map creation", { "type" })

-- Machine status aggregate (entity_status.lua)
gauge_entity_status = prometheus.gauge("factorio_entity_status",
	"machines by operational status", { "surface", "force", "type", "status" })
gauge_entity_status_scanned = prometheus.gauge("factorio_entity_status_scanned",
	"entities inspected during the last status scan")
gauge_entity_status_truncated = prometheus.gauge("factorio_entity_status_truncated",
	"whether the last status scan hit the entity cap (1=truncated)")

-- Train tracking health (train.lua)
gauge_train_tracked = prometheus.gauge("factorio_train_tracked", "trains with active trip tracking")
gauge_train_gc_removed = prometheus.gauge("factorio_train_gc_removed",
	"stale train entries removed by the last garbage collection")
gauge_train_series_truncated = prometheus.gauge("factorio_train_series_truncated",
	"whether the train series budget is exhausted (1=truncated)")
counter_player_deaths = prometheus.counter("factorio_player_deaths_total", "player deaths", { "player" })
counter_player_kills = prometheus.counter("factorio_player_kills_total", "entities killed by a player", { "player" })
--- @type Gauge
gauge_platform_state = prometheus.gauge("factorio_platform_state", "platform state (1=active)", { "force", "platform", "state" })
--- @type Gauge
gauge_platform_weight = prometheus.gauge("factorio_platform_weight", "platform total weight", { "force", "platform" })
--- @type Gauge
gauge_platform_speed = prometheus.gauge("factorio_platform_speed", "platform speed", { "force", "platform" })
--- @type Gauge
gauge_platform_distance = prometheus.gauge("factorio_platform_distance", "platform distance along connection (0-1)", { "force", "platform" })
--- @type Gauge
gauge_platform_damaged_tiles = prometheus.gauge("factorio_platform_damaged_tiles", "number of damaged platform tiles", { "force", "platform" })

-- ============================================================================
-- Krastorio2 metrics
-- ============================================================================

--- @type Gauge
gauge_kr_antimatter_reactors = prometheus.gauge("factorio_kr_antimatter_reactors", "number of antimatter reactors", { "force", "surface" })

-- Environment/state metrics (env.lua)
gauge_game_speed = prometheus.gauge("factorio_game_speed", "map simulation speed multiplier (1.0 = normal)")
gauge_tick_paused = prometheus.gauge("factorio_tick_paused", "whether the game tick is paused (1=paused)")
gauge_ticks_played = prometheus.gauge("factorio_ticks_played", "ticks played since game creation, unaffected by pause")
gauge_technology_price_multiplier =
	prometheus.gauge("factorio_technology_price_multiplier", "difficulty setting: technology price multiplier")
gauge_spoil_time_modifier = prometheus.gauge("factorio_spoil_time_modifier", "difficulty setting: spoil time modifier")

gauge_peaceful_mode = prometheus.gauge("factorio_peaceful_mode", "whether peaceful mode is enabled (1=enabled)", { "surface" })
gauge_solar_power_multiplier = prometheus.gauge("factorio_solar_power_multiplier", "solar power multiplier", { "surface" })
gauge_darkness = prometheus.gauge("factorio_darkness", "surface darkness (0-1)", { "surface" })
gauge_wind_speed = prometheus.gauge("factorio_wind_speed", "surface wind speed", { "surface" })
gauge_wind_orientation = prometheus.gauge("factorio_wind_orientation", "surface wind orientation (0-1)", { "surface" })
gauge_freeze_daytime = prometheus.gauge("factorio_freeze_daytime", "whether the surface freezes at night (1=freezes)", { "surface" })
gauge_entity_count = prometheus.gauge("factorio_entities", "entity count by type (includes unit-spawner for enemy pressure)", { "surface", "type" })

gauge_technologies_researched = prometheus.gauge("factorio_technologies_researched", "technologies researched", { "force" })
gauge_technologies_total = prometheus.gauge("factorio_technologies_available", "technologies available", { "force" })
gauge_friendly_fire = prometheus.gauge("factorio_friendly_fire", "whether friendly fire is enabled (1=enabled)", { "force" })

gauge_player_online_time =
	prometheus.gauge("factorio_player_online_time_ticks", "ticks this player has played this save", { "player" })
gauge_player_afk_time = prometheus.gauge("factorio_player_afk_time_ticks", "ticks this player has been afk", { "player" })

-- ============================================================================
-- Event registration
-- ============================================================================

--- Register all event handlers. Called from both on_init and on_load to ensure
--- handlers are active in both new-game and save-load scenarios.

--- Run one collector stage isolated from the others. A failing stage
--- increments factorio_collector_errors_total{module} and logs once per
--- module instead of stopping the game with an error dialog. Registered
--- event handlers stay alive and the remaining stages still run, so a
--- single broken collector (e.g. from an unexpected mod combination)
--- degrades one metric family instead of killing the server.
--- @param name string
--- @param fn function
--- @param event any
local function guarded(name, fn, event)
	local ok, err = pcall(fn, event)
	if not ok then
		counter_collector_errors:inc(1, { name })
		storage.collector_error_counts = storage.collector_error_counts or {}
		storage.collector_error_counts[name] = (storage.collector_error_counts[name] or 0) + 1
		storage.collector_error_logged = storage.collector_error_logged or {}
		if not storage.collector_error_logged[name] then
			storage.collector_error_logged[name] = true
			log("[graftorio3] collector stage '" .. name .. "' failed: " .. tostring(err))
		end
	end
	return ok
end

--- nth-tick dispatcher: every stage runs guarded, the write always happens.
--- @param event NthTickEventData
--- Collection stages in execution order. The final stage serializes and
--- writes the file, so it must stay last.
--- @type { name: string, fn: fun(event: any) }[]
collection_stages = {
	{ name = "core", fn = function(e) return collect_core(e) end },
	{ name = "power", fn = function(e) return on_power_tick(e) end },
	{ name = "circuit-network", fn = function(e) return on_circuit_network_tick(e) end },
	{ name = "environment", fn = function(e) return collect_environment(e) end },
	{ name = "counters", fn = function(e) return collect_counters(e) end },
	{ name = "entity-status", fn = function(e) return collect_entity_status(e) end },
	{ name = "train-gc", fn = function(e) return collect_train_gc(e) end },
	{ name = "write", fn = function(e) return write_metrics(e) end },
}

--- Run every stage in one tick. Used when time slicing is disabled.
--- @param event NthTickEventData
function guarded_nth_tick(event)
	for _, stage in ipairs(collection_stages) do
		guarded(stage.name, stage.fn, event)
	end
end

--- Run one stage per invocation, cycling through the list. Called every
--- nth_tick/#stages ticks, so a full cycle still completes every nth_tick
--- ticks while the per-tick cost drops to roughly one stage.
---
--- Trade-off: values within one written file are observed up to nth_tick
--- ticks apart rather than all in the same tick. For rates sampled at
--- Prometheus scrape intervals that skew is irrelevant; it is the reason
--- the behaviour can be switched off.
--- @param event NthTickEventData
function sliced_nth_tick(event)
	storage.slice_index = ((storage.slice_index or 0) % #collection_stages) + 1
	local stage = collection_stages[storage.slice_index]
	guarded(stage.name, stage.fn, event)
end

--- Guarded wrappers for the high-frequency entity event handlers: power and
--- circuit tracking stay isolated from each other here as well.
local function guarded_build(event)
	guarded("power", on_power_build, event)
	guarded("circuit-network", on_circuit_network_build, event)
end

local function guarded_destroy(event)
	guarded("power", on_power_destroy, event)
	guarded("circuit-network", on_circuit_network_destroy, event)
	guarded("counters", on_counter_entity_died, event)
end

local function guarded_train(event)
	guarded("train", register_events_train, event)
end

local function register_all_events()
	register_diagnostics_command()
	if time_slicing then
		-- One stage per invocation; a full cycle still spans nth_tick ticks.
		local period = math.max(1, math.floor(nth_tick / #collection_stages))
		script.on_nth_tick(period, sliced_nth_tick)
	else
		script.on_nth_tick(nth_tick, guarded_nth_tick)
	end

	script.on_event(defines.events.on_player_joined_game, register_events_players)
	script.on_event(defines.events.on_player_left_game, register_events_players)
	script.on_event(defines.events.on_player_removed, register_events_players)
	script.on_event(defines.events.on_player_kicked, register_events_players)
	script.on_event(defines.events.on_player_banned, register_events_players)

	-- train events
	if not disable_train_stats then
		script.on_event(defines.events.on_train_changed_state, guarded_train)
	end

	-- research events
	script.on_event(defines.events.on_research_finished, function(e)
		guarded("research", on_research_finished, e)
		guarded("counters", on_counter_research_finished, e)
	end)

	script.on_event(defines.events.on_rocket_launched, function(e)
		guarded("counters", on_counter_rocket_launched, e)
	end)
	script.on_event(defines.events.on_player_died, function(e)
		guarded("counters", on_counter_player_died, e)
	end)

	-- Build/destroy events are shared by power.lua and circuit-network.lua.
	-- Factorio allows only ONE handler per event per mod: a second on_event()
	-- call silently replaces the first. They must therefore be dispatched from
	-- a single combined handler, not registered twice.
	script.on_event(defines.events.on_built_entity, guarded_build)
	script.on_event(defines.events.on_robot_built_entity, guarded_build)
	script.on_event(defines.events.script_raised_built, guarded_build)
	script.on_event(defines.events.script_raised_revive, guarded_build)
	script.on_event(defines.events.on_player_mined_entity, guarded_destroy)
	script.on_event(defines.events.on_robot_mined_entity, guarded_destroy)
	script.on_event(defines.events.on_entity_died, guarded_destroy)
	script.on_event(defines.events.script_raised_destroy, guarded_destroy)

	if defines.events.on_space_platform_built_entity ~= nil then
		script.on_event(defines.events.on_space_platform_built_entity, guarded_build)
		script.on_event(defines.events.on_space_platform_mined_entity, guarded_destroy)
	end
end

script.on_init(function()
	if script.active_mods["YARM"] then
		storage.yarm_on_site_update_event_id = remote.call("YARM", "get_on_site_updated_event_id")
		script.on_event(storage.yarm_on_site_update_event_id --[[@as string]], handle_yarm)
	end

	on_power_init()
	on_circuit_network_init()

	register_all_events()
end)

script.on_load(function()
	-- Only register YARM event if YARM mod is actually active
	if storage.yarm_on_site_update_event_id and script.active_mods["YARM"] then
		-- Use pcall to safely check if the event ID is valid
		local success, handler = pcall(script.get_event_handler, storage.yarm_on_site_update_event_id)
		if success and handler then
			script.on_event(storage.yarm_on_site_update_event_id --[[@as string]], handle_yarm)
		end
	end

	on_power_load()
	on_circuit_network_load()

	register_all_events()
end)

script.on_configuration_changed(function(_event)
	if script.active_mods["YARM"] then
		storage.yarm_on_site_update_event_id = remote.call("YARM", "get_on_site_updated_event_id")
		script.on_event(storage.yarm_on_site_update_event_id --[[@as string]], handle_yarm)
	end
end)
