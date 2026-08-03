-- events.lua
-- Main metric collection event handler
-- Collects game statistics every nth tick and exports to Prometheus format
-- Processes production, pollution, evolution, logistic networks, and player counts

--- Main nth-tick event handler. Collects all game metrics and writes the Prometheus export file.
--- Iterates the filtered surface set for seeds/pollution and game.forces for production/evolution/logistics,
--- and delegates to sub-module tick handlers for power, circuit networks, and research.
--- @param event NthTickEventData
function collect_core(event)
	gauge_tick:set(game.tick)

	-- Build the filtered surface set once per cycle and reuse it everywhere below.
	local surfaces = collected_surfaces()

	for _, surface in pairs(surfaces) do
		gauge_seed:set(surface.map_gen_settings.seed, { surface.name })
	end

	for name, version in pairs(script.active_mods) do
		gauge_mods:set(1, { name, version })
	end

	for _, surface in pairs(surfaces) do
		local stats = game.get_pollution_statistics(surface)
		for name, n in pairs(stats.input_counts) do
			gauge_pollution_production_input:set(n, { name, surface.name })
		end
		for name, n in pairs(stats.output_counts) do
			gauge_pollution_production_output:set(n, { name, surface.name })
		end
	end

	-- Group processing by force instead of by player to avoid duplicate work
	-- Reset gauges once before force iteration, not P times inside loop
	gauge_logistic_network_all_logistic_robots:reset()
	gauge_logistic_network_available_logistic_robots:reset()
	gauge_logistic_network_all_construction_robots:reset()
	gauge_logistic_network_available_construction_robots:reset()
	gauge_logistic_network_robot_limit:reset()
	gauge_logistic_network_items:reset()
	-- These gauges are force-scoped. Resetting them inside the force loop (as the
	-- original did) means each force wipes the previous force's series.
	gauge_research_queue:reset()
	gauge_platform_state:reset()
	gauge_platform_weight:reset()
	gauge_platform_speed:reset()
	gauge_platform_distance:reset()
	gauge_platform_damaged_tiles:reset()

	-- Iterate game.forces directly. The original code looped over game.players,
	-- which means a dedicated server that nobody has joined yet collects nothing
	-- at all: production, pollution-per-force, evolution, logistics, research and
	-- platform metrics were all silently absent.
	for _, force in pairs(game.forces) do
		if force.valid then
			for _, surface in pairs(surfaces) do
				--- @type {[1]: LuaFlowStatistics, [2]: Gauge, [3]: Gauge}[]
				local stats = {
					{ force.get_item_production_statistics(surface), gauge_item_production_input, gauge_item_production_output },
					{ force.get_fluid_production_statistics(surface), gauge_fluid_production_input, gauge_fluid_production_output },
					{ force.get_kill_count_statistics(surface), gauge_kill_count_input, gauge_kill_count_output },
					{
						force.get_entity_build_count_statistics(surface),
						gauge_entity_build_count_input,
						gauge_entity_build_count_output,
					},
				}

				for _, stat in pairs(stats) do
					for name, n in pairs(stat[1].input_counts) do
						stat[2]:set(n, { force.name, name, surface.name })
					end

					for name, n in pairs(stat[1].output_counts) do
						stat[3]:set(n, { force.name, name, surface.name })
					end
				end

				--- @type {[1]: number, [2]: string}[]
				local evolution = {
					{ force.get_evolution_factor(surface), "total" },
					{ force.get_evolution_factor_by_pollution(surface), "by_pollution" },
					{ force.get_evolution_factor_by_time(surface), "by_time" },
					{ force.get_evolution_factor_by_killing_spawners(surface), "by_killing_spawners" },
				}

				for _, stat in pairs(evolution) do
					gauge_evolution:set(stat[1], { force.name, stat[2], surface.name })
				end

				gauge_rockets_launched:set(force.rockets_launched, { force.name })

				-- LuaForce.items_launched is a dictionary<string, uint> in current
				-- 2.x, not an array of ItemWithQualityCounts. ipairs() over a
				-- dictionary yields nothing, so this metric was always empty.
				for item_name, count in pairs(force.items_launched) do
					gauge_items_launched:set(count, { force.name, item_name, "normal" })
				end
			end

			for surface, networks in pairs(force.logistic_networks) do
				for _, network in ipairs(networks) do
					local network_id = tostring(network.network_id)
					gauge_logistic_network_all_logistic_robots:set(
						network.all_logistic_robots,
						{ force.name, surface, network_id }
					)
					gauge_logistic_network_available_logistic_robots:set(
						network.available_logistic_robots,
						{ force.name, surface, network_id }
					)
					gauge_logistic_network_all_construction_robots:set(
						network.all_construction_robots,
						{ force.name, surface, network_id }
					)
					gauge_logistic_network_available_construction_robots:set(
						network.available_construction_robots,
						{ force.name, surface, network_id }
					)
					gauge_logistic_network_robot_limit:set(network.robot_limit, { force.name, surface, network_id })
					-- Cache get_contents() call to avoid calling expensive API twice
					local contents = network.get_contents()
					if contents ~= nil then
						for _, entry in ipairs(contents) do
							-- quality is a prototype-name string in the 2.x API; keep table form for safety
							local q = entry.quality
							local quality_name = (type(q) == "table" and q.name) or (type(q) == "string" and q) or "normal"
							gauge_logistic_network_items:set(entry.count, { force.name, surface, network_id, entry.name, quality_name })
						end
					end
				end
			end

			-- research tick handler (process once per force, not per player)
			on_research_tick(force, event)

			-- Space Age platform metrics
			if force.platforms then
				local platform_count = 0

				for _, platform in pairs(force.platforms) do
					platform_count = platform_count + 1
					local platform_name = platform.name or tostring(platform.index)

					-- Map state enum to readable string
					--- @type table<defines.space_platform_state, string>
					local state_names = {
						[defines.space_platform_state.waiting_for_starter_pack] = "waiting_for_starter_pack",
						[defines.space_platform_state.starter_pack_requested] = "starter_pack_requested",
						[defines.space_platform_state.starter_pack_on_the_way] = "starter_pack_on_the_way",
						[defines.space_platform_state.on_the_path] = "on_the_path",
						[defines.space_platform_state.waiting_for_departure] = "waiting_for_departure",
						[defines.space_platform_state.no_schedule] = "no_schedule",
						[defines.space_platform_state.no_path] = "no_path",
						[defines.space_platform_state.waiting_at_station] = "waiting_at_station",
						[defines.space_platform_state.paused] = "paused",
					}
					local state_name = state_names[platform.state] or "unknown"

					gauge_platform_state:set(1, { force.name, platform_name, state_name })
					gauge_platform_weight:set(platform.weight, { force.name, platform_name })

					if platform.speed then
						gauge_platform_speed:set(platform.speed, { force.name, platform_name })
					end

					if platform.distance then
						gauge_platform_distance:set(platform.distance, { force.name, platform_name })
					end

					if platform.damaged_tiles then
						gauge_platform_damaged_tiles:set(#platform.damaged_tiles, { force.name, platform_name })
					end
				end

				gauge_platform_count:set(platform_count, { force.name })
			end
		end
	end

	-- Krastorio2 antimatter reactor tracking (only if mod is loaded)
	if script.active_mods["Krastorio2-spaced-out"] then
		gauge_kr_antimatter_reactors:reset()
		for _, surface in pairs(surfaces) do
			local reactors = surface.find_entities_filtered({ name = "kr-antimatter-reactor" })
			if reactors and #reactors > 0 then
				-- Count reactors by force
				--- @type table<string, integer>
				local reactor_count_by_force = {}
				for _, reactor in pairs(reactors) do
					if reactor.valid then
						local force_name = reactor.force.name
						reactor_count_by_force[force_name] = (reactor_count_by_force[force_name] or 0) + 1
					end
				end
				-- Set gauge for each force
				for force_name, count in pairs(reactor_count_by_force) do
					gauge_kr_antimatter_reactors:set(count, { force_name, surface.name })
				end
			end
		end
	end

end

--- Serialize all metrics and write the .prom file. Also updates the exporter
--- self-metrics: series/byte counts describe the PREVIOUS cycle's output
--- (one-cycle lag avoids collecting twice per write).
--- @param event NthTickEventData
function write_metrics(event)
	gauge_exporter_last_collection_tick:set(game.tick)
	local out = prometheus.collect()

	local series = 0
	for line in out:gmatch("[^\n]+") do
		if line:sub(1, 1) ~= "#" then
			series = series + 1
		end
	end
	gauge_exporter_series:set(series)
	gauge_exporter_output_bytes:set(#out)

	if server_save then
		helpers.write_file("graftorio3/game.prom", out, false, 0)
	else
		helpers.write_file("graftorio3/game.prom", out, false)
	end
end

--- Handle player join/leave/kick/ban/remove events. Updates connected and total player count gauges.
--- @param event EventData.on_player_joined_game|EventData.on_player_left_game|EventData.on_player_removed|EventData.on_player_kicked|EventData.on_player_banned
function register_events_players(event)
	gauge_connected_player_count:set(#game.connected_players)
	gauge_total_player_count:set(#game.players)
end
